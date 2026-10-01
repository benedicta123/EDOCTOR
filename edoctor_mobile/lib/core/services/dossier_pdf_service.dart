import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../data/models/patient_dossier_model.dart';

/// Génère un vrai PDF A4 du dossier patient — contenu strictement dérivé
/// du dossier API (aucune donnée inventée).
class DossierPdfService {
  static const _brandGreen = PdfColor.fromInt(0xFF529927);
  static const _brandNavy = PdfColor.fromInt(0xFF132A45);
  static const _muted = PdfColor.fromInt(0xFF64748B);
  static const _line = PdfColor.fromInt(0xFFE2E8F0);

  static String _age(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    try {
      final dob = DateTime.parse(iso);
      final now = DateTime.now();
      var age = now.year - dob.year;
      if (now.month < dob.month ||
          (now.month == dob.month && now.day < dob.day)) {
        age--;
      }
      final d = dob.day.toString().padLeft(2, '0');
      final m = dob.month.toString().padLeft(2, '0');
      return '$d/$m/${dob.year} ($age ans)';
    } catch (_) {
      return iso;
    }
  }

  static Future<void> shareDossierPdf(PatientDossier dossier) async {
    final doc = pw.Document();

    final patient = dossier.patient;
    final ref =
        'DOC-TG-${DateTime.now().year}-${patient.id.toString().padLeft(2, '0')}';

    pw.Widget sectionTitle(String text) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
          child: pw.Text(
            text,
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: _brandNavy,
            ),
          ),
        );

    pw.Widget divider() => pw.Container(
          height: 0.7,
          color: _line,
          margin: const pw.EdgeInsets.symmetric(vertical: 6),
        );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (ctx) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'eDoctor — Dossier médical',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: _brandGreen,
              ),
            ),
            pw.Text(
              'Généré le ${_todayFr()}',
              style: const pw.TextStyle(fontSize: 9, color: _muted),
            ),
          ],
        ),
        footer: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            divider(),
            pw.Text(
              'Document généré depuis les données eDoctor (consultations tenues + ordonnances validées). '
              'Réf $ref — Page ${ctx.pageNumber}/${ctx.pagesCount}. Confidentiel, réservé au patient et aux soignants autorisés.',
              style: const pw.TextStyle(fontSize: 8, color: _muted),
            ),
          ],
        ),
        build: (ctx) => [
          pw.Text(
            'Dossier $ref',
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: _brandNavy,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            patient.name.isNotEmpty ? patient.name : 'Patient #${patient.id}',
            style: const pw.TextStyle(fontSize: 12, color: _muted),
          ),
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _line),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Naissance : ${_age(patient.dateOfBirth)}',
                    style: const pw.TextStyle(fontSize: 10)),
                pw.Text(
                    'Adresse : ${(patient.address?.isNotEmpty == true) ? patient.address! : 'Non renseignée'}',
                    style: const pw.TextStyle(fontSize: 10)),
                pw.Text(
                    'Téléphone : ${(patient.phone?.isNotEmpty == true) ? patient.phone! : 'Non renseigné'}',
                    style: const pw.TextStyle(fontSize: 10)),
                pw.Text(
                    'Antécédents déclarés : ${(patient.medicalHistorySummary?.isNotEmpty == true) ? patient.medicalHistorySummary! : 'Non renseignés'}',
                    style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
          ),
          sectionTitle(
              'Consultations tenues (${dossier.consultations.length})'),
          if (dossier.consultations.isEmpty)
            pw.Text('Aucune consultation en_cours/terminee en base.',
                style: const pw.TextStyle(fontSize: 10, color: _muted))
          else
            ...dossier.consultations.map(
              (c) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 6),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      '${c.displayCode} — ${c.doctorName}'
                      '${c.doctorSpecialty?.isNotEmpty == true ? ' (${c.doctorSpecialty})' : ''} — ${c.displayDate} — ${c.status}',
                      style: pw.TextStyle(
                          fontSize: 10, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          sectionTitle(
              'Ordonnances validées (${dossier.prescriptions.length})'),
          if (dossier.prescriptions.isEmpty)
            pw.Text('Aucune ordonnance validée en base.',
                style: const pw.TextStyle(fontSize: 10, color: _muted))
          else
            ...dossier.prescriptions.map(
              (p) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Ordonnance #${p.id} — ${p.doctorName} — ${p.status}',
                      style: pw.TextStyle(
                          fontSize: 10, fontWeight: pw.FontWeight.bold),
                    ),
                    if (p.items.isEmpty)
                      pw.Text('Aucun médicament renseigné.',
                          style: const pw.TextStyle(fontSize: 9, color: _muted))
                    else
                      ...p.items.map(
                        (it) => pw.Text(
                          '• ${it.medicationName}'
                          '${it.dosage?.isNotEmpty == true ? ' — ${it.dosage}' : ''}'
                          '${it.quantity != null ? ' (x${it.quantity})' : ''}',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'dossier-medical-${patient.id}.pdf',
    );
  }

  static String _todayFr() {
    final now = DateTime.now();
    final d = now.day.toString().padLeft(2, '0');
    final m = now.month.toString().padLeft(2, '0');
    return '$d/$m/${now.year}';
  }
}
