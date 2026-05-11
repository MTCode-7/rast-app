<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * مورد API للحجز - يضمن إرجاع المبالغ كأرقام (وليس نصوص)
 * حتى يعرض التطبيق ملخص الحجز بشكل صحيح.
 */
class BookingResource extends JsonResource
{
    private function formatDate($value): ?string
    {
        if ($value === null) return null;
        if (is_string($value)) return $value;
        if (is_object($value) && method_exists($value, 'format')) {
            return $value->format('Y-m-d');
        }
        return (string) $value;
    }

    private function formatDateTime($value): ?string
    {
        if ($value === null) return null;
        if (is_string($value)) return $value;
        if (is_object($value) && method_exists($value, 'toIso8601String')) {
            return $value->toIso8601String();
        }
        if (is_object($value) && method_exists($value, 'format')) {
            return $value->format(\DateTimeInterface::ATOM);
        }
        return (string) $value;
    }

    /**
     * @return array{period_key: string|null, period_label_ar: string|null}
     */
    private function periodMetaFromStartTime(?string $startTime): array
    {
        if ($startTime === null || $startTime === '') {
            return ['period_key' => null, 'period_label_ar' => null];
        }
        $startTime = trim($startTime);
        $parts = explode(':', $startTime);
        $hour = (int) ($parts[0] ?? 0);
        if ($hour >= 0 && $hour < 6) {
            return [
                'period_key' => 'night',
                'period_label_ar' => 'منتصف الليل – الفجر (٠٠:٠٠ – ٠٦:٠٠)',
            ];
        }
        if ($hour >= 6 && $hour < 12) {
            return [
                'period_key' => 'morning',
                'period_label_ar' => 'الصباح (٠٦:٠٠ – ١٢:٠٠)',
            ];
        }
        if ($hour >= 12 && $hour < 18) {
            return [
                'period_key' => 'afternoon',
                'period_label_ar' => 'بعد الظهر (١٢:٠٠ – ١٨:٠٠)',
            ];
        }

        return [
            'period_key' => 'evening',
            'period_label_ar' => 'المساء – الليل (١٨:٠٠ – ٢٤:٠٠)',
        ];
    }

