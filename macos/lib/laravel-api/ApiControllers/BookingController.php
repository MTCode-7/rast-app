<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Booking;
use App\Models\ProviderService;
use App\Models\Settings;
use App\Models\TimeSlot;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class BookingController extends Controller
{
    public function index(Request $request)
    {
        $bookings = Booking::with([
            'provider',
            'providerService.service',
            'timeSlot'
        ])
        ->forUser($request->user()->id)
        ->latest()
        ->paginate(15);

        return response()->json([
            'success' => true,
            'data' => $bookings,
        ]);
    }

    public function upcoming(Request $request)
    {
        $bookings = Booking::with([
            'provider',
            'providerService.service',
            'timeSlot'
        ])
        ->forUser($request->user()->id)
        ->upcoming()
        ->latest()
        ->get();

        return response()->json([
            'success' => true,
            'data' => $bookings,
        ]);
    }

    public function past(Request $request)
    {
        $bookings = Booking::with([
            'provider',
            'providerService.service',
            'timeSlot',
            'review'
        ])
        ->forUser($request->user()->id)
        ->past()
        ->latest()
        ->paginate(15);

        return response()->json([
            'success' => true,
            'data' => $bookings,
        ]);
    }

    public function store(Request $request)
    {
        $validated = $request->validate([
            'provider_service_id' => 'required|exists:provider_services,id',
            'time_slot_id' => 'required|exists:time_slots,id',
            'service_type' => 'required|in:in_clinic,home_service',
            'nationality' => 'nullable|in:saudi,non_saudi', // للضريبة: non_saudi يطبق عليها VAT
            'home_address' => 'required_if:service_type,home_service|nullable|string',
            'home_city' => 'required_if:service_type,home_service|nullable|string',
            'home_district' => 'required_if:service_type,home_service|nullable|string',
            'home_latitude' => 'nullable|numeric',
            'home_longitude' => 'nullable|numeric',
            'notes' => 'nullable|string',
        ]);

        $nationality = $validated['nationality'] ?? 'saudi';

        return DB::transaction(function () use ($request, $validated, $nationality) {
            // Get provider service
            $providerService = ProviderService::with(['provider', 'service'])
                ->findOrFail($validated['provider_service_id']);

            // Check if service is available
            if (!$providerService->is_available) {
                return response()->json([
                    'success' => false,
                    'message' => 'This service is currently not available',
                ], 422);
            }

            // Get and check time slot
            $timeSlot = TimeSlot::findOrFail($validated['time_slot_id']);

            if (!$timeSlot->hasAvailability()) {
                return response()->json([
                    'success' => false,
                    'message' => 'This time slot is no longer available',
                ], 422);
            }

            // Pricing (same logic as User\BookingController for analyses & packages)
            $inClinicPrice = (float) $providerService->final_price;
            $homeServiceFee = 0;

            if ($validated['service_type'] === 'home_service') {
                if (!$providerService->provider->home_service_available) {
                    return response()->json([
                        'success' => false,
                        'message' => 'Home service is not available for this provider',
                    ], 422);
                }

                $homeServiceFee = (float) ($providerService->home_service_price ?? $providerService->provider->home_service_fee ?? 0);
            }

            $settings = Settings::first();
            $platformDiscountRate = $settings->platform_discount_rate / 100;
            $vatRate = $settings->vat_rate / 100;

            $basePrice = $inClinicPrice + $homeServiceFee;
            $platformDiscount = round($inClinicPrice * $platformDiscountRate, 2);
            $subTotal = round($basePrice - $platformDiscount, 2);

            $vatAmount = 0;
            if ($nationality === 'non_saudi') {
                $vatAmount = round($subTotal * $vatRate, 2);
            }

            $totalAmount = round($subTotal + $vatAmount, 2);
            $originalPriceBeforeDiscount = $totalAmount / (1 - $platformDiscountRate);
            $platformCommission = round(0.15 * $originalPriceBeforeDiscount, 2);

            $metadata = [
                'nationality' => $nationality,
                'vat_amount' => (float) round($vatAmount, 2),
                'platform_discount' => (float) round($platformDiscount, 2),
                'platform_discount_rate' => (float) round($platformDiscountRate, 4),
            ];

            // Create booking
            $booking = Booking::create([
                'user_id' => $request->user()->id,
                'provider_id' => $providerService->provider_id,
                'provider_service_id' => $providerService->id,
                'time_slot_id' => $timeSlot->id,
                'booking_date' => $timeSlot->date,
                'booking_time' => $timeSlot->start_time,
                'service_type' => $validated['service_type'],
                'home_address' => $validated['home_address'] ?? null,
                'home_city' => $validated['home_city'] ?? null,
                'home_district' => $validated['home_district'] ?? null,
                'home_latitude' => $validated['home_latitude'] ?? null,
                'home_longitude' => $validated['home_longitude'] ?? null,
                'service_price' => $inClinicPrice,
                'home_service_fee' => $homeServiceFee,
                'discount_amount' => $platformDiscount,
                'total_amount' => $totalAmount,
                'platform_commission' => $platformCommission,
                'status' => 'pending',
                'payment_status' => 'pending',
                'payment_method' => 'cash',
                'notes' => $validated['notes'] ?? null,
                'metadata' => $metadata,
            ]);

            // Update time slot
            $timeSlot->increment('current_bookings');

            return response()->json([
                'success' => true,
                'message' => 'Booking created successfully',
                'data' => $booking->load(['provider', 'providerService.service']),
            ], 201);
        });
    }

    public function show($id)
    {
        $booking = Booking::with([
            'provider',
            'providerService.service',
            'timeSlot',
            'review'
        ])
        ->forUser(auth()->id())
        ->findOrFail($id);

        return response()->json([
            'success' => true,
            'data' => $booking,
        ]);
    }

    public function cancel(Request $request, $id)
    {
        $booking = Booking::forUser($request->user()->id)->findOrFail($id);

        if (!$booking->canBeCancelled()) {
            return response()->json([
                'success' => false,
                'message' => 'This booking cannot be cancelled',
            ], 422);
        }

        $validated = $request->validate([
            'reason' => 'required|string',
        ]);

        $booking->cancel($validated['reason']);

        return response()->json([
            'success' => true,
            'message' => 'Booking cancelled successfully',
            'data' => $booking,
        ]);
    }

    /**
     * إضافة تقييم لحجز مكتمل.
     * POST /api/reviews
     * Body: booking_id, rating (1-5), comment (اختياري)
     */
    public function storeReview(Request $request)
    {
        $validated = $request->validate([
            'booking_id' => 'required|exists:bookings,id',
            'rating' => 'required|integer|min:1|max:5',
            'comment' => 'nullable|string|max:1000',
        ]);

        $booking = Booking::with('provider')
            ->forUser($request->user()->id)
            ->findOrFail($validated['booking_id']);

        if ($booking->status !== 'completed') {
            return response()->json([
                'success' => false,
                'message' => 'لا يمكن التقييم إلا للحجوزات المكتملة',
            ], 422);
        }

        $review = $booking->review;
        if ($review) {
            $review->update([
                'rating' => $validated['rating'],
                'comment' => $validated['comment'] ?? $review->comment,
            ]);
            return response()->json([
                'success' => true,
                'message' => 'تم تحديث التقييم',
                'data' => $review->load('user'),
            ]);
        }

        $review = \App\Models\Review::create([
            'booking_id' => $booking->id,
            'provider_id' => $booking->provider_id,
            'user_id' => $request->user()->id,
            'rating' => $validated['rating'],
            'comment' => $validated['comment'] ?? null,
        ]);

        return response()->json([
            'success' => true,
            'message' => 'تم إضافة التقييم بنجاح',
            'data' => $review->load('user'),
        ], 201);
    }
}