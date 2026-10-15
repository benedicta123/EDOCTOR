import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class ConfirmActionDialog extends StatefulWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final Color confirmColor;
  final IconData icon;
  final bool requireReason;
  final String? reasonHint;
  final List<String>? quickReasons;

  const ConfirmActionDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.confirmColor,
    required this.icon,
    this.requireReason = false,
    this.reasonHint,
    this.quickReasons,
  });

  static Future<String?> show({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmLabel,
    Color confirmColor = AppColors.primary,
    IconData icon = Icons.info_outline_rounded,
    bool requireReason = false,
    String? reasonHint,
    List<String>? quickReasons,
  }) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => ConfirmActionDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        confirmColor: confirmColor,
        icon: icon,
        requireReason: requireReason,
        reasonHint: reasonHint,
        quickReasons: quickReasons,
      ),
    );
  }

  @override
  State<ConfirmActionDialog> createState() => _ConfirmActionDialogState();
}

class _ConfirmActionDialogState extends State<ConfirmActionDialog> {
  final TextEditingController _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: widget.confirmColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(widget.icon, color: widget.confirmColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.message,
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.45),
            ),
            if (widget.requireReason) ...[
              const SizedBox(height: 16),
              if (widget.quickReasons != null && widget.quickReasons!.isNotEmpty) ...[
                const Text(
                  'Motifs réglementaires fréquents :',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: widget.quickReasons!.map((r) {
                    return ActionChip(
                      label: Text(r, style: const TextStyle(fontSize: 11)),
                      backgroundColor: AppColors.surfaceDim,
                      onPressed: () {
                        setState(() {
                          _reasonController.text = r;
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: widget.reasonHint ?? 'Veuillez saisir le motif obligatoire...',
                  filled: true,
                  fillColor: AppColors.surfaceDim,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Annuler', style: TextStyle(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.confirmColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          ),
          onPressed: () {
            if (widget.requireReason && _reasonController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Veuillez spécifier le motif réglementaire.'),
                  backgroundColor: AppColors.rejected,
                ),
              );
              return;
            }
            Navigator.pop(context, widget.requireReason ? _reasonController.text.trim() : 'confirmed');
          },
          child: Text(widget.confirmLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
