import 'dart:async';

import 'package:rast/core/api/api_services.dart';
import 'package:rast/core/services/app_cache_service.dart';

/// لقطة بيانات الصفحة الرئيسية للعرض الفوري.
class HomeSnapshot {
  HomeSnapshot({
    required this.homeData,
    required this.carouselSlides,
    required this.packages,
    required this.offers,
    required this.labs,
    this.totalPackages,
    this.totalOffers,
    this.totalLabs,
  });

  final Map<String, dynamic> homeData;
  final List<dynamic> carouselSlides;
  final List<dynamic> packages;
  final List<dynamic> offers;
  final List<dynamic> labs;
  final int? totalPackages;
  final int? totalOffers;
  final int? totalLabs;

  Map<String, dynamic> toJson() => {
        'homeData': homeData,
        'carouselSlides': carouselSlides,
        'packages': packages,
        'offers': offers,
        'labs': labs,
        'totalPackages': totalPackages,
        'totalOffers': totalOffers,
        'totalLabs': totalLabs,
      };

  factory HomeSnapshot.fromJson(Map<String, dynamic> json) {
    return HomeSnapshot(
      homeData: Map<String, dynamic>.from(
        json['homeData'] is Map ? json['homeData'] as Map : {},
      ),
      carouselSlides: _list(json['carouselSlides']),
      packages: _list(json['packages']),
      offers: _list(json['offers']),
      labs: _list(json['labs']),
      totalPackages: _int(json['totalPackages']),
      totalOffers: _int(json['totalOffers']),
      totalLabs: _int(json['totalLabs']),
    );
  }

  static List<dynamic> _list(dynamic v) =>
      v is List ? List<dynamic>.from(v) : [];

  static int? _int(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '');
  }
}

/// كاش الفئات / التحاليل / الباقات / المختبرات + الذاكرة للجلسة الحالية.
class CatalogCacheService {
  CatalogCacheService._();

  static const _kHome = 'rast_catalog_home_v1';
  static const _kCategories = 'rast_catalog_categories_v1';
  static const _kServicesP1 = 'rast_catalog_services_p1_v1';
  static const _kPackagesP1 = 'rast_catalog_packages_p1_v1';
  static const _kLabsP1 = 'rast_catalog_labs_p1_v1';
  static const _kBranches = 'rast_catalog_branches_v1';

  static const int maxCategories = 40;
  static const int maxServices = 30;
  static const int maxPackages = 24;
  static const int maxLabs = 25;
  static const int maxBranches = 400;

  static bool _hydrated = false;
  static bool _prefetchStarted = false;

  static HomeSnapshot? homeSnapshot;
  static List<dynamic> categories = [];
  static List<dynamic> servicesPage1 = [];
  static List<dynamic> packagesPage1 = [];
  static List<dynamic> labsPage1 = [];
  static Map<int, List<dynamic>> branchesByProvider = {};

  static Future<void> ensureHydrated() async {
    if (_hydrated) return;
    final cache = AppCacheService.instance;
    final results = await Future.wait<dynamic>([
      cache.readPayload(_kHome),
      cache.readPayload(_kCategories),
      cache.readPayload(_kServicesP1),
      cache.readPayload(_kPackagesP1),
      cache.readPayload(_kLabsP1),
      cache.readPayload(_kBranches),
    ]);

    final homeRaw = results[0];
    if (homeRaw is Map) {
      try {
        homeSnapshot = HomeSnapshot.fromJson(Map<String, dynamic>.from(homeRaw));
      } catch (_) {}
    }

    categories = _asList(results[1]);
    servicesPage1 = _asList(results[2]);
    packagesPage1 = _asList(results[3]);
    labsPage1 = _asList(results[4]);

    final branchesRaw = results[5];
    if (branchesRaw is Map) {
      branchesByProvider = {};
      branchesRaw.forEach((key, value) {
        final id = int.tryParse(key.toString());
        if (id == null || value is! List) return;
        branchesByProvider[id] = List<dynamic>.from(value);
      });
    }

    _hydrated = true;
  }

  static List<dynamic> _asList(dynamic v) =>
      v is List ? List<dynamic>.from(v) : [];

  static List<dynamic> _trim(List<dynamic> list, int max) =>
      list.length <= max ? list : list.take(max).toList();

  static Future<void> saveHome(HomeSnapshot snap) async {
    final trimmed = HomeSnapshot(
      homeData: snap.homeData,
      carouselSlides: _trim(snap.carouselSlides, 12),
      packages: _trim(snap.packages, maxPackages),
      offers: _trim(snap.offers, 16),
      labs: _trim(snap.labs, 12),
      totalPackages: snap.totalPackages,
      totalOffers: snap.totalOffers,
      totalLabs: snap.totalLabs,
    );
    homeSnapshot = trimmed;
    await AppCacheService.instance.write(_kHome, trimmed.toJson());
  }

  static Future<void> saveCategories(List<dynamic> list) async {
    categories = _trim(list, maxCategories);
    await AppCacheService.instance.write(_kCategories, categories);
  }

  static Future<void> saveServicesPage1(List<dynamic> list) async {
    servicesPage1 = _trim(list, maxServices);
    await AppCacheService.instance.write(_kServicesP1, servicesPage1);
  }

