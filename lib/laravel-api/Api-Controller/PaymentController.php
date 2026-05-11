<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Booking;
use App\Services\EdfapayService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

class PaymentController extends Controller
{
    /**
     * إنشاء جلسة دفع لحجز (للتطبيق - يفتح redirect_url في WebView).
     * POST /api/bookings/{id}/payment/session
     */
    public function createSession(Request $request, $id)
    {
        $booking = Booking::with(['provider', 'providerService.service'])->findOrFail($id);

        if ($booking->user_id !== $request->user()->id) {
            return response()->json(['success' => false, 'message' => 'غير مصرح'], 403);
        }

        if ($booking->payment_status === 'paid') {
            return response()->json([
                'success' => false,
                'message' => 'تم الدفع مسبقاً',
                'payment_status' => 'paid',
            ], 400);
        }

        $user = $request->user();
        $nameParts = preg_split('/\s+/', trim($user->name ?? 'Customer'), 2);
        $firstName = $nameParts[0] ?? 'Customer';
        $lastName = $nameParts[1] ?? '.';

        $returnUrl = $request->input('return_url');
        if (!$returnUrl) {
            $returnUrl = route('user.booking-details', $booking);
        }

        $metadata = [
            'booking_id' => $booking->id,
            'description' => 'Booking #' . $booking->booking_number,
            'payer_first_name' => $firstName,
            'payer_last_name' => $lastName,
            'payer_email' => $user->email ?? '',
            'payer_phone' => $user->phone ?? '+966500000000',
            'payer_address' => 'N/A',
            'payer_city' => 'Riyadh',
            'payer_country' => 'SA',
            'payer_zip' => '11111',
            'payer_ip' => $request->ip() ?? '127.0.0.1',
            'return_url' => $returnUrl,
        ];

        try {
            $edfapay = new EdfapayService();
            $amountInCents = (int) round($booking->total_amount * 100);
            $response = $edfapay->createPayment($amountInCents, 'SAR', $metadata);

            if (!$response || !is_array($response)) {
                Log::error('Edfapay API invalid response', ['booking_id' => $booking->id]);
                return response()->json([
                    'success' => false,
                    'message' => 'فشل إنشاء جلسة الدفع',
                ], 500);
            }

            $result = $response['result'] ?? null;
            $hasRedirectUrl = !empty($response['redirect_url']);
            $isSuccess = ($result === 'SUCCESS' || $result === 'REDIRECT' || $hasRedirectUrl);

            if (!$isSuccess) {
                $errorMessage = $response['error_message'] ?? 'خطأ في معالجة الطلب';
                return response()->json([
                    'success' => false,
                    'message' => $errorMessage,
                    'error_code' => $response['error_code'] ?? null,
                ], 400);
            }

            $booking->update(['transaction_id' => $response['order_id'] ?? null]);

            $paymentUrl = $response['redirect_url'] ?? $response['checkout_url'] ?? null;

            return response()->json([
                'success' => true,
                'message' => 'تم إنشاء جلسة الدفع',
                'payment_url' => $paymentUrl,
                'order_id' => $response['order_id'] ?? null,
                'trans_id' => $response['trans_id'] ?? null,
                'booking_id' => $booking->id,
                'total_amount' => (float) $booking->total_amount,
                'currency' => 'SAR',
            ]);
        } catch (\Exception $e) {
            Log::error('Edfapay API exception', ['booking_id' => $booking->id, 'error' => $e->getMessage()]);
            return response()->json([
                'success' => false,
                'message' => 'حدث خطأ غير متوقع',
                'debug' => config('app.debug') ? $e->getMessage() : null,
            ], 500);
        }
    }

    /**
     * حالة الدفع لحجز (للاستعلام بعد العودة من WebView).
     * GET /api/bookings/{id}/payment/status
     */
    public function status(Request $request, $id)
    {
        $booking = Booking::findOrFail($id);

        if ($booking->user_id !== $request->user()->id) {
            return response()->json(['success' => false, 'message' => 'غير مصرح'], 403);
        }

        return response()->json([
            'success' => true,
            'data' => [
                'booking_id' => $booking->id,
                'booking_number' => $booking->booking_number,
                'payment_status' => $booking->payment_status,
                'payment_method' => $booking->payment_method ?? null,
                'paid_at' => $booking->payment_status === 'paid' ? $booking->updated_at?->toIso8601String() : null,
                'total_amount' => (float) $booking->total_amount,
            ],
        ]);
    }
}
