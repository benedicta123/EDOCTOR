<?php

use App\Models\Consultation;
use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Schedule;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

Artisan::command('consultations:close-expired', function () {
    $count = Consultation::closeExpiredConsultations();
    $this->info("{$count} consultation(s) expirée(s) clôturée(s) automatiquement après 2h.");
})->purpose('Clôture automatiquement les téléconsultations en cours depuis plus de 2 heures');

Schedule::command('consultations:close-expired')->everyMinute();
