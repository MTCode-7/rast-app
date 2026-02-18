<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\MobileSlide;
use App\Models\Provider;
use App\Models\Service;
use App\Models\ServiceCategory;
use App\Models\Settings;
use Illuminate\Http\Request;

class AppConfigController extends Controller
{
    /**
     * إعدادات التطبيق: البانر، روابط المتجر، الشعار، ألوان الموقع.
     * GET /api/config
     */
    public function config()
    {
        $settings = Settings::first();

        $data = [
            'site' => [
                'name' => $settings->name ?? config('app.name'),
                'logo_url' => $settings->logo ? asset('storage/' . $settings->logo) : null,
                'color1' => $settings->color1 ?? null,
                'color2' => $settings->color2 ?? null,
                'email' => $settings->email ?? null,
                'phone' => $settings->phone ?? null,
                'address' => $settings->address ?? null,
                'facebook' => $settings->facebook ?? null,
                'twitter' => $settings->twitter ?? null,
                'instagram' => $settings->instagram ?? null,
            ],
            'banner' => [
                'active' => (bool) ($settings->banner_active ?? false),
                'message' => $settings->banner_message ?? null,
                'bg_color' => $settings->banner_bg_color ?? '#ffc107',
                'text_color' => $settings->banner_text_color ?? '#212529',
            ],
            'app_links' => [
                'android' => [
                    'active' => (bool) ($settings->android_active ?? false),
                    'link' => $settings->android_link ?? null,
                ],
                'ios' => [
                    'active' => (bool) ($settings->ios_active ?? false),
                    'link' => $settings->ios_link ?? null,
                ],
            ],
        ];

        return response()->json(['success' => true, 'data' => $data]);
    }

    /**
     * بيانات الصفحة الرئيسية: الإعدادات + السلايدر (الكاروسيل) + فئات + مختبرات مميزة.
     * GET /api/home
     */
    public function home(Request $request)
    {
        $settings = Settings::first();
        $platform = $request->query('platform', 'android');

        $slides = MobileSlide::active()->forPlatform($platform)->get()->map(function ($s) {
            return [
                'id' => $s->id,
                'title' => $s->title,
                'subtitle' => $s->subtitle,
                'image_url' => $s->image ? asset('storage/' . $s->image) : null,
                'link' => $s->link,
                'order' => $s->order,
            ];
        });

        $categories = ServiceCategory::active()->ordered()->withCount('activeServices')->get();

        $featuredProviders = Provider::approved()
            ->where('is_active', true)
            ->where('is_featured', true)
            ->with('providerServices')
            ->take(6)
            ->get()
            ->map(function ($p) {
                return [
                    'id' => $p->id,
                    'business_name_ar' => $p->business_name_ar,
                    'business_name_en' => $p->business_name_en,
                    'city' => $p->city,
                    'district' => $p->district,
                    'logo_url' => $p->logo ? asset('storage/' . $p->logo) : null,
                    'avg_rating' => (int) $p->avg_rating,
                    'total_reviews' => (int) $p->total_reviews,
                    'home_service_available' => (bool) $p->home_service_available,
                ];
            });

        $packages = Service::with(['category', 'packageItems.service'])
            ->active()
            ->where('service_type', 'package')
            ->orderBy('name_ar')
            ->take(20)
            ->get();

        $data = [
            'site' => [
                'name' => $settings->name ?? config('app.name'),
                'logo_url' => $settings->logo ? asset('storage/' . $settings->logo) : null,
                'color1' => $settings->color1 ?? null,
                'color2' => $settings->color2 ?? null,
            ],
            'banner' => [
                'active' => (bool) ($settings->banner_active ?? false),
                'message' => $settings->banner_message ?? null,
                'bg_color' => $settings->banner_bg_color ?? '#ffc107',
                'text_color' => $settings->banner_text_color ?? '#212529',
            ],
            'app_links' => [
                'android' => ['active' => (bool) ($settings->android_active ?? false), 'link' => $settings->android_link ?? null],
                'ios' => ['active' => (bool) ($settings->ios_active ?? false), 'link' => $settings->ios_link ?? null],
            ],
            'carousel_slides' => $slides->values(),
            'categories' => $categories,
            'featured_providers' => $featuredProviders->values(),
            'packages' => $packages->values(),
        ];

        return response()->json(['success' => true, 'data' => $data]);
    }
}
