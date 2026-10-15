<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Payment;
use Illuminate\Http\Request;

class PaymentController extends Controller
{
    /**
     * POST /api/payments/{payment}/confirm
     * Réservé exclusivement à l'administration en environnement local ou de test.
     * En production, les règlements doivent impérativement transiter par la passerelle officielle certifiée.
     */
    public function confirm(Request $request, Payment $payment)
    {
        abort_if(
            ! app()->environment('local', 'testing'),
            403,
            "Cet endpoint de confirmation manuelle est strictement désactivé en environnement de production."
        );

        abort_if(
            ! $request->user()?->isAdmin(),
            403,
            "Accès réservé exclusivement aux administrateurs autorisés."
        );

        $validated = $request->validate([
            'transaction_ref' => ['required', 'string'],
        ]);

        $payment->update([
            'status' => 'confirme',
            'transaction_ref' => $validated['transaction_ref'],
        ]);

        return response()->json($payment->load('order'));
    }

    /**
     * POST /api/payments/{payment}/fail
     */
    public function fail(Request $request, Payment $payment)
    {
        abort_if(
            ! app()->environment('local', 'testing'),
            403,
            "Cet endpoint est strictement désactivé en environnement de production."
        );

        abort_if(
            ! $request->user()?->isAdmin(),
            403,
            "Accès réservé exclusivement aux administrateurs autorisés."
        );

        $payment->update(['status' => 'echoue']);

        return response()->json($payment);
    }
}
