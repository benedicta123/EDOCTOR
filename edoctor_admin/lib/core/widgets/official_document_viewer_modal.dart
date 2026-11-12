import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/api_service.dart';
import '../utils/file_download_helper.dart';

enum DocumentType {
  hospitalLicense,
  pharmacyLicense,
  pharmacistDiploma,
  pharmacyOrderCertificate,
  pharmacyRccm,
  pharmacyIdCard,
}

class OfficialDocumentViewerModal extends StatefulWidget {
  final DocumentType type;
  final String? customTitle;
  final String entityName;
  final String? documentApiEndpoint;
  final String? documentPath;
  final String? documentFileName;
  final String? documentMimeType;
  final String? licenseNumber;
  final String? orderNumber;
  final String? taxNumber;
  final String? address;
  final String? contactName;
  final String? officialEmail;
  final String? phone;
  final DateTime? dateIssued;
  final VoidCallback? onApprove;
  final Function(String reason)? onReject;

  const OfficialDocumentViewerModal({
    super.key,
    required this.type,
    this.customTitle,
    required this.entityName,
    this.documentApiEndpoint,
    this.documentPath,
    this.documentFileName,
    this.documentMimeType,
    this.licenseNumber,
    this.orderNumber,
    this.taxNumber,
    this.address,
    this.contactName,
    this.officialEmail,
    this.phone,
    this.dateIssued,
    this.onApprove,
    this.onReject,
  });

  static Future<void> show({
    required BuildContext context,
    required DocumentType type,
    String? customTitle,
    required String entityName,
    String? documentApiEndpoint,
    String? documentPath,
    String? documentFileName,
    String? documentMimeType,
    String? licenseNumber,
    String? orderNumber,
    String? taxNumber,
    String? address,
    String? contactName,
    String? officialEmail,
    String? phone,
    DateTime? dateIssued,
    VoidCallback? onApprove,
    Function(String reason)? onReject,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: OfficialDocumentViewerModal(
          type: type,
          customTitle: customTitle,
          entityName: entityName,
          documentApiEndpoint: documentApiEndpoint,
          documentPath: documentPath,
          documentFileName: documentFileName,
          documentMimeType: documentMimeType,
          licenseNumber: licenseNumber,
          orderNumber: orderNumber,
          taxNumber: taxNumber,
          address: address,
          contactName: contactName,
          officialEmail: officialEmail,
          phone: phone,
          dateIssued: dateIssued,
          onApprove: onApprove,
          onReject: onReject,
        ),
      ),
    );
  }

  @override
  State<OfficialDocumentViewerModal> createState() =>
      _OfficialDocumentViewerModalState();
}

