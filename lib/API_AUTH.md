# API Auth Guide

## Base
- كل المسارات أدناه تبدأ بـ: `/api/auth`
- الاستجابات تكون JSON

## Login (email or phone)
- **Endpoint:** `POST /api/auth/login`
- **Body (email):**
```json
{
  "email": "user@example.com",
  "password": "secret123"
}
```
- **Body (phone):**
```json
{
  "phone": "05xxxxxxxx",
  "password": "secret123"
}
```
- يقبل أيضًا صيغة: `+9665xxxxxxxx`
- النجاح يرجع `token` داخل `data.token`

## Register
- **Endpoint:** `POST /api/auth/register`
- **Body:**
```json
{
  "name": "User Name",
  "email": "user@example.com",
  "phone": "05xxxxxxxx",
  "password": "secret12345",
  "password_confirmation": "secret12345"
}
```

## Forgot Password (Email)
- **Endpoint:** `POST /api/auth/forgot-password`
- **Body:**
```json
{
  "email": "user@example.com"
}
```
- يرسل رابط إعادة تعيين إلى البريد.

## Forgot Password (WhatsApp OTP)
- **Endpoint:** `POST /api/auth/forgot-password`
- **Body:**
```json
{
  "channel": "whatsapp",
  "phone": "05xxxxxxxx"
}
```
- يرسل OTP على واتساب إذا كانت خدمة Green-API مفعلة.

## Reset Password (Email Token)
- **Endpoint:** `POST /api/auth/reset-password`
- **Body:**
```json
{
  "token": "reset-token",
  "email": "user@example.com",
  "password": "NewPass123!",
  "password_confirmation": "NewPass123!"
}
```

## Reset Password (WhatsApp OTP)
- **Endpoint:** `POST /api/auth/reset-password-otp`
- **Body:**
```json
{
  "phone": "05xxxxxxxx",
  "otp": "123456",
  "password": "NewPass123!",
  "password_confirmation": "NewPass123!"
}
```

## Protected Auth Endpoints (need Bearer token)
- `POST /api/auth/logout`
- `GET /api/auth/me`
- `PUT /api/auth/profile`
- `PUT /api/auth/password`

## Notes
- عند الخطأ في التحقق، الـ API يرجع `422`.
- لتفعيل واتساب يجب ضبط:
  - `GREENAPI_INSTANCE_ID`
  - `GREENAPI_API_TOKEN`
  - (اختياري) `GREENAPI_API_URL`

## API Change: Booking Time Periods (4 periods)
- تم تحديث نظام المواعيد ليكون على 4 فترات ثابتة (كل فترة 6 ساعات):
  - `00:00 - 06:00` (الفترة الأولى)
  - `06:00 - 12:00` (الفترة الثانية)
  - `12:00 - 18:00` (الفترة الثالثة)
  - `18:00 - 00:00` (الفترة الرابعة)
- Endpoint جلب مواعيد المزود:
  - `GET /api/providers/{id}/time-slots?date=YYYY-MM-DD`
- الفترات لا تحتاج توليد مسبق (cron/job). عند طلب اليوم، الـ API يضمن وجودها تلقائياً.
- الحقول الجديدة في كل عنصر `time-slot`:
  - `period_key`: one of `night`, `morning`, `afternoon`, `evening`
  - `period_label_ar`: وصف الفترة بالعربية
  - `remaining_capacity`: المقاعد المتبقية في الفترة
- في تفاصيل الحجز وطلبات الحجوزات (`/api/bookings`, `/api/bookings/{id}`) تمت إضافة:
  - `booking_period_key`
  - `booking_period_label_ar`

## API Change: Chatbot Without Login
- Endpoint الدردشة:
  - `POST /api/chat/message`
- أصبح endpoint **عام** ولا يتطلب `Bearer token`.
- ما زال يقبل نفس الـ body:
```json
{
  "message": "ابي افضل المختبرات في جدة",
  "history": [
    { "role": "user", "text": "مرحبا" },
    { "role": "model", "text": "ياهلا" }
  ]
}
```

## API Change: Booking Confirmation + Service Mode
- تأكيد الحجز لم يعد يدوياً من الفرع/المختبر في التدفق التشغيلي؛ يتم تلقائياً بعد نجاح الدفع.
- تمت إضافة إعداد للمختبر `service_mode` (على مستوى إعدادات المختبر):
  - `home_only` (في المنزل فقط)
  - `clinic_only` (في المختبر فقط)
  - `both` (كلاهما)
