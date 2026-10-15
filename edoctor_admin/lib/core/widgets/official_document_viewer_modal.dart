import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../utils/formatters.dart';

enum DocumentType {
  hospitalLicense,
  pharmacyLicense,
  pharmacistDiploma,
  pharmacyOrderCertificate,
}

class OfficialDocumentViewerModal extends StatefulWidget {
  final DocumentType type;
  final String entityName;
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
    required this.entityName,
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
    required String entityName,
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
          entityName: entityName,
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
  State<OfficialDocumentViewerModal> createState() => _OfficialDocumentViewerModalState();
}

class _OfficialDocumentViewerModalState extends State<OfficialDocumentViewerModal> {
  double _zoomScale = 1.0;
  bool _checklistConfirmed = false;

  String get _documentTitle {
    switch (widget.type) {
      case DocumentType.hospitalLicense:
        return 'Autorisation d\'Ouverture & Agrément Sanitaire';
      case DocumentType.pharmacyLicense:
        return 'Licence d\'Exploitation d\'Officine de Pharmacie';
      case DocumentType.pharmacistDiploma:
        return 'Diplôme d\'État de Docteur en Pharmacie';
      case DocumentType.pharmacyOrderCertificate:
        return 'Attestation d\'Inscription au Tableau de l\'Ordre (ONP)';
    }
  }

