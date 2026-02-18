<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Offer;
use App\Models\Service;
use App\Models\ServiceCategory;
use Illuminate\Http\Request;

class ServiceController extends Controller
{
    public function categories()
    {
        $categories = ServiceCategory::active()
            ->ordered()
            ->withCount('activeServices')
            ->get();

        return response()->json([
            'success' => true,
            'data' => $categories,
        ]);
    }

    public function index(Request $request)
    {
        $query = Service::with('category')
            ->active();

        if ($request->has('category_id')) {
            $query->byCategory($request->category_id);
        }

        if ($request->has('search')) {
            $query->search($request->search);
        }

        $services = $query->paginate($request->get('per_page', 15));

        return response()->json([
            'success' => true,
            'data' => $services,
        ]);
    }

    public function show($id)
    {
        $service = Service::with(['category', 'providerServices' => function ($query) {
            $query->where('is_available', true)
                  ->with('provider');
        }])
        ->active()
        ->findOrFail($id);

        return response()->json([
            'success' => true,
            'data' => $service,
        ]);
    }

    public function byCategory($categorySlug)
    {
        $category = ServiceCategory::where('slug', $categorySlug)
            ->active()
            ->firstOrFail();

        $services = Service::with('category')
            ->active()
            ->where('service_category_id', $category->id)
            ->paginate(15);

        return response()->json([
            'success' => true,
            'data' => [
                'category' => $category,
                'services' => $services,
            ],
        ]);
    }

    /**
     * العروض النشطة (للمختبرات).
     * GET /api/offers
     */
    public function offers(Request $request)
    {
        $query = Offer::active()->with('provider');

        if ($request->has('provider_id')) {
            $query->where('provider_id', $request->provider_id);
        }

        $offers = $query->orderByDesc('start_date')->paginate($request->get('per_page', 15));

        return response()->json(['success' => true, 'data' => $offers]);
    }

    /**
     * الباقات (خدمات من نوع package).
     * GET /api/packages
     */
    public function packages(Request $request)
    {
        $query = Service::with(['category', 'packageItems.service'])
            ->active()
            ->where('service_type', 'package');

        if ($request->has('category_id')) {
            $query->where('service_category_id', $request->category_id);
        }

        $packages = $query->orderBy('name_ar')->paginate($request->get('per_page', 15));

        return response()->json(['success' => true, 'data' => $packages]);
    }
}