<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Pharmacy;
use App\Models\PharmacyStock;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;

class PharmacyStockController extends Controller
{
    /**
     * GET /api/pharmacies/{pharmacy}/stocks
     */
    public function index(Pharmacy $pharmacy)
    {
        return response()->json(
            $pharmacy->stocks()->with('medication')->get()
        );
    }

    /**
     * POST /api/pharmacies/{pharmacy}/stocks
     * Ajoute ou met à jour le stock d'un médicament donné.
     */
    public function storeOrUpdate(Request $request, Pharmacy $pharmacy)
    {
        Gate::authorize('manageStocks', $pharmacy);

        $validated = $request->validate([
            'medication_id' => ['required', 'exists:medications,id'],
            'quantity' => ['required', 'integer', 'min:0'],
            'price' => ['required', 'numeric', 'min:0'],
        ]);

        $stock = PharmacyStock::updateOrCreate(
            [
                'pharmacy_id' => $pharmacy->id,
                'medication_id' => $validated['medication_id'],
            ],
            [
                'quantity' => $validated['quantity'],
                'price' => $validated['price'],
            ]
        );

        return response()->json($stock->load('medication'), 200);
    }

    /**
     * DELETE /api/pharmacies/{pharmacy}/stocks/{stock}
     */
    public function destroy(Pharmacy $pharmacy, PharmacyStock $stock)
    {
        Gate::authorize('manageStocks', $pharmacy);

        abort_if($stock->pharmacy_id !== $pharmacy->id, 404);

        $stock->delete();

        return response()->json(['message' => 'Médicament retiré du stock.']);
    }

    /**
     * POST /api/pharmacies/{pharmacy}/stocks/import
     * Importation en masse de stocks à partir d'un fichier CSV ou d'un contenu texte CSV.
     */
    public function importCsv(Request $request, Pharmacy $pharmacy)
    {
        Gate::authorize('manageStocks', $pharmacy);

        $csvString = null;

        if ($request->hasFile('file')) {
            $file = $request->file('file');
            $csvString = file_get_contents($file->getRealPath());
        } elseif ($request->filled('csv_content')) {
            $csvString = $request->input('csv_content');
        } else {
            return response()->json([
                'message' => 'Veuillez fournir un fichier CSV ou le contenu textuel CSV (champ "file" ou "csv_content").',
            ], 422);
        }

        // Nettoyage éventuel du BOM UTF-8
        $csvString = preg_replace('/^\xEF\xBB\xBF/', '', $csvString);

        // Découpage en lignes
        $lines = preg_split('/\r\n|\r|\n/', trim($csvString));
        if (empty($lines)) {
            return response()->json(['message' => 'Le fichier CSV est vide.'], 422);
        }

        // Détection automatique du séparateur (, ou ;)
        $firstLine = $lines[0];
        $separator = substr_count($firstLine, ';') > substr_count($firstLine, ',') ? ';' : ',';

        // Lecture des en-têtes
        $rawHeaders = str_getcsv(array_shift($lines), $separator);
        $headers = array_map(function ($h) {
            $normalized = mb_strtolower(trim($h), 'UTF-8');
            $normalized = str_replace([' ', '-', '_', 'é', 'è', 'ê', 'à'], ['', '', '', 'e', 'e', 'e', 'a'], $normalized);
            return $normalized;
        }, $rawHeaders);

        // Détermination des index de colonnes
        $colName = null;
        $colDosage = null;
        $colForm = null;
        $colCategory = null;
        $colQty = null;
        $colPrice = null;
        $colPrescription = null;

        foreach ($headers as $index => $header) {
            if (in_array($header, ['nommedicament', 'nom', 'medicationname', 'designation', 'produit', 'medicament'])) {
                $colName = $index;
            } elseif (in_array($header, ['dosage', 'dosageform', 'dosage_mg'])) {
                $colDosage = $index;
            } elseif (in_array($header, ['forme', 'form', 'formegalenique'])) {
                $colForm = $index;
            } elseif (in_array($header, ['categorie', 'category', 'classe'])) {
                $colCategory = $index;
            } elseif (in_array($header, ['quantite', 'stock', 'quantity', 'qte', 'disponible'])) {
                $colQty = $index;
            } elseif (in_array($header, ['prix', 'prixunitaire', 'price', 'pu', 'prixfcfa', 'prixvente'])) {
                $colPrice = $index;
            } elseif (in_array($header, ['ordonnance', 'surordonnance', 'requiresprescription', 'prescription'])) {
                $colPrescription = $index;
            }
        }

        if ($colName === null || $colQty === null || $colPrice === null) {
            return response()->json([
                'message' => 'Format de fichier non reconnu. Le fichier doit comporter au minimum les colonnes : "Nom médicament", "Quantité", "Prix".',
                'detected_headers' => $rawHeaders,
            ], 422);
        }

        $imported = 0;
        $createdMedications = 0;
        $updatedStocks = 0;
        $errors = [];

        foreach ($lines as $lineIndex => $line) {
            if (trim($line) === '') continue;

            $row = str_getcsv($line, $separator);
            $medName = isset($row[$colName]) ? trim($row[$colName]) : '';

            if (empty($medName)) {
                $errors[] = "Ligne " . ($lineIndex + 2) . " : nom du médicament manquant.";
                continue;
            }

            $rawQty = isset($row[$colQty]) ? trim($row[$colQty]) : '0';
            $rawPrice = isset($row[$colPrice]) ? trim($row[$colPrice]) : '0';

            // Nettoyage numérique (suppression FCFA, espaces, etc.)
            $qty = (int) preg_replace('/[^\d]/', '', $rawQty);
            $cleanPrice = str_replace(',', '.', preg_replace('/[^\d,.]/', '', $rawPrice));
            $price = (float) $cleanPrice;

            $dosage = ($colDosage !== null && isset($row[$colDosage])) ? trim($row[$colDosage]) : null;
            $form = ($colForm !== null && isset($row[$colForm])) ? trim($row[$colForm]) : null;
            $category = ($colCategory !== null && isset($row[$colCategory])) ? trim($row[$colCategory]) : null;

            $requiresPrescription = false;
            if ($colPrescription !== null && isset($row[$colPrescription])) {
                $val = mb_strtolower(trim($row[$colPrescription]));
                $requiresPrescription = in_array($val, ['1', 'true', 'oui', 'yes', 'o']);
            }

            // Recherche ou création du médicament dans le catalogue
            $medication = \App\Models\Medication::whereRaw('LOWER(name) = ?', [mb_strtolower($medName)])->first();
            if (! $medication) {
                $medication = \App\Models\Medication::create([
                    'name' => $medName,
                    'dosage' => $dosage,
                    'form' => $form ?: 'Comprimé',
                    'category' => $category,
                    'requires_prescription' => $requiresPrescription,
                ]);
                $createdMedications++;
            }

            // Mise à jour ou création du stock pour cette officine
            $stock = PharmacyStock::updateOrCreate(
                [
                    'pharmacy_id' => $pharmacy->id,
                    'medication_id' => $medication->id,
                ],
                [
                    'quantity' => $qty,
                    'price' => $price,
                ]
            );

            $updatedStocks++;
            $imported++;
        }

        return response()->json([
            'success' => true,
            'message' => "Importation terminée : {$imported} article(s) traités avec succès.",
            'total_processed' => $imported,
            'updated_stocks' => $updatedStocks,
            'new_medications' => $createdMedications,
            'errors' => $errors,
        ]);
    }