  static Future<void> savePackagesPage1(List<dynamic> list) async {
    packagesPage1 = _trim(list, maxPackages);
    await AppCacheService.instance.write(_kPackagesP1, packagesPage1);
  }

  static Future<void> saveLabsPage1(List<dynamic> list) async {
    labsPage1 = _trim(list, maxLabs);
    await AppCacheService.instance.write(_kLabsP1, labsPage1);
  }

  static Future<void> saveBranchesIndex(Map<int, List<dynamic>> map) async {
    var count = 0;
    final trimmed = <int, List<dynamic>>{};
    for (final e in map.entries) {
      if (count >= maxBranches) break;
      trimmed[e.key] = e.value;
      count += e.value.length;
    }
    branchesByProvider = trimmed;
    final serial = <String, dynamic>{};
    trimmed.forEach((k, v) => serial['$k'] = v);
    await AppCacheService.instance.write(_kBranches, serial);
  }

  /// أثناء السبلاش: تحميل الكاش من القرص ثم تحديث الشبكة بصمت.
  static Future<void> warmDuringSplash() async {
    await ensureHydrated();
    startBackgroundPrefetch();
  }

  static void startBackgroundPrefetch() {
    if (_prefetchStarted) return;
    _prefetchStarted = true;
    unawaited(_prefetchFromNetwork());
  }

  static Future<void> _prefetchFromNetwork() async {
    await Future.wait<void>([
      _prefetchCategories(),
      _prefetchServices(),
      _prefetchPackages(),
      _prefetchLabs(),
      _prefetchHome(),
      _prefetchBranches(),
    ], eagerError: false);
  }

  static Future<void> _prefetchCategories() async {
    try {
      final list = await Api.services.getCategories();
      if (list.isNotEmpty) await saveCategories(list);
    } catch (_) {}
  }

  static Future<void> _prefetchServices() async {
    try {
      final res = await Api.services.getServices(page: 1, perPage: 24);
      final list = _extractList(res['data']);
      if (list.isNotEmpty) await saveServicesPage1(list);
    } catch (_) {}
  }

  static Future<void> _prefetchPackages() async {
    try {
      final res = await Api.services.getPackages(page: 1, perPage: 20);
      final list = _extractList(res['data']);
      if (list.isNotEmpty) await savePackagesPage1(list);
    } catch (_) {}
  }

  static Future<void> _prefetchLabs() async {
    try {
      final res = await Api.providers.getProviders(page: 1, perPage: 20);
      final list = _extractList(res['data']);
      if (list.isNotEmpty) await saveLabsPage1(list);
    } catch (_) {}
  }

  static Future<void> _prefetchHome() async {
    try {
      final homeData = await Api.home.getHome();
      final slides =
          (homeData['carousel_slides'] as List?)?.where((e) => e != null).toList() ??
              [];
      var packages =
          (homeData['packages'] as List?)?.where((e) => e != null).toList() ?? [];
      if (packages.isEmpty) {
        try {
          final res = await Api.services.getPackages(page: 1, perPage: 16);
          packages = _extractList(res['data']);
        } catch (_) {}
      }
      var labs =
          (homeData['featured_providers'] as List?)
              ?.where((e) => e != null)
              .toList() ??
              [];
      if (labs.isEmpty) {
        try {
          final res = await Api.providers.getProviders(
            sort: 'rating',
            perPage: 12,
          );
          labs = _extractList(res['data']);
        } catch (_) {}
      }
      final snap = HomeSnapshot(
        homeData: Map<String, dynamic>.from(homeData),
        carouselSlides: slides,
        packages: packages,
        offers: const [],
        labs: labs,
      );
      await saveHome(snap);
    } catch (_) {}
  }

  static Future<void> _prefetchBranches() async {
    try {
      final map = <int, List<dynamic>>{};
      var page = 1;
      var total = 0;
      while (page <= 6 && total < maxBranches) {
        final batch = await Api.providers.getBranchesPage(page: page, perPage: 50);
        for (final item in batch.items) {
          if (item is! Map) continue;
          final m = Map<String, dynamic>.from(item);
          if (m['is_active'] == false) continue;
          final pid = _providerIdFromBranch(m);
          if (pid == null) continue;
          map.putIfAbsent(pid, () => []).add(m);
          total++;
          if (total >= maxBranches) break;
        }
        if (!batch.hasMore) break;
        page++;
      }
      if (map.isNotEmpty) await saveBranchesIndex(map);
    } catch (_) {}
  }

  static List<dynamic> _extractList(dynamic data) {
    if (data is List) return List.from(data);
    if (data is Map && data['data'] is List) {
      return List.from(data['data'] as List);
    }
    return [];
  }

  static int? _providerIdFromBranch(Map<String, dynamic> branch) {
    final direct = branch['provider_id'];
    if (direct is int) return direct;
    if (direct != null) return int.tryParse(direct.toString());
    final nested = branch['provider'];
    if (nested is Map) {
      final id = nested['id'];
      if (id is int) return id;
      return int.tryParse(id?.toString() ?? '');
    }
    return null;
  }
}