- تأثيره على `POST /api/bookings`:
  - إذا كان المختبر `home_only` يتم فرض `service_type=home_service` تلقائياً.
  - إذا كان المختبر `clinic_only` يتم فرض `service_type=in_clinic` تلقائياً.
  - إذا كان `both` يُستخدم `service_type` القادم من التطبيق (وإن لم يُرسل يتم التعامل معه كـ `in_clinic` افتراضياً).

## مشكلة شائعة: WebView الدفع يفتح تسجيل الدخول + خصم بدون تأكيد حجز

### ما الذي كان يحدث؟
- التطبيق يفتح رابط الدفع (EdfaPay) داخل WebView.
- بعد نجاح الدفع، البوابة تعيد التوجيه إلى **`return_url`**.
- إذا كان هذا الرابط من مسارات الموقع المحمية بـ **جلسة تسجيل الدخول للويب** (`/user/...` مع `middleware auth`)، فالـ WebView **لا يملك كوكيز جلسة المستخدم** → يُعاد توجيه المستخدم إلى **صفحة تسجيل الدخول**.
- في هذه الحالة قد يُخصم المبلغ في البوابة بينما **لا يُستدعى** مسار إكمال الحجز على السيرفر من رابط العودة، فلا تأكيد للحجز ولا إشعارات بريد/واتساب (ما لم يكتمل التأكيد عبر **Webhook** أو **مزامنة لاحقة**).

### أين كانت المشكلة؟
- **ليس خطأً في منطق التأكيد نفسه** بقدر ما هو **عدم توافق بين تدفق التطبيق (WebView بدون جلسة ويب) وروابط العودة الافتراضية** التي كانت تشير لصفحات تتطلب `auth` ويب.
- **السيرفر (API):** كان الافتراضي في `POST /api/bookings/{id}/payment/session` يضع `return_url` إلى صفحة تفاصيل حجز الويب (`user.booking-details`) وهي محمية بالجلسة.
- **التطبيق:** إن مرّر `return_url` يدوياً إلى رابط محمي بالجلسة، سيحدث نفس السلوك.

### ما الذي تم إصلاحه في الـ API؟
- أصبح الافتراضي لـ `return_url` عند إنشاء جلسة الدفع من الـ API هو رابط عام **بدون جلسة ويب**:
  - `GET|POST /payment/bookings/{booking}/guest-return`
  - مع معاملات أمان في الاستعلام: `guest_pt_expires` و `guest_pt_token` (موقّعة بـ `APP_KEY`، صلاحية ~72 ساعة).
- هذا المسار يعيد صفحة بسيطة ثم يُجرَى على السيرفر **نفس مزامنة EdfaPay** المستخدمة في عودة الدفع للويب، لتأكيد الحجز وإطلاق الإشعارات عند نجاح الدفع.
- ما زال بإمكان التطبيق تمرير **`return_url` خاص** (مثلاً deep link) في body الطلب؛ عندها يتحمّل التطبيق ضمان المتابعة (مثلاً استدعاء `GET /api/bookings/{id}/payment/status` بعد إغلاق الـ WebView).

### ما الذي يجب أن يفعله التطبيق بعد الدفع؟
1. بعد إغلاق WebView أو عند العودة للتطبيق: استدعاء **`GET /api/bookings/{id}/payment/status`** مع `Bearer token` (احتياطي إذا تأخر تأكيد البوابة أو فشل الـ Webhook).
2. عدم الاعتماد على فتح صفحة `/user/...` داخل WebView كصفحة عودة ما لم تُدار جلسة ويب للمستخدم صراحة.

### ملاحظة عن Webhook
- التأكيد التلقائي قد يكتمل أيضاً عبر **`POST /payment/webhook`** إذا كان مُعدّاً وصحيح التوقيع في EdfaPay.
- إذا استمر عدم التأكيد رغم الخصم، راجع سجلات السيرفر لـ webhook والتوقيع، بالإضافة إلى استدعاء `payment/status` من التطبيق.

## API Change: Packages (existing tests or images)
- في لوحة المختبر أصبح إنشاء الباقة يدعم وضعين:
  - `existing_tests`: اختيار الباقة من التحاليل الموجودة.
  - `images`: إضافة سريعة كصور فقط مع اسم الباقة.
- عند استخدام وضع الصور، تُحفظ الصور ضمن بيانات الباقة وتظهر في API الباقات.
- Endpoint المتأثر:
  - `GET /api/packages`
- حقول إضافية قد تظهر في كل باقة:
  - `package_input_mode`: `existing_tests` أو `images`
  - `package_images`: مصفوفة روابط صور كاملة (URLs) عند استخدام وضع الصور.

