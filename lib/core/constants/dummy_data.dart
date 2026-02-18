// بيانات وهمية للواجهة الرئيسية - تتوافق مع هيكل Laravel API

class DummyData {
  static const List<Map<String, dynamic>> carouselSlides = [
  ];

  static const List<Map<String, dynamic>> categories = [
    {'id': 1, 'name_ar': 'فحوصات الدم', 'name_en': 'Blood Tests', 'slug': 'blood', 'icon': '🩸', 'image_url': 'https://picsum.photos/200/200?random=cat1', 'services_count': 24},
    {'id': 2, 'name_ar': 'فحوصات الغدة', 'name_en': 'Thyroid', 'slug': 'thyroid', 'icon': '🦋', 'image_url': 'https://picsum.photos/200/200?random=cat2', 'services_count': 12},
    {'id': 3, 'name_ar': 'سكر ودهون', 'name_en': 'Sugar & Lipids', 'slug': 'sugar', 'icon': '💉', 'image_url': 'https://picsum.photos/200/200?random=cat3', 'services_count': 18},
    {'id': 4, 'name_ar': 'هرمونات', 'name_en': 'Hormones', 'slug': 'hormones', 'icon': '🧬', 'image_url': 'https://picsum.photos/200/200?random=cat4', 'services_count': 15},
    {'id': 5, 'name_ar': 'الكبد', 'name_en': 'Liver', 'slug': 'liver', 'icon': '🫀', 'image_url': 'https://picsum.photos/200/200?random=cat5', 'services_count': 10},
    {'id': 6, 'name_ar': 'فحوصات عامة', 'name_en': 'General', 'slug': 'general', 'icon': '📋', 'image_url': 'https://picsum.photos/200/200?random=cat6', 'services_count': 32},
  ];

  static const List<Map<String, dynamic>> packages = [
    {
      'id': 1,
      'name_ar': 'باقة الفحص الشامل',
      'name_en': 'Full Checkup Package',
      'price': 299,
      'original_price': 450,
      'image_url': 'https://picsum.photos/300/200?random=p1',
      'tests_count': 15,
    },
    {
      'id': 2,
      'name_ar': 'باقة السكري',
      'name_en': 'Diabetes Package',
      'price': 149,
      'original_price': 200,
      'image_url': 'https://picsum.photos/300/200?random=p2',
      'tests_count': 6,
    },
    {
      'id': 3,
      'name_ar': 'باقة الهرمونات',
      'name_en': 'Hormones Package',
      'price': 399,
      'original_price': 520,
      'image_url': 'https://picsum.photos/300/200?random=p3',
      'tests_count': 8,
    },
    {
      'id': 4,
      'name_ar': 'باقة المرأة',
      'name_en': 'Women Package',
      'price': 249,
      'original_price': 320,
      'image_url': 'https://picsum.photos/300/200?random=p4',
      'tests_count': 10,
    },
  ];

  static const List<Map<String, dynamic>> labs = [];

  static const List<String> cities = ['الرياض', 'جدة', 'الدمام', 'مكة', 'المدينة'];

  static const List<Map<String, dynamic>> filterOptions = [
    {'id': 'home_service', 'name_ar': 'خدمة منزلية', 'name_en': 'Home Service'},
    {'id': 'rating', 'name_ar': 'الأعلى تقييماً', 'name_en': 'Top Rated'},
    {'id': 'nearest', 'name_ar': 'الأقرب', 'name_en': 'Nearest'},
  ];

