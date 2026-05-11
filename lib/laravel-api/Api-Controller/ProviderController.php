<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Branch;
use App\Models\Provider;
use Illuminate\Http\Request;

class ProviderController extends Controller
{
    public function index(Request $request)
    {
        $query = Provider::with(['user', 'services'])
            ->active()
            ->approved();

        // Filter by city
        if ($request->has('city')) {
            $query->inCity($request->city);
        }

        // Filter by home service
        if ($request->boolean('home_service')) {
            $query->withHomeService();
        }

        // Filter by service
        if ($request->has('service_id')) {
            $query->whereHas('services', function ($q) use ($request) {
                $q->where('services.id', $request->service_id);
            });
        }

        // Filter by location (nearby)
        if ($request->has('latitude') && $request->has('longitude')) {
            $query->nearby(
                $request->latitude,
                $request->longitude,
                $request->get('radius', 10)
            );
        }

        // Sorting
        if ($request->get('sort') === 'rating') {
            $query->orderByDesc('avg_rating');
        } elseif ($request->get('sort') === 'featured') {
            $query->orderByDesc('is_featured');
        }

        $providers = $query->paginate($request->get('per_page', 15));

        return response()->json([
            'success' => true,
            'data' => $providers,
        ]);
    }

    public function show($id)
    {
        $provider = Provider::with([
            'user',
            'providerServices.service.category',
            'reviews.user',
            'offers' => function ($query) {
                $query->active();
            }
        ])
        ->active()
        ->approved()
        ->findOrFail($id);

        return response()->json([
            'success' => true,
            'data' => $provider,
        ]);
    }

    /**
     * إضافة image_url (رابط كامل) من حقل image إن وُجد، لظهور الصور في التطبيق.
     */
    private function appendImageUrl($model): array
    {
        $arr = $model instanceof \Illuminate\Database\Eloquent\Model ? $model->toArray() : (array) $model;
        $path = $arr['image'] ?? $arr['image_path'] ?? $arr['photo'] ?? null;
        if ($path && is_string($path)) {
            $arr['image_url'] = str_starts_with($path, 'http') ? $path : asset('storage/' . ltrim($path, '/'));
        }
        return $arr;
    }

    public function services($id)
    {
        $provider = Provider::active()->approved()->findOrFail($id);

        $services = $provider->providerServices()
            ->with('service.category')
            ->where('is_available', true)
            ->get()
            ->map(fn ($ps) => $this->appendImageUrl($ps));

        return response()->json([
            'success' => true,
            'data' => $services,
        ]);
    }

    public function timeSlots(Request $request, $id)
    {
        $validated = $request->validate([
            'date' => 'required|date|after_or_equal:today',
        ]);

        $provider = Provider::active()->approved()->findOrFail($id);
        $date = \Carbon\Carbon::parse($validated['date']);
        $maxDate = \Carbon\Carbon::today()->addDays(config('timeslots.generate_ahead_days', 2));

        if ($date->lte($maxDate)) {
            \App\Services\TimeSlotGenerator::generateForProviderBetweenDates(
                $provider,
                $date->copy(),
                $date->copy(),
                []
            );
        }

        $timeSlots = $provider->timeSlots()
            ->available()
            ->forDate($validated['date'])
            ->orderBy('start_time')
            ->get();

        $data = $timeSlots->map(function ($ts) {
            $arr = $ts->toArray();
            $meta = self::periodMetaFromStartTime($arr['start_time'] ?? null);
            $arr['period_key'] = $meta['period_key'];
            $arr['period_label_ar'] = $meta['period_label_ar'];
            if (!array_key_exists('remaining_capacity', $arr)) {
                $remaining = null;
                if (isset($arr['capacity'])) {
                    $booked = (int) ($arr['bookings_count'] ?? $arr['booked_count'] ?? 0);
                    $remaining = max(0, (int) $arr['capacity'] - $booked);
                }
                $arr['remaining_capacity'] = $remaining;
            }

            return $arr;
        });

        return response()->json([
            'success' => true,
            'data' => $data,
        ]);
    }

    /**
     * فترات الحجز الأربع (كل فترة 6 ساعات) — متوافق مع مواصفات التطبيق.
     *
     * @return array{period_key: string|null, period_label_ar: string|null}
     */
    private static function periodMetaFromStartTime(?string $startTime): array
    {
        if ($startTime === null || $startTime === '') {
            return ['period_key' => null, 'period_label_ar' => null];
        }
        $parts = explode(':', trim($startTime));
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

    /**
     * قائمة الفروع (كل المختبرات أو حسب provider_id).
     * GET /api/branches?provider_id=1
     */
    public function branches(Request $request)
    {
        $query = Branch::with('provider:id,business_name_ar,business_name_en,city')
            ->whereHas('provider', function ($q) {
                $q->approved()->where('is_active', true);
            });

        if ($request->filled('provider_id')) {
            $query->where('provider_id', $request->provider_id);
        }

        if ($request->filled('city')) {
            $query->where('city', $request->city);
        }

        $branches = $query->orderBy('name_ar')->get()->map(function ($b) {
            return [
                'id' => $b->id,
                'provider_id' => $b->provider_id,
                'provider_name_ar' => $b->provider->business_name_ar ?? null,
                'provider_name_en' => $b->provider->business_name_en ?? null,
                'name_ar' => $b->name_ar,
                'name_en' => $b->name_en,
                'city' => $b->city,
                'district' => $b->district,
                'address' => $b->address,
                'phone' => $b->phone,
                'latitude' => $b->latitude ? (float) $b->latitude : null,
                'longitude' => $b->longitude ? (float) $b->longitude : null,
            ];
        });

        return response()->json(['success' => true, 'data' => $branches]);
    }

    /**
     * فروع مختبر معين.
     * GET /api/providers/{id}/branches
     */
    public function providerBranches($id)
    {
        $provider = Provider::active()->approved()->findOrFail($id);

        $branches = $provider->branches()->orderBy('name_ar')->get()->map(function ($b) {
            return [
                'id' => $b->id,
                'name_ar' => $b->name_ar,
                'name_en' => $b->name_en,
                'city' => $b->city,
                'district' => $b->district,
                'address' => $b->address,
                'phone' => $b->phone,
                'latitude' => $b->latitude ? (float) $b->latitude : null,
                'longitude' => $b->longitude ? (float) $b->longitude : null,
            ];
        });

        return response()->json(['success' => true, 'data' => $branches]);
    }

    /**
     * تقييمات المختبر.
     * GET /api/providers/{id}/reviews
     */
    public function reviews($id)
    {
        $provider = Provider::active()->approved()->findOrFail($id);
        $reviews = $provider->reviews()
            ->with('user:id,name')
            ->latest()
            ->paginate(15);

        return response()->json([
            'success' => true,
            'data' => $reviews,
        ]);
    }
}