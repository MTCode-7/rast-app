# متطلبات السيرفر (Laravel API) — أقرب فرع + الحجز الصحيح

> **للمطور/AI السيرفر فقط.** التطبيق (Flutter) ينفّذ الجزء الموضّح في قسم «ما يفعله التطبيق». الباقي يجب إضافته في الـ API والموقع.

---

## المشكلة الحالية

1. قائمة المختبرات تعرض **مدينة المقر** وليس **أقرب فرع** للمستخدم.
2. عند `POST /api/bookings` قد يُسجَّل الحجز على **فرع خاطئ** لأن:
   - `branch_id` يُستمد أحياناً من `time_slot.branch_id` فقط.
   - منطق «أقرب فرع» يعتمد على `home_latitude` / `home_longitude` **فقط** (خدمة منزلية)، وليس موقع المستخدم في زيارة **في المختبر**.
3. المواعيد `GET /api/providers/{id}/time-slots` قد لا تكون مربوطة بالفرع الذي سيحضر إليه العميل.

---

## ما يفعله تطبيق Flutter (جاهز / قيد الربط)

| السلوك | التفاصيل |
|--------|----------|
| بطاقة المختبر | يعرض **اسم أقرب فرع · مدينة \| حي** حسب GPS أو الموقع المحفوظ، أو مركز **المنطقة المختارة** إن لم يتوفر GPS. |
| فهرس الفروع | `GET /api/branches` (صفحات) + كاش محلي. |
| إنشاء الحجز | يرسل مع الطلب (عند توفر البيانات): |

```json
{
  "provider_service_id": 123,
  "time_slot_id": 456,
  "service_type": "in_clinic",
  "branch_id": 12,
  "latitude": 24.7136,
  "longitude": 46.6753
}
```

- `branch_id`: أقرب فرع محسوب في التطبيق (إلزامي تنفيذه على السيرفر إن وُجد).
- `latitude` / `longitude`: موقع المستخدم (أو عنوان المنزل عند `home_service`) لاختيار الفرع إن لم يُرسل `branch_id`.

---

## 1) تعديل `POST /api/bookings`

### حقول جديدة / موسّعة في الـ body

| الحقل | النوع | مطلوب | الوصف |
|-------|------|--------|--------|
| `branch_id` | int | اختياري* | الفرع المختار صراحةً. يجب أن يكون `provider_id` للفرع = مختبر الحجز. |
| `latitude` | float | اختياري | خط عرض مرجعي (مستخدم / منزل). |
| `longitude` | float | اختياري | خط طول مرجعي. |

\* **مستحسن جعله مطلوباً** عند `service_type=in_clinic` إذا كان للمختبر أكثر من فرع نشط.

### منطق اختيار `branch_id` على السيرفر (بالترتيب)

1. إذا أُرسل `branch_id` وكان تابعاً للمختبر ونشطاً → **استخدمه** (لا تستبدله بفرع الـ time slot إن كان مختلفاً إلا إذا slot مربوط بنفس الفرع).
2. وإلا إذا وُجدت `latitude` + `longitude` → اختر **أقرب فرع نشط** له إحداثيات ضمن `provider.branches`.
3. وإلا إذا كان `time_slot.branch_id` نشطاً → استخدمه.
4. وإلا أول فرع نشط (fallback) — مع تسجيل تحذير في الـ log.

### التحقق (validation)

```php
'branch_id' => [
    'nullable',
    'integer',
    Rule::exists('branches', 'id')->where(function ($q) use ($providerId) {
        $q->where('provider_id', $providerId)->where('is_active', true);
    }),
],
'latitude' => 'nullable|numeric|between:-90,90',
'longitude' => 'nullable|numeric|between:-180,180',
```

### استجابة الحجز

تأكد أن `branch_id` و `branch_name` (أو `branch.name_ar`) يظهران في:

- `POST /api/bookings` → `data`
- `GET /api/bookings/{id}`

---

## 2) `GET /api/providers` — أقرب فرع في القائمة (اختياري لكن ممتاز)

عند إرسال `latitude` + `longitude` (أو مع `region_id` بعد حساب مركز المنطقة):

أضف في كل عنصر مختبر:

```json
{
  "id": 5,
  "business_name_ar": "...",
  "nearest_branch": {
    "id": 12,
    "name_ar": "فرع الخرج",
    "name_en": "Al Kharj Branch",
    "city": "الخرج",
    "district": "حي العزيزية",
    "latitude": 24.155,
    "longitude": 47.334,
    "distance_km": 8.2
  }
}
```

يقلّل طلبات الفروع المنفصلة من التطبيق.

---

## 3) `GET /api/providers/{id}/time-slots`

### Query اختياري

```
GET /api/providers/{id}/time-slots?date=2026-05-20&branch_id=12
```

- عند `branch_id`: أرجع مواعيد **هذا الفرع** فقط (أو capacity مخصصة للفرع).
- بدون `branch_id`: السلوك الحالي أو مواعيد المختبر الافتراضي.

### في كل time-slot

```json
{
  "id": 456,
  "branch_id": 12,
  "period_key": "morning",
  ...
}
```

حتى يتطابق الفرع مع ما اختاره التطبيق.

---

## 4) `GET /api/branches` و `GET /api/providers/{id}/branches`

تأكد من وجود الحقول (التطبيق يعتمد عليها):

| الحقل | ملاحظة |
|-------|--------|
| `id` | معرّف الفرع |
| `provider_id` | |
| `name_ar`, `name_en` | اسم الفرع للعرض |
| `city`, `district`, `address` | |
| `latitude`, `longitude` | **إلزامي** لظهور المختبر في فلترة المنطقة ولحساب الأقرب |
| `is_active` | |

---

## 5) فلترة المناطق `region_id` (موجود)

- الفلترة الجغرافية تعتمد على إحداثيات الفروع — راجع `lib/api.md` قسم Regions.
- لا تعتمد على نص `city` فقط في الفلترة الجديدة.

---

## 6) لوحة المختبر / الموقع

- كل فرع: اسم عربي/إنجليزي + مدينة + حي + **إحداثيات على الخريطة**.
- بدون إحداثيات لن يظهر في فلترة المنطقة ولن يُختار كأقرب فرع بدقة.

---

## 7) اختبارات قبول (Acceptance)

1. مستخدم في الخرج يفتح قائمة مختبرات له فرع في الخرج وفرع في الرياض → البطاقة تعرض **فرع الخرج** (اسم أو موقع).
2. حجز `in_clinic` مع `branch_id` لفرع الخرج → `booking.branch_id` = فرع الخرج في DB والإشعارات.
3. حجز بدون `branch_id` مع `latitude`/`longitude` في الخرج → السيرفر يختار فرع الخرج وليس الرياض.
4. `time_slot` مربوط بفرع آخر + `branch_id` صريح → يفوز `branch_id` من التطبيق (أو 422 برسالة واضحة).

---

## ملخص أولويات التنفيذ على السيرفر

1. **عاجل:** قبول `branch_id` + `latitude`/`longitude` في `POST /api/bookings` ومنطق الأولوية أعلاه.
2. **مهم:** `branch_id` في time-slots + فلترة المواعيد حسب الفرع.
3. **تحسين:** `nearest_branch` في `GET /api/providers` عند إرسال الإحداثيات.

---

*آخر تحديث: وفق تطبيق RAST Flutter — أقرب فرع + region_id.*
