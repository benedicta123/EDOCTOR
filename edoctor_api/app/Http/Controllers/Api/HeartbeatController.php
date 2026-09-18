<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;

class HeartbeatController extends Controller
{
    /**
     * POST /api/heartbeat
     * L'app appelle cet endpoint toutes les 30-60 secondes tant qu'elle est
     * au premier plan. Aucune action explicite "je suis hors ligne" n'existe :
     * l'absence de heartbeat récent EST le signal d'indisponibilité.
     */
    public function ping(Request $request)
    {
        $request->user()->update(['last_seen_at' => now()]);

        return response()->json(['status' => 'ok']);
    }
}
