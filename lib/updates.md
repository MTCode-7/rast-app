# تعديلات مطلوبة على تطبيق Flutter (RAST)

> مرجع السيرفر: `API_AUTH.md` — هذا الملف يلخّص **ما يجب تنفيذه في التطبيق فقط**.

---

## الأولوية

| الأولوية | المهمة |
|----------|--------|
| **عاجل** | نموذج `Region` + فلترة بـ `region_id` بدل مطابقة نص المدينة |
| **عاجل** | إرسال `branch_id` + `latitude` / `longitude` في `POST /api/bookings` |
| **مهم** | `branch_id` في طلب المواعيد + عرض `nearest_branch` في قائمة المختبرات |
| **تحسين** | الاعتماد على `nearest_branch` من API عند توفر الإحداثيات |

---

## 1) المناطق (Regions) — تغيير مهم (Breaking)

### قبل / بعد

| قبل | الآن |
|-----|------|
| `GET /api/providers/cities` → `data: ["الرياض","جدة"]` | `data: [{ id, name_ar, name_en, latitude, longitude, radius_km }]` |

### Endpoints

- `GET /api/providers/cities`
- `GET /api/regions` (نفس الاستجابة)

### مثال استجابة

```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "name_ar": "الرياض",
      "name_en": "Riyadh",
      "latitude": 24.7136,
      "longitude": 46.6753,
      "radius_km": 30
    }
  ]
}
```

### ما ينفّذه التطبيق

1. عند فتح الشاشة الرئيسية أو قائمة المختبرات: جلب المناطق من أحد الـ endpoints أعلاه.
2. عرض `name_ar` (أو `name_en` حسب لغة التطبيق) في التبويبات / الشريط.
3. عند اختيار منطقة:
   ```http
   GET /api/providers?region_id={id}&page=1&per_page=20
   ```
   (+ فلاتر اختيارية: `service_id`, `home_service`, `sort`)
4. **لا تعتمد** على مطابقة حقل `city` في JSON المختبر للفلترة.
5. **لا ترسل** `region_id` مع `latitude` و `longitude` في نفس الطلب (السيرفر يتجاهل GPS عند وجود `region_id`).
6. Infinite scroll: `page` / `per_page` كما في `API_AUTH.md` (قسم Pagination).

### بدائل (توافق)

- `GET /api/providers?city=الرياض` — يعمل إن وُجدت منطقة بنفس الاسم في الأدمن.
- `GET /api/providers?latitude=...&longitude=...&radius=15` — فلترة بنطاق يدوي.

---

## 2) أقرب فرع + الحجز على الفرع الصحيح

> السيرفر ينفّذ المنطق؛ التطبيق يرسل البيانات ويعرض النتيجة.

### قائمة المختبرات — العرض

- **لا تعرض** مدينة مقر المختبر فقط إن وُجد فرع أقرب.
- النص المقترح: **اسم أقرب فرع · مدينة | حي**
- مصدر البيانات (بالأولوية):
  1. حقل `nearest_branch` من `GET /api/providers` عند إرسال GPS أو `region_id`
  2. أو حساب محلي من `GET /api/branches` + موقع المستخدم / مركز المنطقة المختارة

### مثال `nearest_branch` في قائمة المختبرات

يظهر عند:
```http
GET /api/providers?latitude=24.71&longitude=46.67&page=1&per_page=20
```
أو:
```http
GET /api/providers?region_id=1&page=1&per_page=20
```

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

مع `region_id` يُحسب `nearest_branch` من **مركز المنطقة** (ليس GPS المستخدم).

### فهرس الفروع

```http
GET /api/branches?page=1&per_page=20
GET /api/providers/{id}/branches?page=1&per_page=20
```

حقول مهمة في كل فرع:

| الحقل | الاستخدام |
|-------|-----------|
| `id` | `branch_id` في الحجز والمواعيد |
| `name_ar`, `name_en` | العرض |
| `city`, `district`, `address` | العرض |
| `latitude`, `longitude` | حساب الأقرب + فلترة المنطقة |
| `is_active` | تجاهل غير النشط |
| `phone` | اتصال |

---

### المواعيد (Time slots)

```http
GET /api/providers/{id}/time-slots?date=2026-05-20&branch_id=12
```

- `branch_id`: **أقرب فرع** الذي اختاره/حسبه التطبيق (مستحسن دائماً عند تعدد الفروع).
- كل عنصر في `data` يتضمن `branch_id`.
- بدون `branch_id`: سلوك المختبر الافتراضي (مواعيد عامة + مربوطة بفرع).

---

### إنشاء الحجز `POST /api/bookings`

#### Body (حقول إضافية)