  // التحاليل/الخدمات
  static const List<Map<String, dynamic>> services = [
    {'id': 1, 'name_ar': 'تحليل صورة الدم الكاملة', 'category_id': 1, 'price': 45, 'description_ar': 'تحليل شامل لخلايا الدم', 'image_url': 'https://picsum.photos/400/300?random=s1'},
    {'id': 2, 'name_ar': 'تحليل السكر الصائم', 'category_id': 3, 'price': 25, 'description_ar': 'قياس مستوى السكر بعد الصيام', 'image_url': 'https://picsum.photos/400/300?random=s2'},
    {'id': 3, 'name_ar': 'تحليل الدهون الثلاثية', 'category_id': 3, 'price': 55, 'description_ar': 'قياس مستوى الدهون', 'image_url': 'https://picsum.photos/400/300?random=s3'},
    {'id': 4, 'name_ar': 'تحليل الغدة الدرقية TSH', 'category_id': 2, 'price': 75, 'description_ar': 'فحص وظائف الغدة الدرقية', 'image_url': 'https://picsum.photos/400/300?random=s4'},
    {'id': 5, 'name_ar': 'تحليل وظائف الكبد', 'category_id': 5, 'price': 120, 'description_ar': 'إنزيمات الكبد والبيليروبين', 'image_url': 'https://picsum.photos/400/300?random=s5'},
    {'id': 6, 'name_ar': 'تحليل فيتامين د', 'category_id': 6, 'price': 95, 'description_ar': 'قياس مستوى فيتامين د', 'image_url': 'https://picsum.photos/400/300?random=s6'},
    {'id': 7, 'name_ar': 'تحليل الكرياتينين', 'category_id': 6, 'price': 35, 'description_ar': 'وظائف الكلى', 'image_url': 'https://picsum.photos/400/300?random=s7'},
    {'id': 8, 'name_ar': 'تحليل الهيموجلوبين', 'category_id': 1, 'price': 30, 'description_ar': 'قياس الهيموجلوبين', 'image_url': 'https://picsum.photos/400/300?random=s8'},
  ];

  // تفاصيل المختبر (فروع، مراجعات)
  static List<Map<String, dynamic>> getLabBranches(int labId) => [
        {'id': 1, 'name_ar': 'الفرع الرئيسي', 'address': 'طريق الملك فهد، الرياض', 'phone': '0112345678', 'city': 'الرياض'},
        {'id': 2, 'name_ar': 'فرع النخيل', 'address': 'حي النخيل، الرياض', 'phone': '0118765432', 'city': 'الرياض'},
      ];

  static List<Map<String, dynamic>> getLabServices(int labId) => [
        {'id': 1, 'name_ar': 'صورة الدم الكاملة', 'price': 45, 'home_price': 65},
        {'id': 2, 'name_ar': 'السكر الصائم', 'price': 25, 'home_price': 45},
        {'id': 3, 'name_ar': 'وظائف الكبد', 'price': 120, 'home_price': 140},
      ];

  static List<Map<String, dynamic>> getLabReviews(int labId) => [
        {'id': 1, 'user_name': 'أحمد م.', 'rating': 5, 'comment': 'خدمة ممتازة ونتائج سريعة', 'date': '2024-01-15'},
        {'id': 2, 'user_name': 'سارة ع.', 'rating': 4, 'comment': 'الفريق متعاون والوقت محترم', 'date': '2024-01-10'},
        {'id': 3, 'user_name': 'محمد خ.', 'rating': 5, 'comment': 'أنصح به بشدة', 'date': '2024-01-05'},
      ];

  // الحجوزات
  static const List<Map<String, dynamic>> bookings = [
    {
      'id': 1,
      'booking_number': 'RST-2024-001247',
      'status': 'confirmed',
      'payment_status': 'paid',
      'booking_date': '2024-02-10',
      'booking_time': '09:00',
      'service_type': 'in_clinic',
      'service_name_ar': 'تحليل صورة الدم الكاملة',
      'provider_name_ar': 'مختبر الفاروق',
      'total_amount': 45,
      'branch_name': 'الفرع الرئيسي',
    },
    {
      'id': 2,
      'booking_number': 'RST-2024-001389',
      'status': 'pending',
      'payment_status': 'pending',
      'booking_date': '2024-02-12',
      'booking_time': '14:30',
      'service_type': 'home_service',
      'service_name_ar': 'تحليل السكر والدهون',
      'provider_name_ar': 'مختبر الصحة',
      'total_amount': 95,
      'branch_name': 'منزلي',
    },
    {
      'id': 3,
      'booking_number': 'RST-2024-000982',
      'status': 'completed',
      'payment_status': 'paid',
      'booking_date': '2024-01-28',
      'booking_time': '10:00',
      'service_type': 'in_clinic',
      'service_name_ar': 'تحليل الغدة الدرقية',
      'provider_name_ar': 'مختبر المعرفة',
      'total_amount': 75,
      'branch_name': 'فرع الياسمين',
    },
  ];
}
