<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Payment;
use Illuminate\Http\Request;

class PaymentController extends Controller
{
    /**
     * POST /api/payments/{payment}/confirm
     * À appeler depuis le callback de l'agrégateur mobile money (ou manuellement en dev).
     */
    public function confirm(Request $request, Payment $payment)
    {
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
    public function fail(Payment $payment)
    {
        $payment->update(['status' => 'echoue']);

        return response()->json($payment);
    }
}
