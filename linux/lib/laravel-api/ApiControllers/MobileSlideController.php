<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\MobileSlide;
use Illuminate\Http\Request;

class MobileSlideController extends Controller
{
    public function index(Request $request)
    {
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

        return response()->json(['data' => $slides]);
    }
}