```json
{
  "provider_service_id": 123,
  "time_slot_id": 456,
  "service_type": "in_clinic",
  "branch_id": 12,
  "latitude": 24.7136,
  "longitude": 46.6753,
  "nationality": "saudi",
  "notes": ""
}
```

| الحقل | متى يُرسل |
|-------|-----------|
| `branch_id` | أقرب فرع محسوب في التطبيق — **يُفضّل دائماً** عند تعدد الفروع |
| `latitude` / `longitude` | موقع المستخدم (`in_clinic`) أو عنوان المنزل (`home_service`) |
| `home_latitude` / `home_longitude` | بديل للمنزل إن وُجد |

#### أولوية السيرفر (للمرجع فقط)

1. `branch_id` من التطبيق (لا يُستبدل بفرع الـ time slot)
2. أقرب فرع بالإحداثيات
3. `time_slot.branch_id`
4. أول فرع نشط (fallback)

#### خطأ 422

عند `service_type=in_clinic` ومختبر له **أكثر من فرع نشط** ولم يُرسل:
- لا `branch_id`
- ولا `latitude` + `longitude`

الرسالة تقريباً: *يرجى تحديد الفرع أو إرسال موقعك*.

#### الاستجابة — اعرض للمستخدم

- `branch_id`
- `branch_name`
- كائن `branch` (اسم، مدينة، حي، عنوان)

نفس الحقول في `GET /api/bookings/{id}`.

---

## 3) تعديلات سابقة (إن لم تُنفَّذ بعد)

راجع `API_AUTH.md` بالكامل. أبرز ما يخص التطبيق:

### Pagination

- `GET /api/providers`, `/services`, `/packages`, `/branches`, …
- ابدأ `page=1&per_page=20`، ألحِق النتائج حتى `current_page == last_page`.

### تفاصيل المختبر

1. `GET /api/providers/{id}` — خفيف (بدون كل التحاليل).
2. `GET /api/providers/{id}/services?page=1&per_page=20` — قائمة التحاليل + بحث `q` + ترتيب `sort`.
3. `GET /api/providers/{id}/reviews?page=1` — التقييمات منفصلة.

### الدفع (WebView)

- بعد إغلاق WebView: `GET /api/bookings/{id}/payment/status`
- لا تعتمد على فتح `/user/...` داخل WebView بدون جلسة ويب.
- الافتراضي لـ `return_url` من API: رابط `guest-return` موقّع.

### الحجز والدفع

- التأكيد تلقائي بعد نجاح الدفع.
- `service_mode` للمختبر: `home_only` / `clinic_only` / `both`.

### أخرى

- شات بوت: `POST /api/chat/message` بدون توكن.
- مواعيد 4 فترات: `period_key`, `period_label_ar`, `remaining_capacity`.
- باقات: `package_images`, `package_input_mode`.

---

## 4) اختبارات قبول (من التطبيق)

1. مستخدم في الخرج + مختبر بفرع الخرج والرياض → البطاقة تعرض **فرع الخرج**.
2. حجز `in_clinic` مع `branch_id` لفرع الخرج → تفاصيل الحجز تعرض نفس الفرع.
3. حجز بدون `branch_id` مع GPS في الخرج → السيرفر يختار فرع الخرج.
4. اختيار منطقة من التبويب → قائمة مختبرات تتغير عبر `region_id` وليس مطابقة نص.

---

## 5) نماذج Dart مقترحة (اختياري)

```dart
class AppRegion {
  final int id;
  final String nameAr;
  final String? nameEn;
  final double latitude;
  final double longitude;
  final int radiusKm;

  factory AppRegion.fromJson(Map<String, dynamic> j) => AppRegion(
    id: j['id'] as int,
    nameAr: j['name_ar'] as String,
    nameEn: j['name_en'] as String?,
    latitude: (j['latitude'] as num).toDouble(),
    longitude: (j['longitude'] as num).toDouble(),
    radiusKm: j['radius_km'] as int,
  );
}

class NearestBranch {
  final int id;
  final String nameAr;
  final String? city;
  final String? district;
  final double? distanceKm;

  factory NearestBranch.fromJson(Map<String, dynamic>? j) {
    if (j == null) throw ArgumentError();
    return NearestBranch(
      id: j['id'] as int,
      nameAr: j['name_ar'] as String,
      city: j['city'] as String?,
      district: j['district'] as String?,
      distanceKm: (j['distance_km'] as num?)?.toDouble(),
    );
  }
}
```

---

## مراجع

| الملف | المحتوى |
|-------|---------|
| `API_AUTH.md` | توثيق API كامل (Auth، دفع، pagination، regions، فروع) |
| `brances.md` | متطلبات أقرب فرع (سياق السيرفر + Flutter) |

*آخر تحديث: وفق تغييرات السيرفر — Regions + أقرب فرع + الحجز.*
