import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/api_service.dart';

/// Modal permettant de tester et modifier facilement l'adresse IP / URL du serveur Laravel
/// directement depuis l'application mobile sans avoir à recompiler le code.
class ServerConfigDialog extends StatefulWidget {
  const ServerConfigDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ServerConfigDialog(),
    );
  }

  @override
  State<ServerConfigDialog> createState() => _ServerConfigDialogState();
}

class _ServerConfigDialogState extends State<ServerConfigDialog> {
  late final TextEditingController _urlController;
  bool _testing = false;
  String? _testResult;
  bool? _testSuccess;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: ApiService.baseUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _runTest() async {
    setState(() {
      _testing = true;
      _testResult = null;
      _testSuccess = null;
    });

    final res = await ApiService.testConnection(_urlController.text.trim());

    if (!mounted) return;
    setState(() {
      _testing = false;
      _testSuccess = res['success'] as bool? ?? false;
      _testResult = res['message'] as String? ?? '';
    });
  }

  Future<void> _saveAndClose() async {
    final newUrl = _urlController.text.trim();
    if (newUrl.isNotEmpty) {
      await ApiService.setBaseUrl(newUrl);
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Adresse serveur configurée sur : ${ApiService.baseUrl}'),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _applyPreset(String preset) {
    setState(() {
      _urlController.text = preset;
      _testResult = null;
      _testSuccess = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.dns_rounded, color: AppColors.primary, size: 24),
                SizedBox(width: 10),
                Text(
                  'Configuration Réseau de l\'API',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Ajustez l\'adresse IP du PC pour que votre téléphone puisse dialoguer avec le backend Laravel.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.3),
            ),
            const SizedBox(height: 16),

            // Raccourcis / Presets
            const Text(
              'Raccourcis rapides :',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildPresetChip('Wi-Fi PC (192.168.1.79)', 'http://192.168.1.79:8000/api'),
                _buildPresetChip('USB Câble (127.0.0.1)', 'http://127.0.0.1:8000/api'),
                _buildPresetChip('Émulateur Android', 'http://10.0.2.2:8000/api'),
              ],
            ),
            const SizedBox(height: 16),

            // Champ de saisie
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: 'URL de base de l\'API',
                hintText: 'http://192.168.1.79:8000/api',
                prefixIcon: const Icon(Icons.link_rounded),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),

            // Résultat du test
            if (_testResult != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: _testSuccess == true
                      ? const Color(0xFFE8F5E9)
                      : const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _testSuccess == true
                        ? const Color(0xFF81C784)
                        : const Color(0xFFE57373),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _testSuccess == true
                          ? Icons.check_circle_rounded
                          : Icons.error_outline_rounded,
                      color: _testSuccess == true
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFFC62828),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _testResult!,
                        style: TextStyle(
                          fontSize: 12,
                          color: _testSuccess == true
                              ? const Color(0xFF1B5E20)
                              : const Color(0xFFB71C1C),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Boutons d'action
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _testing ? null : _runTest,
                    icon: _testing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.wifi_tethering_rounded, size: 18),
                    label: const Text('Tester'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _saveAndClose,
                    icon: const Icon(Icons.save_rounded, size: 18, color: Colors.white),
                    label: const Text('Enregistrer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  Widget _buildPresetChip(String label, String value) {
    final isSelected = _urlController.text.trim() == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : AppColors.textPrimary)),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surface,
      onSelected: (_) => _applyPreset(value),
    );
  }
}
