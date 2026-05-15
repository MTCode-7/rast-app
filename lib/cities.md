# شرح الوصول إلى المدن في API

## نظرة عامة
يوفر التطبيق عدة طرق للوصول إلى معلومات المدينة للمختبرات والفروع من خلال API endpoints.

---

## 1. الحصول على فروع مختبر معين (مع المدينة)

### الـ Endpoint
```
GET /api/providers/{id}/branches
```

### الوصف
يرجع قائمة جميع فروع مختبر معين مع معلومات المدينة والموقع الجغرافي لكل فرع.

### المعاملات (Parameters)
- `id` (مطلوب): معرّف المختبر (Provider ID)
- `per_page` (اختياري): عدد النتائج في كل صفحة (افتراضي: 20، الحد الأقصى: 50)

### مثال على الطلب
```bash
curl "https://yourdomain.com/api/providers/1/branches"
```

### مثال على الاستجابة
```json
{
  "success": true,
  "data": {
    "data": [
      {
        "id": 1,
        "name_ar": "فرع الرياض",
        "name_en": "Riyadh Branch",
        "city": "الرياض",
        "district": "النسيم",
        "address": "شارع التحلية",
        "phone": "0112345678",
        "latitude": 24.7136,
        "longitude": 46.6753
      },
      {
        "id": 2,
        "name_ar": "فرع جدة",
        "name_en": "Jeddah Branch",
        "city": "جدة",
        "district": "الشاطئ",
        "address": "كورنيش جدة",
        "phone": "0122345678",
        "latitude": 21.5433,
        "longitude": 39.1728
      }
    ],
    "links": { ... },
    "meta": { ... }
  }
}
```

---

## 2. الحصول على جميع الفروع (مع فلترة حسب المدينة)

### الـ Endpoint
```
GET /api/branches
```

### الوصف
يرجع قائمة بجميع فروع جميع المختبرات المنشطة والموافق عليها، مع إمكانية فلترتها حسب المدينة أو معرّف المختبر.

### المعاملات (Parameters)
- `provider_id` (اختياري): معرّف المختبر للفلترة
- `city` (اختياري): اسم المدينة للفلترة (مثلاً: "الرياض")
- `per_page` (اختياري): عدد النتائج في كل صفحة

### أمثلة على الطلبات

#### جميع الفروع
```bash
curl "https://yourdomain.com/api/branches"
```

#### فروع مدينة معينة (الرياض)
```bash
curl "https://yourdomain.com/api/branches?city=الرياض"
```

#### فروع مختبر معين
```bash
curl "https://yourdomain.com/api/branches?provider_id=1"
```

#### فروع مختبر معين في مدينة معينة
```bash
curl "https://yourdomain.com/api/branches?provider_id=1&city=الرياض"
```

### مثال على الاستجابة
```json
{
  "success": true,
  "data": {
    "data": [
      {
        "id": 1,
        "provider_id": 1,
        "provider_name_ar": "مختبرات الشميمري",
        "provider_name_en": "Al Shammari Labs",
        "name_ar": "فرع الرياض",
        "name_en": "Riyadh Branch",
        "city": "الرياض",
        "district": "النسيم",
        "address": "شارع التحلية",
        "phone": "0112345678",
        "latitude": 24.7136,
        "longitude": 46.6753
      }
    ],
    "links": { ... },
    "meta": { ... }
  }
}
```

---

## 3. فلترة المختبرات حسب المدينة

### الـ Endpoint
```
GET /api/providers?city=المدينة
```

### الوصف
يرجع قائمة المختبرات (مع فروعهم) في مدينة معينة.

### المعاملات (Parameters)
- `city` (اختياري): اسم المدينة
- `home_service` (اختياري): تصفية المختبرات التي توفر خدمة المنزل (true/false)
- `service_id` (اختياري): معرّف الخدمة للفلترة
- `sort` (اختياري): طريقة الترتيب (rating، featured)
- `latitude`, `longitude`, `radius` (اختياري): البحث حسب الموقع

### مثال على الطلب
```bash
curl "https://yourdomain.com/api/providers?city=الرياض"
```

