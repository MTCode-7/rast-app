import 'dart:async';

import 'package:rast/core/api/api_services.dart';
import 'package:rast/core/services/catalog_cache_service.dart';
import 'package:rast/core/utils/lab_location_utils.dart';

/// فهرس فروع المختبرات (مجمّع حسب provider_id) للعرض في القوائم.
class BranchesIndexService {
  BranchesIndexService._();
  static final BranchesIndexService instance = BranchesIndexService._();

  Map<int, List<dynamic>> _byProviderId = {};
  bool _loaded = false;
  bool _loading = false;

  Map<int, List<dynamic>> get byProviderId => _byProviderId;

  List<dynamic>? branchesFor(Map<String, dynamic> lab) {
    final id = LabLocationUtils.providerIdFrom(lab);
    if (id == null) return null;
    return _byProviderId[id];
  }

  Future<void> ensureLoaded({bool force = false}) async {
    if (_loaded && !force) return;
    if (_loading) {
      while (_loading) {
        await Future<void>.delayed(const Duration(milliseconds: 40));
      }
      return;
    }

    await CatalogCacheService.ensureHydrated();
    if (!force && CatalogCacheService.branchesByProvider.isNotEmpty) {
      _byProviderId = Map<int, List<dynamic>>.from(
        CatalogCacheService.branchesByProvider,
      );
      _loaded = true;
      unawaited(_fetchFromNetwork(saveCache: true));
      return;
    }

    await _fetchFromNetwork(saveCache: true);
  }

  Future<void> _fetchFromNetwork({required bool saveCache}) async {
    _loading = true;
    final map = <int, List<dynamic>>{};
    try {
      var page = 1;
      var total = 0;
      while (page <= 6 && total < CatalogCacheService.maxBranches) {
        final batch = await Api.providers.getBranchesPage(page: page, perPage: 50);
        for (final item in batch.items) {
          if (item is! Map) continue;
          final m = Map<String, dynamic>.from(item);
          if (m['is_active'] == false) continue;
          final pid = _providerIdFromBranch(m);
          if (pid == null) continue;
          map.putIfAbsent(pid, () => []).add(m);
          total++;
          if (total >= CatalogCacheService.maxBranches) break;
        }
        if (!batch.hasMore) break;
        page++;
      }
      _byProviderId = map;
      _loaded = true;
      if (saveCache && map.isNotEmpty) {
        await CatalogCacheService.saveBranchesIndex(map);
      }
    } catch (_) {
      // يبقى الفهرس فارغاً أو من الكاش.
    } finally {
      _loading = false;
    }
  }

  int? _providerIdFromBranch(Map<String, dynamic> branch) {
    final direct = branch['provider_id'];
    if (direct is int) return direct;
    if (direct != null) return int.tryParse(direct.toString());
    final nested = branch['provider'];
    if (nested is Map) {
      return LabLocationUtils.providerIdFrom(Map<String, dynamic>.from(nested));
    }
    return null;
  }
}
