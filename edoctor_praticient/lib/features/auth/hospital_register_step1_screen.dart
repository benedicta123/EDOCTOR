import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_dragmarker/flutter_map_dragmarker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/widgets/ui_kit.dart';
import 'hospital_register_step2_screen.dart';

/// Étape 1/2 — Informations de l'établissement hospitalier.
class HospitalRegisterStep1Screen extends StatefulWidget {
  const HospitalRegisterStep1Screen({super.key});

  @override
  State<HospitalRegisterStep1Screen> createState() =>
      _HospitalRegisterStep1ScreenState();
}

class _HospitalRegisterStep1ScreenState
    extends State<HospitalRegisterStep1Screen> {
  final _formKey = GlobalKey<FormState>();
  final _hospitalName = TextEditingController();
  final _address = TextEditingController();
  final _lat = TextEditingController();
  final _lng = TextEditingController();
  final _license = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController(text: '+228 ');
  final _consultationFee = TextEditingController(text: '3000');
  final LatLng _defaultMapCenter = const LatLng(6.1375, 1.2224);
  LatLng? _selectedPoint;
  bool _locationConfirmed = false;
  bool _locating = false;
  String? _locationMessage;
  bool _updatingAddress = false;

  @override
  void initState() {
    super.initState();
    _address.addListener(_handleAddressChanged);
  }

  @override
  void dispose() {
    _address.removeListener(_handleAddressChanged);
    _hospitalName.dispose();
    _address.dispose();
    _lat.dispose();
    _lng.dispose();
    _license.dispose();
    _email.dispose();
    _phone.dispose();
    _consultationFee.dispose();
    super.dispose();
  }

  void _handleAddressChanged() {
    if (_updatingAddress || !_locationConfirmed) return;
    setState(() {
      _locationConfirmed = false;
      _selectedPoint = null;
      _lat.clear();
      _lng.clear();
      _locationMessage = 'Adresse modifiée. Relancez la localisation pour confirmer la position.';
    });
  }

  void _goToStep2() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_locationConfirmed || _selectedPoint == null) {
      showMsg(
        context,
        'Localisez l’adresse ou confirmez une position sur la carte.',
        error: true,
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HospitalRegisterStep2Screen(
          hospitalName: _hospitalName.text.trim(),
          address: _address.text.trim(),
          latitude: _selectedPoint!.latitude,
          longitude: _selectedPoint!.longitude,
          licenseNumber: _license.text.trim(),
          officialEmail: _email.text.trim(),
          hospitalPhone: _phone.text.trim(),
          consultationFee: double.tryParse(_consultationFee.text.trim()) ?? 3000.0,
        ),
      ),
    );
  }

  Future<void> _locateAddress() async {
    final address = _address.text.trim();
    if (address.isEmpty) {
      setState(
        () => _locationMessage = 'Saisissez d’abord l’adresse de l’hôpital.',
      );
      return;
    }
    setState(() {
      _locating = true;
      _locationMessage = null;
    });
    try {
      final result = await ApiService.geocodeHospitalAddress(address: address);
      _applyPoint(
        LatLng(
          (result['latitude'] as num).toDouble(),
          (result['longitude'] as num).toDouble(),
        ),
        address: result['address'] as String?,
      );
    } catch (e) {
      if (mounted) {
        setState(
          () => _locationMessage = e.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _useCurrentPosition() async {
    setState(() {
      _locating = true;
      _locationMessage = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('La géolocalisation est désactivée sur cet appareil.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception(
          'Permission GPS refusée. Choisissez la position sur la carte.',
        );
      }
      final position = await Geolocator.getCurrentPosition();
      final point = LatLng(position.latitude, position.longitude);
      String? address;
      try {
        final result = await ApiService.geocodeHospitalAddress(
          latitude: point.latitude,
          longitude: point.longitude,
        );
        address = result['address'] as String?;
      } catch (_) {}
      _applyPoint(point, address: address);
    } on UnsupportedError {
      if (mounted)
        setState(
          () => _locationMessage = 'Ce navigateur ne supporte pas la géolocalisation. Choisissez la position sur la carte.',
        );
    } catch (e) {
      if (mounted)
        setState(
          () => _locationMessage = e.toString().replaceFirst('Exception: ', ''),
        );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _applyPoint(LatLng point, {String? address}) {
    setState(() {
      _selectedPoint = point;
      _lat.text = point.latitude.toStringAsFixed(6);
      _lng.text = point.longitude.toStringAsFixed(6);
      _locationConfirmed = true;
      if (address != null && address.isNotEmpty) {
        _updatingAddress = true;
        _address.text = address;
        _updatingAddress = false;
      }
      _locationMessage = 'Position confirmée. Vous pouvez déplacer le marqueur pour l’ajuster.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Contenu défilable
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // En-tête : logo + badge sécurité
                          Row(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryContainer,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.local_hospital_rounded,
                                      color: AppColors.primary,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'eDoctor Praticien',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      color: AppColors.secondary,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.verified_rounded,
                                      size: 13,
                                      color: AppColors.primary,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Établissement certifié',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Barre de progression Étape 1/2
                          _StepProgressBar(currentStep: 1),

                          const SizedBox(height: 16),

                          // Titre
                          const Text(
                            'Inscrire mon établissement',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Row(
                            children: [
                              Icon(
                                Icons.local_hospital_outlined,
                                size: 14,
                                color: AppColors.primary,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Informations de l\'hôpital ou clinique',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Section : Identité de l'établissement
                          _SectionHeader(
                            icon: Icons.apartment_rounded,
                            title: 'Identité de l\'établissement',
                          ),
                          const SizedBox(height: 12),

                          _ResponsivePair(
                            first: CustomTextField(
                              controller: _hospitalName,
                              label: 'Nom de l\'hôpital / clinique',
                              hint: 'CHU de Lomé, Clinique Sainte-Marie…',
                              icon: Icons.local_hospital_outlined,
                              validator: (v) =>
                                  v == null || v.isEmpty ? 'Requis' : null,
                            ),
                            second: CustomTextField(
                              controller: _address,
                              label: 'Adresse complète',
                              hint: 'Boulevard Médical, Lomé',
                              icon: Icons.place_outlined,
                              validator: (v) =>
                                  v == null || v.isEmpty ? 'Requis' : null,
                            ),
                          ),
                          const SizedBox(height: 10),

                          const Text(
                            'Localisation de l’hôpital',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _locating ? null : _locateAddress,
                                  icon: _locating
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.search),
                                  label: const Text('Localiser l’adresse'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _locating
                                      ? null
                                      : _useCurrentPosition,
                                  icon: const Icon(Icons.my_location_outlined),
                                  label: const Text(
                                    'Utiliser ma position actuelle',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              height: 260,
                              child: FlutterMap(
                                options: MapOptions(
                                  initialCenter:
                                      _selectedPoint ?? _defaultMapCenter,
                                  initialZoom: 12,
                                  onTap: (_, point) => _applyPoint(point),
                                ),
                                children: [
                                  TileLayer(
                                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                    userAgentPackageName:
                                        'com.edoctor.praticient',
                                  ),
                                  if (_selectedPoint != null)
                                    DragMarkers(
                                      markers: [
                                        DragMarker(
                                          point: _selectedPoint!,
                                          size: const Size(52, 64),
                                          offset: const Offset(0, -32),
                                          builder:
                                              (context, position, isDragging) =>
                                                  const Icon(
                                                    Icons.location_pin,
                                                    color: AppColors.primary,
                                                    size: 48,
                                                  ),
                                          onDragEnd: (_, point) =>
                                              _applyPoint(point),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _locationConfirmed
                                ? 'Position confirmée. Faites glisser le marqueur ou cliquez sur la carte pour l’ajuster.'
                                : 'Cliquez sur la carte pour placer le marqueur, puis déplacez-le si nécessaire.',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceDim,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.code,
                                  size: 16,
                                  color: AppColors.textMuted,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _locationConfirmed
                                        ? 'Latitude : ${_lat.text}  ·  Longitude : ${_lng.text}'
                                        : 'Coordonnées générées automatiquement après localisation',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_locationMessage != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _locationMessage!,
                              style: TextStyle(
                                fontSize: 12,
                                color: _locationConfirmed
                                    ? AppColors.success
                                    : AppColors.error,
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          CustomTextField(
                            controller: _license,
                            label: 'Numéro d\'agrément / licence',
                            hint: 'AGR-MS-2024-001',
                            icon: Icons.badge_outlined,
                            validator: (v) =>
                                v == null || v.isEmpty ? 'Requis' : null,
                          ),
                          const SizedBox(height: 16),

                          // Section : Contacts officiels
                          _SectionHeader(
                            icon: Icons.contact_mail_outlined,
                            title: 'Contacts officiels',
                          ),
                          const SizedBox(height: 12),

                          _ResponsivePair(
                            first: CustomTextField(
                              controller: _email,
                              label: 'Email institutionnel',
                              hint: 'direction@chu-lome.tg',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) => v == null || !v.contains('@')
                                  ? 'Email invalide'
                                  : null,
                            ),
                            second: CustomTextField(
                              controller: _phone,
                              label: 'Téléphone de l\'établissement',
                              hint: '+228 22 00 00 00',
                              icon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Section : Tarification des consultations
                          _SectionHeader(
                            icon: Icons.payments_outlined,
                            title: 'Tarif des consultations',
                          ),
                          const SizedBox(height: 12),

                          CustomTextField(
                            controller: _consultationFee,
                            label: 'Tarif standard de la consultation (FCFA)',
                            hint: '3000',
                            icon: Icons.payments_outlined,
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Requis';
                              final val = double.tryParse(v.trim());
                              if (val == null || val < 500) {
                                return 'Montant invalide (minimum 500 FCFA)';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            '100% de ces honoraires sont reversés directement à votre hôpital pour chaque téléconsultation effectuée.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),

                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Bas fixe
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(
                  top: BorderSide(
                    color: AppColors.border.withValues(alpha: 0.8),
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      onPressed: _locationConfirmed ? _goToStep2 : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Suivant',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Déjà inscrit ? ',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        InkWell(
                          onTap: () => Navigator.of(context).pop(),
                          child: const Text(
                            'Se connecter',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Widgets partagés ───────────────────────────────────────────────────────

class _StepProgressBar extends StatelessWidget {
  const _StepProgressBar({required this.currentStep});
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _StepDot(
              stepNumber: 1,
              active: currentStep >= 1,
              done: currentStep > 1,
            ),
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: currentStep > 1 ? AppColors.primary : AppColors.border,
                ),
              ),
            ),
            _StepDot(
              stepNumber: 2,
              active: currentStep >= 2,
              done: currentStep > 2,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                'Établissement',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: currentStep == 1
                      ? FontWeight.w700
                      : FontWeight.w400,
                  color: currentStep == 1
                      ? AppColors.primary
                      : AppColors.textMuted,
                ),
              ),
            ),
            Expanded(
              child: Text(
                'Compte Admin',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: currentStep == 2
                      ? FontWeight.w700
                      : FontWeight.w400,
                  color: currentStep == 2
                      ? AppColors.primary
                      : AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.stepNumber,
    required this.active,
    required this.done,
  });
  final int stepNumber;
  final bool active;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: active ? AppColors.primary : AppColors.border,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: done
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
            : Text(
                '$stepNumber',
                style: TextStyle(
                  color: active ? Colors.white : AppColors.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _ResponsivePair extends StatelessWidget {
  const _ResponsivePair({required this.first, required this.second});

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
          return Column(children: [first, const SizedBox(height: 14), second]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: 16),
            Expanded(child: second),
          ],
        );
      },
    );
  }
}