## API Change: Infinite Scroll Pagination
- تم اعتماد pagination للقوائم الكبيرة حتى لا يتم تحميل كل العناصر دفعة واحدة (لتفادي تعليق التطبيق).
- جميع endpoints التالية تدعم الآن `page` و `per_page` (حد أقصى `50`):
  - `GET /api/providers`
  - `GET /api/providers/{id}/services`
  - `GET /api/providers/{id}/branches`
  - `GET /api/providers/{id}/reviews`
  - `GET /api/branches`
  - `GET /api/services`
  - `GET /api/services/category/{slug}`
  - `GET /api/packages`
  - `GET /api/offers`
- الشكل المتوقع للاستهلاك في التطبيق:
  - ابدأ بـ `page=1&per_page=20`
  - اعرض `data.data` (العناصر)
  - عند النزول لأسفل:
    - إذا `data.current_page < data.last_page` اطلب الصفحة التالية
    - أضف النتائج الجديدة لنفس القائمة (append)
  - توقف عندما تصل `current_page == last_page`
- ملاحظة مهمة للتطبيق:
  - بعض endpoints التي كانت تعيد Array مباشرة أصبحت تعيد Paginator object داخل `data`.
  - مثال: `GET /api/providers/{id}/services` و `GET /api/branches` و `GET /api/providers/{id}/branches`.

## API Change: مناطق التطبيق (Regions) — فلترة بالإحداثيات

### الفكرة
- المناطق (جدة، الرياض، الطائف، …) **لا تُستخرج** من أسماء المختبرات بعد الآن.
- الأدمن يضيف كل منطقة من لوحة التحكم: **اسم + مركز على الخريطة + نصف قطر (كم)**.
- التطبيق يعرض **نفس القائمة** من الـ API.
- عند اختيار منطقة: يظهر المختبر إذا كان **موقع المختبر** أو **أي فرع نشط له إحداثيات** داخل نصف قطر المنطقة.

### جلب قائمة المناطق (لتبويب/شريط المدن)
- `GET /api/providers/cities`
- `GET /api/regions` (نفس الاستجابة — alias)

**مثال استجابة:**
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

> **تغيير breaking:** لم يعد `data` مصفوفة نصوص (`["الرياض","جدة"]`). أصبحت كائنات فيها `id` وإحداثيات. حدّث التطبيق accordingly.

### فلترة المختبرات حسب المنطقة (الطريقة المفضلة للتطبيق)
- `GET /api/providers?region_id={id}`

مثال:
```http
GET /api/providers?region_id=1&page=1&per_page=20
```

السيرفر يستخدم `latitude` / `longitude` / `radius_km` للمنطقة المختارة ويبحث في موقع المختبر **وفروعه**.

### بدائل متوافقة مع الإصدارات السابقة
- `GET /api/providers?city=الرياض` — إن وُجدت منطقة بنفس `name_ar` أو `name_en` تُطبَّق فلترة الإحداثيات؛ وإلا تُستخدم مطابقة النص القديمة على `city` للمختبر/الفروع.
- `GET /api/providers?latitude=24.7136&longitude=46.6753` — ترتيب حسب الأقرب (موقع المختبر فقط في الترتيب).
- `GET /api/providers?latitude=...&longitude=...&radius=15` — يقيّد النتائج لمختبر/فرع ضمن 15 كم (نفس منطق `region_id`).

**لا تُرسل `region_id` مع `latitude`/`longitude` معًا** — عند وجود `region_id` يُتجاهل موقع GPS في نفس الطلب.

### ما يجب تنفيذه في التطبيق (Android)
1. عند فتح الشاشة الرئيسية/قائمة المختبرات: `GET /api/providers/cities` (أو `/api/regions`).
2. اعرض `name_ar` (أو `name_en` حسب لغة التطبيق) في التبويبات.
3. عند اختيار تبويب: `GET /api/providers?region_id={id}&page=1&per_page=20` (+ باقي الفلاتر: `service_id`, `home_service`, `sort`).
4. **لا تعتمد على مطابقة نص `city` في JSON المختبر** للفلترة — استخدم `region_id` فقط.
5. Infinite scroll: نفس نمط `page` / `per_page` كما في قسم Pagination أعلاه.

### لوحة الأدمن (السيرفر)
- المسار: `/admin/regions` — إضافة/تعديل/تعطيل المناطق وتحديد الموقع على الخريطة.
- قائمة اختيار مدينة المختبرات في الموقع تُحمَّل من نفس جدول المناطق.

### ملاحظات للمختبرات
- يجب أن يحدّد المختبر **إحداثيات** لموقعه أو لفروعه (من لوحة المختبر) ليظهر في فلترة المنطقة.
- حقل `city` النصي يبقى للعرض والتوافق؛ الفلترة الجغرافية تعتمد على `latitude` / `longitude`.

