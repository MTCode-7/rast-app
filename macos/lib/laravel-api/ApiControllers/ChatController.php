<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\ChatbotService;
use Illuminate\Http\Request;

class ChatController extends Controller
{
    public function __construct(
        protected ChatbotService $chatbot
    ) {}

    /**
     * Send a message to the chatbot (for mobile app).
     * POST /api/chat/message
     * Body: { "message": "...", "history": [ {"role": "user"|"model", "text": "..."} ] }
     */
    public function message(Request $request)
    {
        $validated = $request->validate([
            'message' => ['required', 'string', 'max:1000'],
            'history' => ['nullable', 'array'],
            'history.*.role' => ['required_with:history', 'string', 'in:user,model'],
            'history.*.text' => ['required_with:history', 'string', 'max:5000'],
        ]);

        $user = $request->user(); // auth:sanctum
        $result = $this->chatbot->sendMessage(
            $validated['message'],
            $validated['history'] ?? [],
            $user,
            true
        );

        if (isset($result['error'])) {
            return response()->json([
                'success' => false,
                'error' => $result['error'],
                'message' => $result['message'] ?? null,
            ], $result['code'] ?? 500);
        }

        return response()->json([
            'success' => true,
            'data' => [
                'reply' => $result['reply'],
                'agents_results' => $result['agents_results'] ?? null,
            ],
        ]);
    }
}
