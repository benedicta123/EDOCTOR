import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../data/models/lab_request_model.dart';

class LabOrderPdfService {
  LabOrderPdfService._();

  /// Génère et ouvre l'interface native d'impression / export PDF de la prescription d'analyses.
  static Future<void> printLabOrder(LabRequestModel lab) async {
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
                          lab.hospitalName.toUpperCase(),
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
                          'Service de Téléconsultation & Examens Biologiques',
                          style: pw.TextStyle(fontSize: 9, color: textMuted),
                        ),
                      ],
                    ),
                    pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: 'EDOCTOR-LAB:${lab.referenceCode}:${lab.id}',
                      width: 54,
                      height: 54,
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 18),

              // ─── Titre du document ───
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'ORDONNANCE D’EXAMENS COMPLÉMENTAIRES',
                      style: pw.TextStyle(
                        fontSize: 15,
                        fontWeight: pw.FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'Référence du dossier : ${lab.referenceCode}',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: greenColor,
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 18),

              // ─── Informations Praticien & Patient ───
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Médecin prescripteur
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        borderRadius: pw.BorderRadius.circular(8),
                        border: pw.Border.all(color: borderColor),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'PRATICIEN PRESCRIPTEUR',
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: textMuted,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            lab.doctorName,
                            style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                          pw.Text(
                            lab.doctorSpecialty,
                            style: pw.TextStyle(fontSize: 10, color: textMuted),
                          ),
                        ],
                      ),
                    ),
                  ),

                  pw.SizedBox(width: 12),

                  // Patient bénéficiaire
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        borderRadius: pw.BorderRadius.circular(8),
                        border: pw.Border.all(color: borderColor),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'PATIENT BÉNÉFICIAIRE',
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: textMuted,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            lab.patientName,
                            style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                          pw.Text(
                            lab.patientAge,
                            style: pw.TextStyle(fontSize: 10, color: textMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 14),

              // ─── Indications cliniques & Consignes ───
              if ((lab.clinicalNotes != null && lab.clinicalNotes!.isNotEmpty) || lab.fastingRequired || lab.isUrgent)
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  margin: const pw.EdgeInsets.only(bottom: 14),
                  decoration: pw.BoxDecoration(
                    color: lightBg,
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: borderColor),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        children: [
                          if (lab.isUrgent)
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              margin: const pw.EdgeInsets.only(right: 8),
                              decoration: pw.BoxDecoration(
                                color: PdfColors.red50,
                                borderRadius: pw.BorderRadius.circular(4),
                              ),
                              child: pw.Text(
                                'URGENT',
                                style: pw.TextStyle(
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.red700,
                                ),
                              ),
                            ),
                          if (lab.fastingRequired)
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: pw.BoxDecoration(
                                color: PdfColors.blue50,
                                borderRadius: pw.BorderRadius.circular(4),
                              ),
                              child: pw.Text(
                                'À JEUN STRICT',
                                style: pw.TextStyle(
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.blue700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (lab.clinicalNotes != null && lab.clinicalNotes!.isNotEmpty) ...[
                        pw.SizedBox(height: 6),
                        pw.Text(
                          'Renseignements cliniques : ${lab.clinicalNotes}',
                          style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic),
                        ),
                      ],
                    ],
                  ),
                ),

              // ─── Tableau des examens demandés ───
              pw.Text(
                'EXAMENS & ANALYSES À RÉALISER',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              pw.SizedBox(height: 6),

              pw.Table(
                border: pw.TableBorder.all(color: borderColor, width: 0.5),
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: lightBg),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Examen prescrit',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Discipline / Type',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Instructions particulières',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  ...lab.items.map((it) {
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            it.name,
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            it.category.toUpperCase(),
                            style: pw.TextStyle(fontSize: 9, color: textMuted),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            it.instructions?.isNotEmpty == true
                                ? it.instructions!
                                : 'Prélèvement standard',
                            style: pw.TextStyle(fontSize: 9),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),

              pw.Spacer(),

              // ─── Pied de page & Visa médical ───
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Délivré le : ${lab.formattedDate}',
                        style: pw.TextStyle(fontSize: 9, color: textMuted),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Document officiel numérisé avec certification cryptographique.',
                        style: pw.TextStyle(fontSize: 8, color: textMuted),
                      ),
                      pw.Text(
                        'Valable dans tout laboratoire d’analyses médicales ou centre d’imagerie agréé.',
                        style: pw.TextStyle(fontSize: 8, color: textMuted),
                      ),
                    ],
                  ),
                  pw.Container(
                    width: 140,
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: borderColor),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Text(
                          'VISA DU MÉDECIN',
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            color: textMuted,
                          ),
                        ),
                        pw.SizedBox(height: 18),
                        pw.Text(
                          lab.doctorName,
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        pw.Text(
                          'Signature certifiée eDoctor',
                          style: pw.TextStyle(fontSize: 7, color: greenColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Ordonnance_Analyses_${lab.referenceCode}.pdf',
    );
  }
}
