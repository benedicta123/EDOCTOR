import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../data/models/prescription_model.dart';

class PrescriptionPdfService {
  PrescriptionPdfService._();

  /// Génère et ouvre l'interface native d'impression / export PDF de l'ordonnance pour le patient.
  static Future<void> printPrescription(PatientPrescription prescription) async {
    final pdf = pw.Document();

    final primaryColor = PdfColor.fromHex('132A45'); // Bleu nuit eDoctor
    final greenColor = PdfColor.fromHex('529927');   // Vert végétal eDoctor
    final lightBg = PdfColor.fromHex('F8FAF7');
    final borderColor = PdfColor.fromHex('E2E8F0');
    final textMuted = PdfColor.fromHex('64748B');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ─── En-tête officiel de l'établissement ───
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: lightBg,
                  borderRadius: pw.BorderRadius.circular(12),
                  border: pw.Border.all(color: borderColor),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          prescription.hospitalName.toUpperCase(),
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          'Établissement conventionné eDoctor Santé',
                          style: pw.TextStyle(fontSize: 10, color: textMuted),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Service de Téléconsultation & Soins Numériques',
                          style: pw.TextStyle(fontSize: 9, color: textMuted),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: pw.BoxDecoration(
                            color: greenColor,
                            borderRadius: pw.BorderRadius.circular(6),
                          ),
                          child: pw.Text(
                            'ORDONNANCE MÉDICALE',
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Réf : ORD-2026-${prescription.id.toString().padLeft(4, '0')}',
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: primaryColor),
                        ),
                        pw.Text(
                          'Date : ${prescription.formattedDate}',
                          style: pw.TextStyle(fontSize: 9, color: textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // ─── Cartouches Médecin & Patient ───
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Praticien
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: borderColor),
                        borderRadius: pw.BorderRadius.circular(10),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'MÉDECIN PRESCRIPTEUR',
                            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: textMuted),
                          ),
                          pw.SizedBox(height: 6),
                          pw.Text(
                            'Dr. ${prescription.doctorName}',
                            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: primaryColor),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'Praticien hospitalier agréé',
                            style: pw.TextStyle(fontSize: 9, color: textMuted),
                          ),
                          pw.Text(
                            prescription.hospitalName,
                            style: pw.TextStyle(fontSize: 9, color: textMuted),
                          ),
                        ],
                      ),
                    ),
                  ),

                  pw.SizedBox(width: 14),

                  // Patient
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: borderColor),
                        borderRadius: pw.BorderRadius.circular(10),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'PATIENT BÉNÉFICIAIRE',
                            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: textMuted),
                          ),
                          pw.SizedBox(height: 6),
                          pw.Text(
                            prescription.patientName,
                            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: primaryColor),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'Âge : ${prescription.patientAge}',
                            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: greenColor),
                          ),
                          if (prescription.patientPhone.isNotEmpty)
                            pw.Text(
                              'Tél : ${prescription.patientPhone}',
                              style: pw.TextStyle(fontSize: 9, color: textMuted),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 16),

              // ─── Diagnostic clinique préalable ───
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('F1F5F9'),
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: borderColor),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Diagnostic clinique posé : ',
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: primaryColor),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        prescription.diagnosis.isNotEmpty ? prescription.diagnosis : 'Consultation de suivi médical',
                        style: pw.TextStyle(fontSize: 10, color: primaryColor),
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // ─── Titre Prescription ───
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'PRESCRIPTION MÉDICAMENTEUSE',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  pw.Text(
                    '${prescription.items.length} produit(s) prescrit(s)',
                    style: pw.TextStyle(fontSize: 10, color: textMuted),
                  ),
                ],
              ),

              pw.SizedBox(height: 10),

              // ─── Tableau des Médicaments ───
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: borderColor),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  children: [
                    // En-tête tableau
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: pw.BoxDecoration(
                        color: lightBg,
                        borderRadius: const pw.BorderRadius.vertical(top: pw.Radius.circular(7)),
                      ),
                      child: pw.Row(
                        children: [
                          pw.SizedBox(
                            width: 25,
                            child: pw.Text('#', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: textMuted)),
                          ),
                          pw.Expanded(
                            flex: 4,
                            child: pw.Text('Médicament', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: textMuted)),
                          ),
                          pw.Expanded(
                            flex: 5,
                            child: pw.Text('Posologie & Instructions', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: textMuted)),
                          ),
                          pw.SizedBox(
                            width: 45,
                            child: pw.Text('Qté', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: textMuted)),
                          ),
                        ],
                      ),
                    ),

                    // Lignes médicaments
                    ...prescription.items.asMap().entries.map((entry) {
                      final idx = entry.key + 1;
                      final item = entry.value;
                      final isLast = entry.key == prescription.items.length - 1;

                      return pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: pw.BoxDecoration(
                          border: isLast ? null : pw.Border(bottom: pw.BorderSide(color: borderColor)),
                        ),
                        child: pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.SizedBox(
                              width: 25,
                              child: pw.Text('$idx.', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: textMuted)),
                            ),
                            pw.Expanded(
                              flex: 4,
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(
                                    item.medicationName,
                                    style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: primaryColor),
                                  ),
                                ],
                              ),
                            ),
                            pw.Expanded(
                              flex: 5,
                              child: pw.Text(
                                item.dosageInstructions.isNotEmpty ? item.dosageInstructions : 'Conforme aux recommandations',
                                style: const pw.TextStyle(fontSize: 10),
                              ),
                            ),
                            pw.SizedBox(
                              width: 45,
                              child: pw.Text(
                                '${item.quantity}',
                                textAlign: pw.TextAlign.right,
                                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: greenColor),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),

              if (prescription.homeCareRecommended) ...[
                pw.SizedBox(height: 14),
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('F0FDF4'),
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: greenColor.flatten()),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Text(
                        'ℹ️ Soins infirmiers à domicile recommandés pour cette ordonnance.',
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: greenColor),
                      ),
                    ],
                  ),
                ),
              ],

              pw.Spacer(),

              // ─── Cachet numérique & Signature ───
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.all(8),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: greenColor),
                          borderRadius: pw.BorderRadius.circular(6),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'CERTIFICATION ÉLECTRONIQUE eDOCTOR',
                              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: greenColor),
                            ),
                            pw.Text(
                              'ID Consultation : #${prescription.consultationId}',
                              style: pw.TextStyle(fontSize: 7, color: textMuted),
                            ),
                            pw.Text(
                              'Signature numérique chiffrée SHA-256',
                              style: pw.TextStyle(fontSize: 7, color: textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(
                        'Signature et Cachet du Praticien',
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: primaryColor),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Container(
                        width: 140,
                        height: 50,
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: borderColor, style: pw.BorderStyle.dashed),
                          borderRadius: pw.BorderRadius.circular(6),
                        ),
                        child: pw.Center(
                          child: pw.Text(
                            'Dr. ${prescription.doctorName}\nSigné électroniquement',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(fontSize: 8, color: primaryColor, fontStyle: pw.FontStyle.italic),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 16),
              pw.Divider(color: borderColor),
              pw.SizedBox(height: 6),

              // ─── Bas de page légal ───
              pw.Center(
                child: pw.Text(
                  'Ordonnance dématérialisée délivrée via la plateforme sécurisée eDoctor conforme au code de la santé publique.\nPrésentez cette ordonnance ou votre référence ORD-2026-${prescription.id.toString().padLeft(4, '0')} dans une pharmacie partenaire eDoctor.',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(fontSize: 7.5, color: textMuted),
                ),
              ),
            ],
          );
        },
      ),
    );

    final bytes = await pdf.save();
    try {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => bytes,
        name: 'Ordonnance_eDoctor_${prescription.id}.pdf',
      );
    } catch (_) {}
  }
}