### مثال على الاستجابة
```json
{
  "success": true,
  "data": {
    "data": [
      {
        "id": 1,
        "user_id": 5,
        "business_name_ar": "مختبرات الشميمري",
        "business_name_en": "Al Shammari Labs",
        "city": "الرياض",
        "district": "النسيم",
        "phone": "0112345678",
        "is_active": true,
        "is_approved": true,
        "avg_rating": 4.5,
        "is_featured": true,
        "user": {
          "id": 5,
          "name": "محمد الشميمري",
          "email": "provider@email.com",
          "phone": "0512345678"
        }
      }
    ],
    "links": { ... },
    "meta": { ... }
  }
}
```

---

## 4. الحصول على قائمة المدن المتاحة

### الـ Endpoint
```
GET /api/providers/cities
```

### الوصف
يرجع قائمة بجميع المدن التي تحتوي على مختبرات أو فروع نشطة وموافق عليها.

### المعاملات
لا توجد معاملات لهذا الـ Endpoint

### مثال على الطلب
```bash
curl "https://yourdomain.com/api/providers/cities"
```

### مثال على الاستجابة
```json
{
  "success": true,
  "data": [
    "الأحساء",
    "الخبر",
    "الدمام",
    "الرياض",
    "جازان",
    "جدة",
    "حائل",
    "خميس مشيط",
    "مكة المكرمة",
    "المدينة المنورة",
    "نجران",
    "الطائف",
    "الظهران",
    "عرعر",
    "ينبع",
    "تبوك"
  ]
}
```

---

## 5. تفاصيل مختبر معين (يتضمن المدينة)

### الـ Endpoint
```
GET /api/providers/{id}
```

### الوصف
يرجع معلومات تفصيلية عن مختبر معين، تتضمن المدينة والعنوان والموقع الجغرافي.

### المعاملات
- `id` (مطلوب): معرّف المختبر

### مثال على الطلب
```bash
curl "https://yourdomain.com/api/providers/1"
```

### مثال على الاستجابة
```json
{
  "success": true,
  "data": {
    "id": 1,
    "user_id": 5,
    "business_name_ar": "مختبرات الشميمري",
    "business_name_en": "Al Shammari Labs",
    "city": "الرياض",
    "district": "النسيم",
    "phone": "0112345678",
    "is_active": true,
    "is_approved": true,
    "avg_rating": 4.5,
    "user": {
      "id": 5,
      "name": "محمد الشميمري",
      "email": "provider@email.com",
      "phone": "0512345678"
    }
  }
}
```

---

## استخدامات عملية

### 1. عرض جميع المدن المتاحة في تطبيق الجوال
```bash
// اتصل بهذا الـ Endpoint أولاً
GET /api/providers/cities

// ثم استخدم المدن في dropdown أو قائمة الفلترة
```

### 2. البحث عن مختبرات في مدينة معينة
```bash
GET /api/providers?city=الرياض
```

### 3. الحصول على جميع فروع مختبر
```bash
GET /api/providers/1/branches
```

### 4. البحث عن فرع في مدينة معينة
```bash
GET /api/branches?city=الرياض&provider_id=1
```

### 5. البحث عن مختبرات توفر خدمة المنزل في مدينة معينة
```bash
GET /api/providers?city=الرياض&home_service=true
```

---

## ملاحظات مهمة

1. **المدينة تكون موجودة في المستويات التالية:**
   - مستوى المختبر (Provider): المدينة الرئيسية للمختبر
   - مستوى الفرع (Branch): مدينة كل فرع على حدة

2. **يمكن للمختبر أن يكون في مدينة مختلفة عن فروعه** — لذا يجب فلترة الفروع أيضاً حسب المدينة

3. **جميع الـ Endpoints ترجع بيانات مختبرات نشطة وموافق عليها فقط** (is_active = true و is_approved = true)

4. **الفلترة حسب المدينة في `/api/providers` تفحص:**
   - مدينة المختبر الرئيسية
   - مدن الفروع التابعة للمختبر

5. **جميع الـ Endpoints تدعم pagination** — استخدم `page` و `per_page` للتنقل بين الصفحات

---

## أكواد الخطأ المحتملة

| الكود | المعنى |
|------|--------|
| 404 | المختبر غير موجود أو غير نشط |
| 422 | معاملات غير صحيحة |
| 500 | خطأ في الخادم |
