<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Password;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    /** صيغ مقبولة لمطابقة حقل phone في قاعدة البيانات */
    private function phoneVariants(string $phone): array
    {
        $digits = preg_replace('/\D/', '', $phone) ?? '';
        $variants = array_filter([
            trim($phone),
            $digits,
        ]);
        if (str_starts_with($digits, '966') && strlen($digits) > 3) {
            $variants[] = '0' . substr($digits, 3);
            $variants[] = '+' . $digits;
        }
        if (str_starts_with($digits, '0') && strlen($digits) > 1) {
            $variants[] = substr($digits, 1);
            $variants[] = '966' . substr($digits, 1);
            $variants[] = '+966' . substr($digits, 1);
        }
        return array_values(array_unique(array_filter($variants)));
    }

    /** مفتاح موحّد للـ OTP في الكاش */
    private function phoneCacheKey(string $phone): string
    {
        $digits = preg_replace('/\D/', '', $phone) ?? '';
        if (str_starts_with($digits, '966')) {
            return '966' . substr($digits, 3);
        }
        if (str_starts_with($digits, '0')) {
            return '966' . substr($digits, 1);
        }

        return $digits;
    }

    public function register(Request $request)
    {
        $validated = $request->validate([
            'name' => 'required|string|max:255',
            'email' => 'required|email|unique:users,email',
            'phone' => 'nullable|string|unique:users,phone',
            'password' => 'required|string|min:8|confirmed',
        ]);

        $user = User::create([
            'name' => $validated['name'],
            'email' => $validated['email'],
            'phone' => $validated['phone'] ?? null,
            'password' => Hash::make($validated['password']),
            'role' => 'user',
        ]);

        $token = $user->createToken('auth-token')->plainTextToken;

        return response()->json([
            'success' => true,
            'message' => 'User registered successfully',
            'data' => [
                'user' => $user,
                'token' => $token,
            ]
        ], 201);
    }

    public function login(Request $request)
    {
        $validated = $request->validate([
            'email' => 'required_without:phone|nullable|email',
            'phone' => 'required_without:email|nullable|string',
            'password' => 'required|string',
        ]);

        $user = null;
        if (!empty($validated['email'])) {
            $user = User::where('email', $validated['email'])->first();
        } elseif (!empty($validated['phone'])) {
            $user = User::whereIn('phone', $this->phoneVariants($validated['phone']))->first();
        }

        if (!$user || !Hash::check($validated['password'], $user->password)) {
            throw ValidationException::withMessages([
                'email' => ['The provided credentials are incorrect.'],
            ]);
        }

        if (!$user->is_active) {
            return response()->json([
                'success' => false,
                'message' => 'Your account has been deactivated',
            ], 403);
        }

        $token = $user->createToken('auth-token')->plainTextToken;

        return response()->json([
            'success' => true,
            'message' => 'Login successful',
            'data' => [
                'user' => $user,
                'token' => $token,
            ]
        ]);
    }

    /**
     * POST /api/auth/forgot-password
     * Body: { email } أو { channel: whatsapp, phone }
     */
    public function forgotPassword(Request $request): JsonResponse
    {
        if ($request->input('channel') === 'whatsapp') {
            $validated = $request->validate([
                'phone' => 'required|string',
            ]);

            $user = User::whereIn('phone', $this->phoneVariants($validated['phone']))->first();
            if (!$user) {
                return response()->json([
                    'success' => true,
                    'message' => 'If this phone is registered, an OTP has been sent.',
                ]);
            }

            $otp = (string) random_int(100000, 999999);
            $key = $this->phoneCacheKey($validated['phone']);
            Cache::put(
                'whatsapp_pwd_reset:' . $key,
                ['otp_hash' => Hash::make($otp), 'user_id' => $user->id],
                now()->addMinutes(15)
            );

            // يمكن ربط Green-API هنا عند توفر GREENAPI_INSTANCE_ID و GREENAPI_API_TOKEN
            if (config('services.greenapi.instance_id') && config('services.greenapi.token')) {
                // إرسال عبر واتساب — يترك للمشروع الفعلي ربط Http client بـ Green API
            }

            return response()->json([
                'success' => true,
                'message' => 'OTP sent via WhatsApp if the service is enabled.',
            ]);
        }

        $validated = $request->validate([
            'email' => 'required|email',
        ]);

        Password::sendResetLink(['email' => $validated['email']]);

        return response()->json([
            'success' => true,
            'message' => 'If that email exists, a reset link has been sent.',
        ]);
    }

    /**
     * POST /api/auth/reset-password (رابط البريد)
     */
    public function resetPassword(Request $request): JsonResponse
    {
        $request->validate([
            'token' => 'required|string',
            'email' => 'required|email',
            'password' => 'required|string|min:8|confirmed',
        ]);

        $status = Password::reset(
            $request->only('email', 'password', 'password_confirmation', 'token'),
            function (User $user, string $password) {
                $user->forceFill([
                    'password' => Hash::make($password),
                ])->save();
            }
        );

        if ($status !== Password::PASSWORD_RESET) {
            throw ValidationException::withMessages([
                'email' => [__($status)],
            ]);
        }

        return response()->json([
            'success' => true,
            'message' => 'Password has been reset.',
        ]);
    }

    /**
     * POST /api/auth/reset-password-otp (واتساب)
     */
    public function resetPasswordOtp(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'phone' => 'required|string',
            'otp' => 'required|string|size:6',
            'password' => 'required|string|min:8|confirmed',
        ]);

        $key = $this->phoneCacheKey($validated['phone']);
        $cached = Cache::get('whatsapp_pwd_reset:' . $key);

        if (!$cached || empty($cached['otp_hash']) || empty($cached['user_id'])) {
            throw ValidationException::withMessages([
                'otp' => ['Invalid or expired OTP.'],
            ]);
        }

        if (!Hash::check($validated['otp'], $cached['otp_hash'])) {
            throw ValidationException::withMessages([
                'otp' => ['Invalid or expired OTP.'],
            ]);
        }

        $user = User::findOrFail($cached['user_id']);
        $user->password = Hash::make($validated['password']);
        $user->save();

        Cache::forget('whatsapp_pwd_reset:' . $key);

        return response()->json([
            'success' => true,
            'message' => 'Password has been reset.',
        ]);
    }

    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json([
            'success' => true,
            'message' => 'Logged out successfully',
        ]);
    }

    public function me(Request $request)
    {
        return response()->json([
            'success' => true,
            'data' => $request->user()->load('provider'),
        ]);
    }

    public function updateProfile(Request $request)
    {
        $validated = $request->validate([
            'name' => 'sometimes|string|max:255',
            'phone' => 'sometimes|nullable|string|unique:users,phone,' . $request->user()->id,
        ]);

        $request->user()->update($validated);

        return response()->json([
            'success' => true,
            'message' => 'Profile updated successfully',
            'data' => $request->user(),
        ]);
    }

    public function changePassword(Request $request)
    {
        $validated = $request->validate([
            'current_password' => 'required|string',
            'new_password' => 'required|string|min:8|confirmed',
        ]);

        if (!Hash::check($validated['current_password'], $request->user()->password)) {
            throw ValidationException::withMessages([
                'current_password' => ['Current password is incorrect.'],
            ]);
        }

        $request->user()->update([
            'password' => Hash::make($validated['new_password']),
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Password changed successfully',
        ]);
    }
}