## API Change: سلة التحاليل (Cart) — دفع مجمّع

> **الحجز المفرد** (`POST /api/bookings` + دفعه) **لم يُلغَ** ويعمل كما كان.

### Endpoints (محمية بـ Bearer)

| Method | Path | الوصف |
|--------|------|--------|
| GET | `/api/cart` | عرض السلة + المجاميع |
| POST | `/api/cart/items` | إضافة تحليل |
| DELETE | `/api/cart/items/{id}` | حذف عنصر |
| DELETE | `/api/cart` | إفراغ السلة |
| POST | `/api/cart/checkout` | إنشاء `cart_order` + حجوزات + تفريغ السلة |
| GET | `/api/cart-orders/{id}` | تفاصيل الطلب |
| POST | `/api/cart-orders/{id}/payment/session` | WebView دفع **مجموع** السلة |
| GET | `/api/cart-orders/{id}/payment/status` | مزامنة بعد الدفع |

### الدفع

- `order_id` في EdfaPay للسلة: **`CO{cart_order_id}`** (مثال `CO15`).
- Webhook وصفحة `guest-return` تدعمان السلة دون كسر الحجز المفرد.
- مبلغ الدفع = `cart_order.total_amount` (مجموع أسطر الحجز).
- عند النجاح: تأكيد **كل** `bookings` المرتبطة بـ `cart_order_id`.

### قيود

- سلة واحدة = **مختبر واحد**.
- لا تستدعِ `POST /api/bookings/{id}/payment/session` لحجز تابع لسلة غير مدفوعة (يرجع 422 مع `payment_endpoint` للسلة).

### توثيق التطبيق

راجع **`CART_API.md`** (أمثلة JSON وتدفق Flutter كامل).

---

## API Change: أقرب فرع + الحجز على الفرع الصحيح

> تفاصيل كاملة في `brances.md`. ملخص للتطبيق:

### `POST /api/bookings` — حقول إضافية
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

**أولوية اختيار `branch_id` على السيرفر:**
1. `branch_id` من التطبيق (إن كان تابعاً للمختبر ونشطاً) — **لا يُستبدل** بفرع الـ time slot.
2. أقرب فرع نشط له إحداثيات عند إرسال `latitude` + `longitude` (أو `home_latitude`/`home_longitude` للمنزل).
3. `time_slot.branch_id` إن كان نشطاً.
4. أول فرع نشط (fallback + log).

- عند `in_clinic` ومختبر له **أكثر من فرع** وبدون `branch_id` وبدون إحداثيات → **422**.
- الاستجابة تتضمن `branch_id`, `branch_name`, وكائن `branch`.

### `GET /api/providers?latitude=...&longitude=...` أو مع `region_id`
كل مختبر قد يتضمن:
```json
"nearest_branch": {
  "id": 12,
  "name_ar": "فرع الخرج",
  "city": "الخرج",
  "district": "حي العزيزية",
  "latitude": 24.155,
  "longitude": 47.334,
  "distance_km": 8.2
}
```
مع `region_id` يُحسب `nearest_branch` من **مركز المنطقة**.

### `GET /api/providers/{id}/time-slots?date=YYYY-MM-DD&branch_id=12`
- يفلتر المواعيد للفرع المحدد (+ المواعيد العامة `branch_id=null`).
- كل slot يتضمن `branch_id`.

### `GET /api/branches` و `/api/providers/{id}/branches`
- حقول: `id`, `provider_id`, `name_ar`, `name_en`, `city`, `district`, `address`, `latitude`, `longitude`, `is_active`, `phone`.

## API Change: تفاصيل المختبر خفيفة + تحاليل بصفحات (Infinite scroll)

### الهدف
- صفحة تفاصيل المختبر كانت تعتمد على `GET /api/providers/{id}` الذي يحمّل **كل** التحاليل (`provider_services` + خدمة + فئة) و**كل** التقييمات المرتبطة، فيبطئ التطبيق عند المختبرات الكبيرة.
- تم **فصل** بيانات التحاليل عن تفاصيل المختبر الأساسية وجعل جلب التحاليل **صفحات** كما في بقية القوائم.

### ما تغيّر في الـ API

#### 1) `GET /api/providers/{id}` — تفاصيل مختبر (خفيفة)
- **لم يعد** يرجع الحقول/العلاقات الثقيلة:
  - لا يوجد `provider_services` (ولا `services` المدمجة مع التحاليل).
  - لا يُحمّل تقييمات المختبر ضمن هذا الطلب (استخدم `GET /api/providers/{id}/reviews` مع `page` / `per_page`).