class _OfficialDocumentViewerModalState
    extends State<OfficialDocumentViewerModal> {
  double _zoomScale = 1.0;
  bool _checklistConfirmed = false;
  bool _isLoading = false;
  String? _errorMessage;
  DocumentPayload? _payload;

  @override
  void initState() {
    super.initState();
    if (_hasEndpoint) {
      _loadDocument();
    }
  }

  bool get _hasEndpoint =>
      widget.documentApiEndpoint != null &&
      widget.documentApiEndpoint!.trim().isNotEmpty;

  Future<void> _loadDocument() async {
    if (!_hasEndpoint) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final payload = await ApiService.fetchDocumentBytes(
        widget.documentApiEndpoint!,
      );
      if (!mounted) return;
      setState(() {
        _payload = payload;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  String get _documentTitle {
    if (widget.customTitle != null && widget.customTitle!.trim().isNotEmpty) {
      return widget.customTitle!;
    }
    switch (widget.type) {
      case DocumentType.hospitalLicense:
        return 'Autorisation d\'Ouverture & Agrément Sanitaire';
      case DocumentType.pharmacyLicense:
        return 'Arrêté Ministériel / Licence d\'Officine de Pharmacie';
      case DocumentType.pharmacistDiploma:
        return 'Diplôme d\'État de Docteur en Pharmacie';
      case DocumentType.pharmacyOrderCertificate:
        return 'Attestation d\'Inscription au Tableau de l\'Ordre (ONP)';
      case DocumentType.pharmacyRccm:
        return 'Extrait du Registre du Commerce (RCCM)';
      case DocumentType.pharmacyIdCard:
        return 'Pièce d\'Identité du Pharmacien Titulaire';
    }
  }

  String get _resolvedFileName {
    return _payload?.fileName ??
        widget.documentFileName ??
        widget.documentPath?.split('/').last ??
        'piece_justificative';
  }

  String get _resolvedMimeType {
    return (_payload?.contentType ?? widget.documentMimeType ?? '')
        .toLowerCase();
  }

  bool _isImageBytes(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return true; // JPEG
    }
    if (bytes.length >= 4 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return true; // PNG
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return true; // WEBP
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46) {
      return true; // GIF
    }
    return false;
  }

  bool _isPdfBytes(Uint8List bytes) {
    return bytes.length >= 4 &&
        bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46; // %PDF
  }

  bool get _isImagePayload {
    if (_payload == null) return false;
    if (_isImageBytes(_payload!.bytes)) return true;
    final mime = _resolvedMimeType;
    final name = _resolvedFileName.toLowerCase();
    return mime.startsWith('image/') ||
        name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.png') ||
        name.endsWith('.webp');
  }

  bool get _isPdfPayload {
    if (_payload == null) return false;
    if (_isPdfBytes(_payload!.bytes)) return true;
    final mime = _resolvedMimeType;
    final name = _resolvedFileName.toLowerCase();
    return mime.contains('pdf') || name.endsWith('.pdf');
  }

  String _formatSize(int byteLength) {
    if (byteLength < 1024) return '$byteLength o';
    if (byteLength < 1024 * 1024) {
      return '${(byteLength / 1024).toStringAsFixed(1)} Ko';
    }
    return '${(byteLength / (1024 * 1024)).toStringAsFixed(2)} Mo';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1080,
      height: 860,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildToolbar(),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 7,
                  child: Container(
                    color: const Color(0xFF1E293B),
                    padding: const EdgeInsets.all(20),
                    child: _buildDocumentContentArea(),
                  ),
                ),
                Container(
                  width: 320,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: _buildAuditPanel(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFF132A45),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(bottom: BorderSide(color: Color(0xFF24446A))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.verified_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Audit de Pièce Justificative — $_documentTitle',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Partenaire : ${widget.entityName} • Réf : ${widget.licenseNumber ?? widget.orderNumber ?? "Non renseignée"} • Fichier : $_resolvedFileName',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              if (_payload != null) ...[
                IconButton(
                  icon: const Icon(
                    Icons.download_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  tooltip: 'Télécharger la pièce originale',
                  onPressed: () {
                    downloadOrSaveBytes(
                      _payload!.bytes,
                      _resolvedFileName,
                      mimeType: _resolvedMimeType.isNotEmpty
                          ? _resolvedMimeType
                          : 'application/octet-stream',
                    );
                  },
                ),
                const SizedBox(width: 4),
              ],
              if (_isImagePayload) ...[
                IconButton(
                  icon: const Icon(
                    Icons.zoom_out_rounded,
                    color: Colors.white70,
                    size: 20,
                  ),
                  tooltip: 'Zoom arrière',
                  onPressed: () {
                    if (_zoomScale > 0.5) {
                      setState(() => _zoomScale = (_zoomScale - 0.15).clamp(0.5, 3.0));
                    }
                  },
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${(_zoomScale * 100).toInt()}%',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.zoom_in_rounded,
                    color: Colors.white70,
                    size: 20,
                  ),
                  tooltip: 'Zoom avant',
                  onPressed: () {
                    if (_zoomScale < 3.0) {
                      setState(() => _zoomScale = (_zoomScale + 0.15).clamp(0.5, 3.0));
                    }
                  },
                ),
                const SizedBox(width: 8),
              ],
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                tooltip: 'Fermer la visionneuse',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentContentArea() {
    if (!_hasEndpoint) {
      return Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 460),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.file_present_outlined,
                  color: Color(0xFFFBBF24),
                  size: 44,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Aucune pièce justificative téléversée',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.documentFileName != null &&
                        widget.documentFileName!.isNotEmpty
                    ? 'Seul le nom « ${widget.documentFileName} » a été transmis sans fichier physique associé lors d\'une ancienne inscription.'
                    : 'Le responsable de ${widget.entityName} n\'a pas encore joint de fichier officiel (PDF ou document requis) pour cette pièce justificative.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF94A3B8),
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16),
            Text(
              'Chargement de la pièce justificative...',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 460),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.broken_image_outlined,
                color: Color(0xFFF87171),
                size: 46,
              ),
              const SizedBox(height: 14),
              const Text(
                'Impossible de charger le document',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFFCBD5E1),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: _loadDocument,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Réessayer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final payload = _payload;
    if (payload == null) return const SizedBox.shrink();

    // 1. Cas Image réelle (JPG, PNG, WEBP, GIF)
    if (_isImagePayload) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.image_rounded,
                  color: Color(0xFF86EFAC),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  '$_resolvedFileName (${_formatSize(payload.bytes.length)})',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                color: const Color(0xFF0F172A),
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Center(
                    child: Transform.scale(
                      scale: _zoomScale,
                      child: Image.memory(
                        payload.bytes,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Text(
                          'Format d\'image non supporté pour l\'aperçu direct.',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // 2. Cas Document PDF ou autre fichier binaire
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: (_isPdfPayload
                        ? const Color(0xFFEF4444)
                        : AppColors.primary)
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                _isPdfPayload
                    ? Icons.picture_as_pdf_rounded
                    : Icons.insert_drive_file_rounded,
                color: _isPdfPayload
                    ? const Color(0xFFF87171)
                    : AppColors.primary,
                size: 52,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              _resolvedFileName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${_isPdfPayload ? "Document PDF officiel" : "Fichier justificatif"} • ${_formatSize(payload.bytes.length)}',
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    final opened = await openBytesInNewTab(
                      payload.bytes,
                      mimeType: _resolvedMimeType.isNotEmpty
                          ? _resolvedMimeType
                          : (_isPdfPayload
                              ? 'application/pdf'
                              : 'application/octet-stream'),
                    );
                    if (!opened && mounted) {
                      await downloadOrSaveBytes(
                        payload.bytes,
                        _resolvedFileName,
                        mimeType: _resolvedMimeType,
                      );
                    }
                  },
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('Ouvrir le document'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    downloadOrSaveBytes(
                      payload.bytes,
                      _resolvedFileName,
                      mimeType: _resolvedMimeType,
                    );
                  },
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Télécharger'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF475569)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuditPanel() {
    final hasName = widget.entityName.trim().isNotEmpty;
    final ref = widget.licenseNumber ?? widget.orderNumber;
    final hasRef = ref != null && ref.trim().isNotEmpty;
    final hasAddress = widget.address != null && widget.address!.trim().isNotEmpty;
    final hasTax = widget.taxNumber != null && widget.taxNumber!.trim().isNotEmpty;
    final hasContact = widget.contactName != null && widget.contactName!.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.fact_check_rounded, color: AppColors.primary, size: 20),
            SizedBox(width: 8),
            Text(
              'Audit de Conformité eDoctor',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Vérifiez la concordance entre la pièce réelle soumise et les informations du profil partenaire.',
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 16),
        const Divider(height: 1),
        const SizedBox(height: 14),
        Expanded(
          child: ListView(
            children: [
              _buildAuditCheckItem(
                'Raison sociale déclarée',
                hasName ? widget.entityName : 'Non renseignée',
                hasName,
              ),
              _buildAuditCheckItem(
                'Numéro d\'agrément / licence',
                hasRef ? ref : 'Non communiqué',
                hasRef,
              ),
              _buildAuditCheckItem(
                'Adresse & localisation',
                hasAddress ? widget.address! : 'Non renseignée',
                hasAddress,
              ),
              _buildAuditCheckItem(
                'Identifiant Fiscal (NIF / RCCM)',
                hasTax ? widget.taxNumber! : 'Non renseigné',
                hasTax,
              ),
              _buildAuditCheckItem(
                'Responsable légal / Titulaire',
                hasContact ? widget.contactName! : 'Non renseigné',
                hasContact,
              ),
              const SizedBox(height: 14),
              InkWell(
                onTap: () =>
                    setState(() => _checklistConfirmed = !_checklistConfirmed),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _checklistConfirmed
                        ? AppColors.verifiedBg
                        : AppColors.surfaceDim,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _checklistConfirmed
                          ? AppColors.verifiedBorder
                          : AppColors.border,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _checklistConfirmed
                            ? Icons.check_box_rounded
                            : Icons.check_box_outline_blank_rounded,
                        size: 18,
                        color: _checklistConfirmed
                            ? AppColors.verified
                            : AppColors.textMuted,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'J\'atteste avoir vérifié la pièce soumise et certifie la conformité du dossier partenaire.',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (widget.onApprove != null) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check_circle_rounded, size: 16),
              label: const Text('Valider la pièce'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                Navigator.pop(context);
                widget.onApprove!();
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (widget.onReject != null) ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.cancel_outlined, size: 16),
              label: const Text('Rejeter la pièce'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.rejected,
                side: const BorderSide(color: AppColors.rejected),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                Navigator.pop(context);
                widget.onReject!(
                  'Pièce justificative absente, non conforme ou illisible lors de l\'audit eDoctor.',
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAuditCheckItem(String label, String value, bool isPresent) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isPresent ? Icons.check_circle_rounded : Icons.info_outline_rounded,
            size: 15,
            color: isPresent ? AppColors.verified : AppColors.pending,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isPresent
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
