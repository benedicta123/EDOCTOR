<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;

class NotificationController extends Controller
{
    /**
     * GET /api/notifications
     */
    public function index(Request $request)
    {
        return response()->json(
            $request->user()->notifications()->latest()->get()
        );
    }

    /**
     * POST /api/notifications/{notification}/read
     */
    public function markAsRead(Request $request, \App\Models\Notification $notification)
    {
        abort_if($notification->user_id !== $request->user()->id, 403);

        $notification->update(['read' => true]);

        return response()->json($notification);
    }
}