- يُرجع بدلاً منها عدّاً جاهزاً للواجهة:
  - **`available_services_count`**: عدد عناصر `provider_services` المتاحة (`is_available = true`) لهذا المختبر.
- ما زال يُرجع: معلومات المختبر، `user` مختصر، وعروض (`offers`) النشطة **حد أقصى 40** حسب الأحدث (للعرض في البطاقات فقط).

#### 2) `GET /api/providers/{id}/services` — التحاليل بصفحات + بحث + ترتيب
- يدعم **`page`** و **`per_page`** (حد أقصى `50`، افتراضي `20`) كما سبق.
- **بحث اختياري** داخل تحاليل هذا المختبر فقط:
  - `GET /api/providers/{id}/services?q=دم&page=1&per_page=20`
  - يطابق `name_ar` أو `name_en` للخدمة المرتبطة (LIKE).
- **ترتيب اختياري** لسعر التحليل عند المختبر (حقل `final_price` في `provider_services`):
  - `sort=price_asc` — من الأرخص للأغلى
  - `sort=price_desc` — من الأغلى للأرخص
  - بدون `sort` — ترتيب ثابت حسب `id` (مناسب للتمرير المتكرر دون قفزات).

### ما يجب أن يفعله التطبيق (صفحة تفاصيل المختبر)

1. **خطوة أولى** بعد اختيار مختبر:
   - `GET /api/providers/{id}` لعرض الهيدر (اسم، مدينة، تقييم، `available_services_count`، إلخ).
2. **قائمة التحاليل** (RecyclerView / LazyColumn):
   - `GET /api/providers/{id}/services?page=1&per_page=20`
   - عند التمرير لأسفل: إذا `current_page < last_page` → طلب `page=2` ثم `3`… و**إلحاق** النتائج بالقائمة (append).
   - عند البحث داخل المختبر: أعد الطلب من `page=1` مع نفس `q` (مع **debounce** ~300–500ms حتى لا تُحمّل السيرفر عند كل حرف).
3. **التقييمات** (إن وُجدت شاشة منفصلة أو تبويب):
   - `GET /api/providers/{id}/reviews?page=1&per_page=15` بنفس نمط التمرير.

### تغيير جانبي: قائمة المختبرات والرئيسية
- **`GET /api/providers`**: لم يعد يحمّل علاقة `services` لكل مختبر في الاستجابة (كانت ثقيلة دون فائدة واضحة في JSON). الفلترة بـ `service_id` ما زالت تعمل عبر `whereHas`.
- **`GET /api/home`**: أُزيل تحميل `providerServices` للمختبرات المميزة (لم تكن تُستخدم في الـ JSON أصلاً).

---

## توصيات أداء للتطبيق (تنفّذ في الكود هناك — ليست تغييرات API)

> هذا القسم إرشادي لفريق التطبيق؛ تنفيذه يقلل البطء في «أغلب الصفحات» دون انتظار تعديلات إضافية من الـ API.

### شبكة وطلبات
- **لا تكرر** طلب `GET /api/providers/{id}` عند كل `onResume` إن لم يتغيّر المختبر؛ خزّن نسخة في الذاكرة مع `ETag` بسيط (وقت آخر جلب) أو استخدم كاش محلي قصير العمر.
- راعِ **حد التوازي**: لا تشغّل أكثر من 3–4 طلبات HTTP ثقيلة في نفس اللحظة على شاشة واحدة.
- فعّل **ضغط HTTP** (Gzip) في العميل إن كان معطّلاً؛ السيرفر يرسل JSON عادة مضغوطاً.

### واجهة وتمرير
- استخدم **Paging 3** (أندرويد) أو مكافئه: التحميل الكسول للصفحات بدل `getItemCount()` ضخم.
- للصور: **Coil / Glide** مع `resize` و`memoryCache`؛ لا تعرض صوراً بأبعاد الشاشة الكاملة لمصغّرات القوائم.
- تجنب **إعادة بناء القائمة كاملة** عند append صفحة جديدة (استخدم `notifyItemRangeInserted`).

### تجربة المستخدم
- أظهر **Skeleton / Shimmer** بدل شاشة بيضاء أثناء أول طلب؛ حمّل الهيدر أولاً ثم التحاليل.
- للبحث داخل المختبر: **debounce** قبل استدعاء `/services?q=`.

### أماكن أخرى في الـ API تدعم الصفحات مسبقاً
- راجع قسم **Infinite Scroll Pagination** أعلاه لـ `packages`, `offers`, `services`, `branches`, إلخ — طبّق نفس نمط `page` / `per_page` في كل شاشة قائمة.