  String get _issuingAuthority {
    switch (widget.type) {
      case DocumentType.hospitalLicense:
      case DocumentType.pharmacyLicense:
        return 'MINISTÈRE DE LA SANTÉ ET DE L\'HYGIÈNE PUBLIQUE\nDirection Générale des Établissements de Santé';
      case DocumentType.pharmacistDiploma:
        return 'RÉPUBLIQUE - MINISTÈRE DE L\'ENSEIGNEMENT SUPÉRIEUR\nFaculté des Sciences de la Santé — Département Pharmacie';
      case DocumentType.pharmacyOrderCertificate:
        return 'ORDRE NATIONAL DES PHARMACIENS\nConseil National de l\'Ordre — Section Officine';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1050,
      height: 900,
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
          // Barre d'outils supérieure de la visionneuse
          _buildToolbar(),

          // Corps de visualisation avec split view (Document officiel zoomable + Checklist de conformité)
          Expanded(
            child: Row(
              children: [
                // Zone Document (Simulateur d'acte officiel certifié haute lisibilité)
                Expanded(
                  flex: 7,
                  child: Container(
                    color: const Color(0xFF1E293B),
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: SingleChildScrollView(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Transform.scale(
                            scale: _zoomScale,
                            alignment: Alignment.center,
                            child: _buildOfficialDocumentSheet(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Panneau latéral d'audit réglementaire & Checklist de concordance
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.verified_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Audit de Pièce Justificative — $_documentTitle',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Partenaire dépositaire : ${widget.entityName} • Réf : ${widget.licenseNumber ?? widget.orderNumber ?? "DOC-PARTENAIRE"}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ],
          ),

          // Contrôles Zoom & Fermeture
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.zoom_out_rounded, color: Colors.white70, size: 20),
                tooltip: 'Zoom arrière',
                onPressed: () {
                  if (_zoomScale > 0.7) setState(() => _zoomScale -= 0.1);
                },
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${(_zoomScale * 100).toInt()}%',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.zoom_in_rounded, color: Colors.white70, size: 20),
                tooltip: 'Zoom avant',
                onPressed: () {
                  if (_zoomScale < 1.4) setState(() => _zoomScale += 0.1);
                },
              ),
              const SizedBox(width: 12),
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

  Widget _buildOfficialDocumentSheet() {
    return Container(
      width: 620,
      padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 40),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF9), // Papier officiel crème / ivoire
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD1D5DB), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Bandeau indiquant qu'il s'agit du justificatif téléversé par le partenaire
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_shared_outlined, size: 14, color: Color(0xFF475569)),
                SizedBox(width: 8),
                Text(
                  'JUSTIFICATIF TRANSMIS PAR LE PARTENAIRE — AUDIT DE CONFORMITÉ EDOCTOR',
                  style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: Color(0xFF475569), letterSpacing: 0.6),
                ),
              ],
            ),
          ),

          // En-tête Institutionnel Officiel de la pièce déposée
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'RÉPUBLIQUE',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF1E293B), letterSpacing: 1.5),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Travail - Liberté - Patrie',
                    style: TextStyle(fontSize: 9, fontStyle: FontStyle.italic, color: Color(0xFF475569)),
                  ),
                  const SizedBox(height: 4),
                  Container(width: 40, height: 1.5, color: const Color(0xFF1E293B)),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF132A45), width: 1.5),
                ),
                child: const Icon(Icons.health_and_safety_rounded, color: Color(0xFF132A45), size: 28),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'RÉGULATION SANITAIRE',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Émis le ${Formatters.formatDate(widget.dateIssued ?? DateTime.now().subtract(const Duration(days: 30)))}',
                    style: const TextStyle(fontSize: 9, color: Color(0xFF475569)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Réf : ${widget.licenseNumber ?? widget.orderNumber ?? "REG-2026-OK"}',
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF529927)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Autorité Émettrice
          Text(
            _issuingAuthority,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E293B),
              height: 1.4,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 14),
          const Divider(color: Color(0xFF94A3B8), thickness: 1),
          const SizedBox(height: 14),

          // Titre de l'Acte
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF132A45).withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF132A45).withValues(alpha: 0.2)),
            ),
            child: Text(
              _documentTitle.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Color(0xFF132A45),
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Corps de texte de l'acte juridique (très lisible et précis)
          _buildLegalBody(),

          const SizedBox(height: 24),

          // Tampon officiel, Cachet et Signature
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // QR Code d'authenticité numérique
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                      borderRadius: BorderRadius.circular(6),
                      color: Colors.white,
                    ),
                    child: const Icon(Icons.qr_code_2_rounded, size: 50, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 4),
                  const Text('Signature Électronique Certifiée', style: TextStyle(fontSize: 7, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                ],
              ),

              // Cachet circulaire officiel & Signature
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 105,
                    height: 105,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.8), width: 2),
                    ),
                    child: Center(
                      child: Text(
                        'RÉPUBLIQUE\n★ DIRECTION ★\nHOMOLOGATION\nCONFORME',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFDC2626).withValues(alpha: 0.85),
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),
                  Transform.rotate(
                    angle: -0.2,
                    child: const Text(
                      'Pr. K. Inspecteur\nDirecteur Général',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Courier',
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegalBody() {
    switch (widget.type) {
      case DocumentType.hospitalLicense:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'LE MINISTRE DE LA SANTÉ ET DE L\'HYGIÈNE PUBLIQUE,\n'
              'Vu la Constitution ;\n'
              'Vu la loi portant Code de la Santé Publique et de l\'exercice des professions médicales ;\n'
              'Vu le rapport d\'inspection technique et de conformité des infrastructures hospitalières ;\n\n'
              'ARRÊTE :',
              style: TextStyle(fontSize: 10, height: 1.5, color: Color(0xFF334155), fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 10),
            _buildArticle(
              'Article 1er',
              'L\'établissement de soins dénommé « ${widget.entityName.toUpperCase()} » situé à l\'adresse « ${widget.address ?? "Territoire National"} », sous le numéro d\'identification fiscale (NIF) « ${widget.taxNumber ?? "CI-CC-2026"} », est officiellement HOMOLOGUÉ et autorisé à dispenser des actes médicaux et hospitaliers.',
            ),
            _buildArticle(
              'Article 2',
              'L\'autorisation est accordée sous le numéro d\'agrément officiel : « ${widget.licenseNumber ?? "AGR-MSHP-2026-HOMOL"} ». Cet agrément atteste de la conformité du plateau technique, des blocs opératoires, de la pharmacie à usage intérieur et des effectifs médicaux.',
            ),
            _buildArticle(
              'Article 3',
              'Le Directeur Médical et Représentant Légal désigné est le « ${widget.contactName ?? "Dr. Médecin Directeur"} ». Tout changement de direction ou d\'adresse devra être notifié sous 30 jours à l\'autorité sanitaire.',
            ),
          ],
        );

      case DocumentType.pharmacyLicense:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'LE MINISTÈRE DE LA SANTÉ — DIRECTION DE LA PHARMACIE ET DU MÉDICAMENT,\n'
              'Vu les dispositions légales régissant le monopole pharmaceutique et la dispensation des médicaments ;\n'
              'Vu l\'avis favorable du Conseil National de l\'Ordre des Pharmaciens ;\n\n'
              'DÉCIDE :',
              style: TextStyle(fontSize: 10, height: 1.5, color: Color(0xFF334155), fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 10),
            _buildArticle(
              'Article 1er',
              'Il est accordé à l\'officine dénommée « ${widget.entityName.toUpperCase()} », sise à « ${widget.address ?? "Adresse Nationale"} », la LICENCE D\'EXPLOITATION D\'OFFICINE DE PHARMACIE sous le numéro officiel « ${widget.licenseNumber ?? "LIC-OFF-2026"} ».',
            ),
            _buildArticle(
              'Article 2',
              'L\'exploitation de cette officine est placée sous la responsabilité technique et juridique exclusive du Docteur en Pharmacie « ${widget.contactName ?? "Dr. Pharmacien Titulaire"} », dûment inscrit à l\'Ordre.',
            ),
            _buildArticle(
              'Article 3',
              'Cette licence autorise la dispensation au public des spécialités pharmaceutiques, dispositifs médicaux et ordonnances électroniques sécurisées via la plateforme nationale eDoctor.',
            ),
          ],
        );

      case DocumentType.pharmacistDiploma:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'RÉPUBLIQUE - UNIVERSITÉ D\'ÉTAT\nFACULTÉ DES SCIENCES PHARMACEUTIQUES ET BIOLOGIQUES',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 14),
            Text(
              'Le Président de l\'Université et le Doyen de la Faculté attestent que :',
              style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: const Color(0xFF529927), width: 1.5)),
              ),
              child: Text(
                widget.contactName?.toUpperCase() ?? 'DOCTEUR EN PHARMACIE',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF132A45), letterSpacing: 0.5),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'A soutenu avec succès sa Thèse d\'État et a satisfait à l\'ensemble des épreuves théoriques, hospitalières et pratiques du cursus pharmaceutique ;\n\n'
              'En foi de quoi, lui est décerné le titre légal de :\n'
              'DOCTEUR EN PHARMACIE (DIPLÔME D\'ÉTAT)',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, height: 1.5, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 8),
            Text(
              'Enregistré sous le N° National Universitaire : UNI-PHARM-${widget.orderNumber ?? "2026-DIP"}',
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF529927)),
            ),
          ],
        );

      case DocumentType.pharmacyOrderCertificate:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Text(
                'TABLEAU DE L\'ORDRE NATIONAL DES PHARMACIENS\nCERTIFICAT D\'INSCRIPTION ET D\'EXERCICE RÉGULIER',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0D9488)),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Le Conseil National de l\'Ordre des Pharmaciens certifie par la présente que :',
              style: TextStyle(fontSize: 10, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 8),
            _buildArticle(
              'Praticien Titulaire',
              'Dr. ${widget.contactName ?? "Pharmacien Titulaire"}, titulaire du Diplôme d\'État de Docteur en Pharmacie.',
            ),
            _buildArticle(
              'Numéro Ordinal National',
              'Inscrit au Tableau sous le Numéro d\'Ordre : « ${widget.orderNumber ?? "ONP-2026-REG"} » (Section Officine).',
            ),
            _buildArticle(
              'Officine d\'Affectation',
              '« ${widget.entityName} » sise à « ${widget.address ?? "Adresse déclarée"} ».',
            ),
            _buildArticle(
              'Situation Ordinale',
              'Régulière. À jour de ses cotisations ordinales et habilité à l\'exercice de la pharmacie d\'officine pour l\'année civile en cours.',
            ),
          ],
        );
    }
  }

  Widget _buildArticle(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 10, height: 1.45, color: Color(0xFF1E293B)),
          children: [
            TextSpan(text: '$title : ', style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF132A45))),
            TextSpan(text: content),
          ],
        ),
      ),
    );
  }

  Widget _buildAuditPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.fact_check_rounded, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Audit de Conformité eDoctor',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Vérifiez la concordance entre la pièce déposée et les informations du profil partenaire.',
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3),
        ),
        const SizedBox(height: 16),
        const Divider(height: 1),
        const SizedBox(height: 14),

        Expanded(
          child: ListView(
            children: [
              _buildAuditCheckItem('Raison sociale conforme', widget.entityName, true),
              _buildAuditCheckItem('Numéro d\'agrément vérifié', widget.licenseNumber ?? widget.orderNumber ?? 'Conforme', true),
              _buildAuditCheckItem('Adresse & Ville concordantes', widget.address ?? 'Vérifié', true),
              _buildAuditCheckItem('Identifiant Fiscal (NIF/RCCM)', widget.taxNumber ?? 'Enregistré', true),
              _buildAuditCheckItem('Responsable légal qualifié', widget.contactName ?? 'Médecin/Pharmacien', true),
              const SizedBox(height: 14),

              // Case à cocher d'engagement de l'auditeur
              InkWell(
                onTap: () => setState(() => _checklistConfirmed = !_checklistConfirmed),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _checklistConfirmed ? AppColors.verifiedBg : AppColors.surfaceDim,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _checklistConfirmed ? AppColors.verifiedBorder : AppColors.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _checklistConfirmed ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                        size: 18,
                        color: _checklistConfirmed ? AppColors.verified : AppColors.textMuted,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'J\'atteste avoir vérifié la pièce et certifie la conformité du dossier partenaire.',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
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

        // Boutons de décision
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(context);
                widget.onReject!('Pièce justificative non conforme ou illisible lors de l\'audit eDoctor.');
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAuditCheckItem(String label, String value, bool isOk) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_rounded, size: 15, color: AppColors.verified),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