    public function toArray(Request $request): array
    {
        $booking = $this->resource;

        // تحويل المبالغ إلى أرقام صريحة (Laravel يرجع decimal كنص في JSON)
        $servicePrice = (float) $booking->service_price;
        $homeServiceFee = (float) ($booking->home_service_fee ?? 0);
        $discountAmount = (float) ($booking->discount_amount ?? 0);
        $totalAmount = (float) $booking->total_amount;
        $rawMeta = $booking->metadata;
        $metadata = is_array($rawMeta) ? $rawMeta : (is_string($rawMeta) ? (json_decode($rawMeta, true) ?: []) : []);

        $platformDiscount = (float) ($metadata['platform_discount'] ?? $discountAmount);
        if ($discountAmount == 0 && $platformDiscount > 0) {
            $discountAmount = $platformDiscount;
        }

        $summary = [
            'service_price' => round($servicePrice, 2),
            'home_service_fee' => round($homeServiceFee, 2),
            'discount_amount' => round($discountAmount, 2),
            'platform_discount' => (float) round($platformDiscount, 2),
            'vat_amount' => (float) ($metadata['vat_amount'] ?? 0),
            'sub_total' => round($servicePrice + $homeServiceFee - $discountAmount, 2),
            'total_amount' => round($totalAmount, 2),
            'currency' => 'SAR',
        ];

        $bookingPeriodMeta = ['period_key' => null, 'period_label_ar' => null];
        if ($booking->relationLoaded('timeSlot') && $booking->timeSlot) {
            $start = $booking->timeSlot->start_time;
            $startStr = is_string($start) ? $start : (is_object($start) && method_exists($start, 'format') ? $start->format('H:i:s') : null);
            $bookingPeriodMeta = $this->periodMetaFromStartTime($startStr);
        } elseif ($booking->booking_time) {
            $bt = $booking->booking_time;
            $startStr = is_string($bt) ? $bt : (is_object($bt) && method_exists($bt, 'format') ? $bt->format('H:i:s') : null);
            $bookingPeriodMeta = $this->periodMetaFromStartTime($startStr);
        }

        return [
            'id' => $booking->id,
            'booking_number' => $booking->booking_number,
            'booking_date' => $this->formatDate($booking->booking_date),
            'booking_time' => $booking->booking_time,
            'booking_period_key' => $bookingPeriodMeta['period_key'],
            'booking_period_label_ar' => $bookingPeriodMeta['period_label_ar'],
            'service_type' => $booking->service_type,
            'status' => $booking->status,
            'payment_status' => $booking->payment_status,
            'payment_method' => $booking->payment_method,
            'notes' => $booking->notes,
            'home_address' => $booking->home_address,
            'home_city' => $booking->home_city,
            'home_district' => $booking->home_district,
            'home_latitude' => $booking->home_latitude ? (float) $booking->home_latitude : null,
            'home_longitude' => $booking->home_longitude ? (float) $booking->home_longitude : null,
            // ملخص الحجز - كل القيم أرقام للتطبيق
            'summary' => $summary,
            // المبالغ أيضاً في الجذر لعدم كسر التطبيقات الحالية
            'service_price' => $summary['service_price'],
            'home_service_fee' => $summary['home_service_fee'],
            'discount_amount' => $summary['discount_amount'],
            'total_amount' => $summary['total_amount'],
            'metadata' => $metadata,
            'confirmed_at' => $this->formatDateTime($booking->confirmed_at),
            'completed_at' => $this->formatDateTime($booking->completed_at),
            'cancelled_at' => $this->formatDateTime($booking->cancelled_at),
            'created_at' => $this->formatDateTime($booking->created_at),
            'updated_at' => $this->formatDateTime($booking->updated_at),
            // العلاقات (whenLoaded تُستدعى على الـ Resource = $this وليس على الموديل)
            'provider' => $this->whenLoaded('provider', fn () => [
                'id' => $booking->provider->id,
                'business_name_ar' => $booking->provider->business_name_ar,
                'business_name_en' => $booking->provider->business_name_en ?? null,
                'contact_phone' => $booking->provider->contact_phone ?? null,
                'whatsapp' => $booking->provider->whatsapp ?? null,
                'home_service_available' => (bool) $booking->provider->home_service_available,
            ]),
            'provider_service' => $this->whenLoaded('providerService', function () use ($booking) {
                $ps = $booking->providerService;
                if (!$ps) return null;
                return [
                    'id' => $ps->id,
                    'final_price' => (float) $ps->final_price,
                    'duration' => (int) $ps->duration,
                    'service' => $ps->relationLoaded('service') && $ps->service ? [
                        'id' => $ps->service->id,
                        'name_ar' => $ps->service->name_ar,
                        'name_en' => $ps->service->name_en ?? null,
                        'category' => $ps->service->relationLoaded('category') && $ps->service->category ? [
                            'id' => $ps->service->category->id,
                            'name_ar' => $ps->service->category->name_ar,
                            'name_en' => $ps->service->category->name_en ?? null,
                        ] : null,
                    ] : null,
                ];
            }),
            'time_slot' => $this->whenLoaded('timeSlot', function () use ($booking) {
                $ts = $booking->timeSlot;
                if (!$ts) return null;
                $date = $ts->date;
                $dateStr = is_object($date) && method_exists($date, 'format') ? $date->format('Y-m-d') : (string) $date;
                $startRaw = $ts->start_time;
                $startStr = is_string($startRaw) ? $startRaw : (is_object($startRaw) && method_exists($startRaw, 'format') ? $startRaw->format('H:i:s') : null);
                $period = $this->periodMetaFromStartTime($startStr);

                return [
                    'id' => $ts->id,
                    'date' => $dateStr,
                    'start_time' => $ts->start_time,
                    'end_time' => $ts->end_time,
                    'period_key' => $period['period_key'],
                    'period_label_ar' => $period['period_label_ar'],
                ];
            }),
            'review' => $this->whenLoaded('review', fn () => $booking->review ? [
                'id' => $booking->review->id,
                'rating' => (int) $booking->review->rating,
                'comment' => $booking->review->comment,
            ] : null),
        ];
    }
}