    /**
     * GET /api/pharmacies/stocks/template
     * Téléchargement du modèle de fichier CSV type.
     */
    public function template()
    {
        $csv = "nom_medicament;dosage;forme;quantite;prix_fcfa;sur_ordonnance\n";
        $csv .= "Paracétamol;500mg;Comprimé;150;500;non\n";
        $csv .= "Amoxicilline;1g;Gélule;40;2500;oui\n";
        $csv .= "Artéméther / Luméfantrine;20/120mg;Comprimé;80;1800;non\n";
        $csv .= "Ibuprofène;400mg;Comprimé;100;1200;non\n";
        $csv .= "Sérum Physiologique;0.9% 500ml;Flacon;30;850;non\n";

        return response($csv, 200, [
            'Content-Type' => 'text/csv; charset=UTF-8',
            'Content-Disposition' => 'attachment; filename="modele_import_stocks_edoctor.csv"',
        ]);
    }

    /**
     * GET /api/pharmacies/{pharmacy}/stocks/export
     * Exporte l'ensemble des stocks et du catalogue de l'officine au format CSV standardisé.
     */
    public function exportCsv(Pharmacy $pharmacy)
    {
        Gate::authorize('manageStocks', $pharmacy);

        $stocks = $pharmacy->stocks()->with('medication')->get();

        $pharmacySlug = \Illuminate\Support\Str::slug($pharmacy->name ?: 'officine');
        $filename = "inventaire_{$pharmacySlug}_" . date('Y-m-d') . ".csv";

        $headers = [
            'Content-Type' => 'text/csv; charset=UTF-8',
            'Content-Disposition' => "attachment; filename=\"{$filename}\"",
            'Pragma' => 'no-cache',
            'Cache-Control' => 'must-revalidate, post-check=0, pre-check=0',
            'Expires' => '0',
        ];

        $callback = function () use ($stocks) {
            $handle = fopen('php://output', 'w');
            // BOM UTF-8 pour ouverture directe et propre dans Microsoft Excel francophone
            fprintf($handle, chr(0xEF).chr(0xBB).chr(0xBF));

            // En-têtes CSV standardisés (séparateur point-virgule)
            fputcsv($handle, [
                'ID',
                'Nom Medicament',
                'Dosage',
                'Forme Galenique',
                'Categorie',
                'Quantite en Stock',
                'Prix Unitaire (FCFA)',
                'Valeur Totale (FCFA)',
                'Statut Stock',
                'Sur Ordonnance',
                'Derniere Mise a Jour'
            ], ';');

            foreach ($stocks as $stock) {
                $med = $stock->medication;
                $statusLabel = $stock->quantity <= 0 ? 'Rupture' : ($stock->quantity <= 10 ? 'Stock faible' : 'En stock');
                $totalValue = (int) ($stock->quantity * $stock->price);

                fputcsv($handle, [
                    $med ? $med->id : $stock->id,
                    $med ? $med->name : 'Inconnu',
                    $med ? ($med->dosage ?? '') : '',
                    $med ? ($med->form ?? '') : '',
                    $med ? ($med->category ?? '') : '',
                    $stock->quantity,
                    (int) $stock->price,
                    $totalValue,
                    $statusLabel,
                    ($med && $med->requires_prescription) ? 'Oui' : 'Non',
                    $stock->updated_at ? $stock->updated_at->format('d/m/Y H:i') : '',
                ], ';');
            }

            fclose($handle);
        };

        return response()->stream($callback, 200, $headers);
    }
}
