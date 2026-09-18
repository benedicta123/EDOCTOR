<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Consultation;
use App\Services\NotificationService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;

class MessageController extends Controller
{
    public function index(Request $request, Consultation $consultation)
    {
        Gate::authorize('view', $consultation);

        return response()->json(
            $consultation->messages()->with('sender:id,name,role')->orderBy('created_at')->get()
        );
    }

    public function store(Request $request, Consultation $consultation)
    {
        Gate::authorize('sendMessage', $consultation);

        abort_if(
            in_array($consultation->status, ['terminee', 'annulee']),
            422,
            'Les échanges sont clos : cette consultation est terminée.'
        );

        $validated = $request->validate([
            'content' => ['required', 'string', 'max:2000'],
        ]);

        $message = $consultation->messages()->create([
            'sender_id' => $request->user()->id,
            'content' => $validated['content'],
        ]);

        $recipient = $request->user()->id === $consultation->patient_id
            ? $consultation->doctor
            : $consultation->patient;

        if ($recipient) {
            NotificationService::send(
                $recipient,
                'new_message',
                "Nouveau message de {$request->user()->name}."
            );
        }

        return response()->json($message->load('sender:id,name,role'), 201);
    }
}
