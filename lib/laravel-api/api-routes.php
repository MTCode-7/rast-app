<?php

use App\Http\Controllers\Api\AppConfigController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\BookingController;
use App\Http\Controllers\Api\PaymentController as ApiPaymentController;
use App\Http\Controllers\Api\ProviderController;
use App\Http\Controllers\Api\ServiceController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| API Routes (لربط تطبيق أندرويد / أي عميل)
|--------------------------------------------------------------------------
*/

// إعدادات التطبيق والبانر والكاروسيل والنافذة المنبثقة
Route::get('/config', [AppConfigController::class, 'config']);
Route::get('/home', [AppConfigController::class, 'home']);
Route::get('/popup', [AppConfigController::class, 'popup']);

// Public routes
Route::prefix('auth')->group(function () {
    Route::post('/register', [AuthController::class, 'register']);
    Route::post('/login', [AuthController::class, 'login']);
});

// Service & Provider public routes
Route::prefix('services')->group(function () {
    Route::get('/categories', [ServiceController::class, 'categories']);
    Route::get('/', [ServiceController::class, 'index']);
    Route::get('/category/{slug}', [ServiceController::class, 'byCategory']);
    Route::get('/{id}', [ServiceController::class, 'show']);
});

Route::prefix('providers')->group(function () {
    Route::get('/', [ProviderController::class, 'index']);
    Route::get('/{id}/services', [ProviderController::class, 'services']);
    Route::get('/{id}/time-slots', [ProviderController::class, 'timeSlots']);
    Route::get('/{id}/reviews', [ProviderController::class, 'reviews']);
    Route::get('/{id}/branches', [ProviderController::class, 'providerBranches']);
    Route::get('/{id}', [ProviderController::class, 'show']);
});

Route::get('/offers', [ServiceController::class, 'offers']);
Route::get('/packages', [ServiceController::class, 'packages']);

// Mobile slides for apps
Route::get('/mobile/slides', [\App\Http\Controllers\Api\MobileSlideController::class, 'index']);
Route::get('/branches', [ProviderController::class, 'branches']);

// Chatbot API (for mobile app) – requires auth
Route::prefix('chat')->middleware('auth:sanctum')->group(function () {
    Route::post('/message', [\App\Http\Controllers\Api\ChatController::class, 'message']);
});

// Protected routes
Route::middleware('auth:sanctum')->group(function () {
    // Auth routes
    Route::prefix('auth')->group(function () {
        Route::post('/logout', [AuthController::class, 'logout']);
        Route::get('/me', [AuthController::class, 'me']);
        Route::put('/profile', [AuthController::class, 'updateProfile']);
        Route::put('/password', [AuthController::class, 'changePassword']);
        Route::post('/delete-account', [AuthController::class, 'deleteAccount']);
    });

    // Booking routes
    Route::prefix('bookings')->group(function () {
        Route::get('/', [BookingController::class, 'index']);
        Route::get('/upcoming', [BookingController::class, 'upcoming']);
        Route::get('/past', [BookingController::class, 'past']);
        Route::post('/', [BookingController::class, 'store']);
        Route::post('/{id}/payment/session', [ApiPaymentController::class, 'createSession']);
        Route::get('/{id}/payment/status', [ApiPaymentController::class, 'status']);
        Route::get('/{id}', [BookingController::class, 'show']);
        Route::post('/{id}/cancel', [BookingController::class, 'cancel']);
    });

    // Review routes
    Route::prefix('reviews')->group(function () {
        Route::post('/', [BookingController::class, 'storeReview']);
    });
});