<?php

use App\Http\Controllers\Api\AdminController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\ClaimController;
use App\Http\Controllers\Api\ConsultationController;
use App\Http\Controllers\Api\ConsultationVideoController;
use App\Http\Controllers\Api\DeliveryController;
use App\Http\Controllers\Api\DoctorController;
use App\Http\Controllers\Api\DoctorDashboardController;
use App\Http\Controllers\Api\HeartbeatController;
use App\Http\Controllers\Api\HospitalRegistrationController;
use App\Http\Controllers\Api\HospitalStaffController;
use App\Http\Controllers\Api\HospitalDashboardController;
use App\Http\Controllers\Api\HospitalVerificationController;
use App\Http\Controllers\Api\LabRequestController;
use App\Http\Controllers\Api\MedicationAvailabilityController;
use App\Http\Controllers\Api\MedicationController;
use App\Http\Controllers\Api\MessageController;
use App\Http\Controllers\Api\NotificationController;
use App\Http\Controllers\Api\NurseVisitController;
use App\Http\Controllers\Api\OrderController;
use App\Http\Controllers\Api\PatientDossierController;
use App\Http\Controllers\Api\PaymentController;
use App\Http\Controllers\Api\PharmacyController;
use App\Http\Controllers\Api\PharmacyRegistrationController;
use App\Http\Controllers\Api\PharmacyStockController;
use App\Http\Controllers\Api\PrescriptionController;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

// --- Routes Publiques ---
// Inscription Patient dédiée (sur l'app mobile ou web)
Route::post('/register', [AuthController::class, 'register']);
Route::post('/patients/register', [AuthController::class, 'register']);
Route::post('/login', [AuthController::class, 'login']);

// Inscription Hôpital & Super-Admin (Shopify-like)
Route::post('/hospitals/register', [HospitalRegistrationController::class, 'register']);
Route::post('/hospitals/geocode', [HospitalRegistrationController::class, 'geocode']);

// Inscription & Suivi d'Agrément Pharmacie (KYP)
Route::post('/pharmacies/register', [PharmacyRegistrationController::class, 'register']);
Route::post('/pharmacies/track-status', [PharmacyRegistrationController::class, 'trackStatus']);

// Catalogue médicaments & officines
Route::get('/medications', [MedicationController::class, 'index']);
Route::get('/medications/{medication}', [MedicationController::class, 'show']);
Route::get('/medications/{medication}/availability', [MedicationAvailabilityController::class, 'nearby']);
Route::get('/pharmacies', [PharmacyController::class, 'index']);
Route::get('/pharmacies/{pharmacy}', [PharmacyController::class, 'show']);

// Médecins disponibles (accessible aux patients pour recherche rapide)
Route::get('/doctors/available', [DoctorController::class, 'available']);

// Webhook / Callbacks de paiement
Route::post('/payments/{payment}/confirm', [PaymentController::class, 'confirm']);
Route::post('/payments/{payment}/fail', [PaymentController::class, 'fail']);

