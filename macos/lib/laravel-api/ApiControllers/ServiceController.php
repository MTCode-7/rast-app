<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Offer;
use App\Models\ProviderService;
use App\Models\Service;
use App\Models\ServiceCategory;
use Illuminate\Http\Request;

class ServiceController extends Controller
{
    /**
     * إضافة image_url (رابط كامل) من حقل image إن وُجد، لظهور الصور في التطبيق.
     */
    private function appendImageUrl($model): array
    {
        $arr = $model instanceof Service ? $model->toArray() : (array) $model;
        $path = $arr['image'] ?? $arr['image_path'] ?? $arr['photo'] ?? null;
        if ($path && is_string($path)) {
            $arr['image_url'] = str_starts_with($path, 'http') ? $path : asset('storage/' . ltrim($path, '/'));
        }
        return $arr;
    }

    /**
     * تحويل عناصر الصفحة: image_url + السعر من provider_service إن لم يكن على الخدمة.
     */
    private function transformServicesList($paginator)
    {
        $collection = $paginator->getCollection();
        $collection->transform(function ($item) {
            $arr = $this->appendImageUrl($item);
            $price = $arr['price'] ?? $arr['final_price'] ?? null;
            if (($price === null || $price == 0) && $item->relationLoaded('providerServices') && $item->providerServices->isNotEmpty()) {
                $first = $item->providerServices->first();
                $arr['price'] = $first->final_price ?? $first->price ?? 0;
                $arr['final_price'] = $arr['price'];
            }
            return $arr;
        });
        return $paginator;
    }

    /**
     * تحويل الباقات: image_url + استخراج السعر والصور من أول provider_service إن لم تكن على الباقة.
     */
    private function transformPackagesList($paginator)
    {
        $collection = $paginator->getCollection();
        $collection->transform(function ($item) {
            $arr = $this->appendImageUrl($item);
            $hasImage = !empty($arr['image'] ?? $arr['image_url'] ?? $arr['image_path'] ?? null);
            if (!$hasImage && $item->relationLoaded('providerServices') && $item->providerServices->isNotEmpty()) {
                $first = $item->providerServices->first();
                $firstArr = $first instanceof \Illuminate\Database\Eloquent\Model ? $first->toArray() : (array) $first;
                $path = $firstArr['image'] ?? $firstArr['image_path'] ?? $firstArr['photo'] ?? null;
                if ($path && is_string($path)) {
                    $arr['image'] = $path;
                    $arr['image_url'] = str_starts_with($path, 'http') ? $path : asset('storage/' . ltrim($path, '/'));
                }
            }
            $price = $arr['price'] ?? $arr['final_price'] ?? null;
            if (($price === null || $price == 0) && $item->relationLoaded('providerServices') && $item->providerServices->isNotEmpty()) {
                $first = $item->providerServices->first();
                $arr['price'] = $first->final_price ?? $first->price ?? 0;
            }
            return $arr;
        });
        return $paginator;
    }
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

        $services = $query->with(['providerServices' => fn ($q) => $q->where('is_available', true)->limit(1)])
            ->paginate($request->get('per_page', 15));
        $this->transformServicesList($services);

        return response()->json([
            'success' => true,
            'data' => $services,
        ]);
    }

    public function show($id)
    {
        // إذا لم تظهر تحاليل الباقة، تأكد أن موديل Service يملك العلاقة packageItems() أو package_items()
        // واستخدم نفس الاسم هنا (مثلاً 'package_items.service' إن كان اسم الدالة package_items)
        $service = Service::with([
            'category',
            'providerServices' => function ($query) {
                $query->where('is_available', true)->with('provider');
            },
            'packageItems.service',
        ])
            ->active()
            ->findOrFail($id);

        $data = $this->appendImageUrl($service);
        if (isset($data['provider_services']) && is_array($data['provider_services'])) {
            $data['provider_services'] = array_map(fn ($ps) => $this->appendImageUrl($ps), $data['provider_services']);
        }

        return response()->json([
            'success' => true,
            'data' => $data,
        ]);
    }

    public function byCategory($categorySlug)
    {
        $category = ServiceCategory::where('slug', $categorySlug)
            ->active()
            ->firstOrFail();

        $services = Service::with(['category', 'providerServices' => fn ($q) => $q->where('is_available', true)->limit(1)])
            ->active()
            ->where('service_category_id', $category->id)
            ->paginate(15);
        $this->transformServicesList($services);

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
        $query = Service::with(['category', 'packageItems.service', 'providerServices'])
            ->active()
            ->where('service_type', 'package');

        if ($request->has('category_id')) {
            $query->where('service_category_id', $request->category_id);
        }

        $packages = $query->orderBy('name_ar')->paginate($request->get('per_page', 15));
        $this->transformPackagesList($packages);

        return response()->json(['success' => true, 'data' => $packages]);
    }
}