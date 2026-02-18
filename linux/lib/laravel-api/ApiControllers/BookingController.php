<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Booking;
use App\Models\ProviderService;
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
            'home_address' => 'required_if:service_type,home_service|nullable|string',
            'home_city' => 'required_if:service_type,home_service|nullable|string',
            'home_district' => 'required_if:service_type,home_service|nullable|string',
            'home_latitude' => 'nullable|numeric',
            'home_longitude' => 'nullable|numeric',
            'notes' => 'nullable|string',
        ]);

        return DB::transaction(function () use ($request, $validated) {
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

            // Calculate pricing
            $servicePrice = $providerService->final_price;
            $homeServiceFee = 0;

            if ($validated['service_type'] === 'home_service') {
                if (!$providerService->provider->home_service_available) {
                    return response()->json([
                        'success' => false,
                        'message' => 'Home service is not available for this provider',
                    ], 422);
                }

                $homeServiceFee = $providerService->home_service_price ?? $providerService->provider->home_service_fee;
            }

            $totalAmount = $servicePrice + $homeServiceFee;

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
                'service_price' => $servicePrice,
                'home_service_fee' => $homeServiceFee,
                'discount_amount' => 0,
                'total_amount' => $totalAmount,
                'platform_commission' => $totalAmount * 0.15, // 15% commission
                'status' => 'pending',
                'payment_status' => 'pending',
                'payment_method' => 'cash',
                'notes' => $validated['notes'] ?? null,
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
}