// --- Routes Protégées (nécessitent un token Sanctum valide) ---
Route::middleware('auth:sanctum')->group(function () {
    Route::get('/user', fn (Request $request) => $request->user());
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::get('/me', [AuthController::class, 'me']);
    Route::put('/profile', [AuthController::class, 'updateProfile']);
    Route::post('/heartbeat', [HeartbeatController::class, 'ping']);

    // Téléconsultations
    Route::get('/consultations', [ConsultationController::class, 'index']);
    Route::post('/consultations', [ConsultationController::class, 'store']);
    Route::post('/consultations/{consultation}/pay', [ConsultationController::class, 'pay']);
    Route::post('/consultations/{consultation}/start', [ConsultationController::class, 'start']);
    Route::post('/consultations/{consultation}/decline', [ConsultationController::class, 'decline']);
    Route::post('/consultations/{consultation}/end', [ConsultationController::class, 'end']);
    Route::post('/consultations/{consultation}/cancel', [ConsultationController::class, 'cancel']);
    Route::post('/consultations/{consultation}/join', [ConsultationVideoController::class, 'join']);

    // Dashboards médecin
    Route::get('/doctor/dashboard', [DoctorDashboardController::class, 'dashboard']);
    Route::get('/doctor/patients', [DoctorDashboardController::class, 'patients']);
    Route::get('/doctor/profile', [DoctorDashboardController::class, 'profile']);
    Route::put('/doctor/profile', [DoctorDashboardController::class, 'updateProfile']);
    Route::patch('/doctor/availability', [DoctorDashboardController::class, 'availability']);

    // Messagerie de consultation
    Route::get('/consultations/{consultation}/messages', [MessageController::class, 'index']);
    Route::post('/consultations/{consultation}/messages', [MessageController::class, 'store']);

    // Ordonnances / Prescriptions
    Route::get('/prescriptions', [PrescriptionController::class, 'index']);
    Route::post('/prescriptions', [PrescriptionController::class, 'store']);
    Route::get('/prescriptions/{prescription}', [PrescriptionController::class, 'show']);
    Route::post('/prescriptions/{prescription}/cancel', [PrescriptionController::class, 'cancel']);

    // Examens complémentaires & bilans de laboratoire
    Route::get('/lab-requests/my', [LabRequestController::class, 'indexMine']);
    Route::get('/lab-requests/{labRequest}', [LabRequestController::class, 'show']);
    Route::post('/lab-requests/{labRequest}/results', [LabRequestController::class, 'uploadResults']);
    Route::post('/lab-requests/{labRequest}/review', [LabRequestController::class, 'review']);
    Route::get('/consultations/{consultation}/lab-requests', [LabRequestController::class, 'indexConsultation']);
    Route::post('/consultations/{consultation}/lab-requests', [LabRequestController::class, 'store']);

    // Dossier médical patient
    Route::get('/patients/{patient}/dossier', [PatientDossierController::class, 'show']);

    // Réclamations, litiges et assistance usagers (patients & praticiens)
    Route::get('/claims/my', [ClaimController::class, 'indexMine']);
    Route::post('/claims', [ClaimController::class, 'store']);

    // Commandes en pharmacie
    Route::get('/orders', [OrderController::class, 'index']);
    Route::post('/orders', [OrderController::class, 'store']);
    Route::post('/orders/quote', [OrderController::class, 'quote']);
    Route::get('/orders/{order}', [OrderController::class, 'show']);
    Route::post('/orders/{order}/mark-ready', [OrderController::class, 'markReady']);
    Route::post('/orders/{order}/mark-collected', [OrderController::class, 'markCollected']);
    Route::post('/orders/{order}/cancel', [OrderController::class, 'cancel']);

    // Livraison de médicaments
    Route::post('/deliveries/quote', [DeliveryController::class, 'quote']);
    Route::post('/orders/{order}/delivery', [DeliveryController::class, 'store']);
    Route::post('/deliveries/{delivery}/assign', [DeliveryController::class, 'assign']);
    Route::post('/deliveries/{delivery}/mark-delivered', [DeliveryController::class, 'markDelivered']);

    // Espace Pharmacie & Inventaire (pour pharmaciens)
    Route::get('/my-pharmacy', [PharmacyController::class, 'mine']);
    Route::put('/pharmacies/{pharmacy}', [PharmacyController::class, 'update']);
    Route::get('/pharmacies/stocks/template', [PharmacyStockController::class, 'template']);
    Route::get('/pharmacies/{pharmacy}/stocks', [PharmacyStockController::class, 'index']);
    Route::get('/pharmacies/{pharmacy}/stocks/export', [PharmacyStockController::class, 'exportCsv']);
    Route::post('/pharmacies/{pharmacy}/stocks', [PharmacyStockController::class, 'storeOrUpdate']);
    Route::post('/pharmacies/{pharmacy}/stocks/import', [PharmacyStockController::class, 'importCsv']);
    Route::delete('/pharmacies/{pharmacy}/stocks/{stock}', [PharmacyStockController::class, 'destroy']);

    // Soins à domicile (Visites infirmières)
    Route::post('/prescriptions/{prescription}/nurse-visit', [NurseVisitController::class, 'store']);
    Route::get('/hospitals/{hospital}/nurse-visits', [NurseVisitController::class, 'index']);
    Route::post('/nurse-visits/{nurseVisit}/assign', [NurseVisitController::class, 'assign']);
    Route::post('/nurse-visits/{nurseVisit}/accept', [NurseVisitController::class, 'accept']);
    Route::post('/nurse-visits/{nurseVisit}/decline', [NurseVisitController::class, 'decline']);
    Route::post('/nurse-visits/{nurseVisit}/complete', [NurseVisitController::class, 'complete']);

    // Notifications
    Route::get('/notifications', [NotificationController::class, 'index']);
    Route::post('/notifications/{notification}/read', [NotificationController::class, 'markAsRead']);

    // Espace Administration Hôpital & Gestion du Personnel Soignant
    Route::get('/my-hospital', [HospitalRegistrationController::class, 'myHospital']);
    Route::get('/my-hospital/staff', [HospitalStaffController::class, 'index']);
    Route::post('/my-hospital/doctors', [HospitalStaffController::class, 'storeDoctor']);
    Route::post('/my-hospital/nurses', [HospitalStaffController::class, 'storeNurse']);
    Route::get('/my-hospital/dashboard', [HospitalDashboardController::class, 'dashboard']);
    Route::get('/my-hospital/consultations', [HospitalDashboardController::class, 'consultations']);
    Route::get('/my-hospital/statistics', [HospitalDashboardController::class, 'statistics']);
    Route::put('/my-hospital', [HospitalDashboardController::class, 'updateHospital']);

    // Vérification administrative Hôpital (Back-Office eDoctor)
    Route::get('/admin/hospitals/pending', [HospitalVerificationController::class, 'index']);
    Route::post('/admin/hospitals/{hospital}/verify', [HospitalVerificationController::class, 'verify']);
    Route::post('/admin/hospitals/{hospital}/reject', [HospitalVerificationController::class, 'reject']);

    // ==========================================
    // ESPACE SUPER-ADMIN & RÉGULATION NATIONALE
    // ==========================================
    Route::prefix('admin')->group(function () {
        // Vue d'ensemble statistique nationale
        Route::get('/overview', [AdminController::class, 'overview']);

        // Module de validation et conformité des Hôpitaux
        Route::get('/hospitals', [AdminController::class, 'hospitals']);
        Route::post('/hospitals/{hospital}/verify', [AdminController::class, 'verifyHospital']);
        Route::post('/hospitals/{hospital}/reject', [AdminController::class, 'rejectHospital']);
        Route::post('/hospitals/{hospital}/suspend', [AdminController::class, 'suspendHospital']);
        Route::post('/hospitals/{hospital}/reactivate', [AdminController::class, 'reactivateHospital']);

        // Module de validation et conformité des Pharmacies
        Route::get('/pharmacies', [AdminController::class, 'pharmacies']);
        Route::post('/pharmacies/{pharmacy}/verify', [AdminController::class, 'verifyPharmacy']);
        Route::post('/pharmacies/{pharmacy}/reject', [AdminController::class, 'rejectPharmacy']);
        Route::post('/pharmacies/{pharmacy}/suspend', [AdminController::class, 'suspendPharmacy']);
        Route::post('/pharmacies/{pharmacy}/reactivate', [AdminController::class, 'reactivatePharmacy']);

        // Gestion des utilisateurs et modération (suspension / réactivation)
        Route::get('/users', [AdminController::class, 'users']);
        Route::post('/users/{user}/suspend', [AdminController::class, 'suspendUser']);
        Route::post('/users/{user}/reactivate', [AdminController::class, 'reactivateUser']);

        // Journal de gestion des réclamations et litiges
        Route::get('/claims', [AdminController::class, 'claims']);
        Route::post('/claims', [AdminController::class, 'storeClaim']);
        Route::post('/claims/{claim}/resolve', [AdminController::class, 'resolveClaim']);
        Route::post('/claims/{claim}/status', [AdminController::class, 'updateClaimStatus']);
    });

    // Utilitaire développement (Auto-vérification en 1 clic)
    Route::post('/dev/hospitals/{hospital}/quick-verify', [HospitalVerificationController::class, 'quickVerify']);
});
