import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:rast/core/theme/app_theme.dart';
import 'package:rast/core/services/location_service.dart';
import 'package:rast/core/widgets/gradient_button.dart';
import 'package:rast/core/utils/responsive.dart';

/// شاشة إعداد الموقع الافتراضي - للعثور على المختبرات القريبة
class DefaultLocationScreen extends StatefulWidget {
  const DefaultLocationScreen({super.key});

  @override
  State<DefaultLocationScreen> createState() => _DefaultLocationScreenState();
}

class _DefaultLocationScreenState extends State<DefaultLocationScreen> {
  ({double lat, double lng, String? label})? _savedLocation;
  bool _isLoading = false;
  String? _message;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final loc = await LocationService.getDefaultLocation();
    if (mounted) {
      setState(() => _savedLocation = loc);
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _message = 'السماح بالموقع مطلوب للعثور على المختبرات القريبة';
          });
        }
        return;
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _message = 'تفعيل خدمة الموقع أولاً';
          });
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      await LocationService.setDefaultLocation(
        latitude: pos.latitude,
        longitude: pos.longitude,
        label: 'موقعي الحالي',
      );
      if (mounted) {
        setState(() {
          _savedLocation = (lat: pos.latitude, lng: pos.longitude, label: 'موقعي الحالي');
          _isLoading = false;
          _message = 'تم حفظ موقعك الافتراضي';
          _isSuccess = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _message = 'تعذر الحصول على الموقع: ${e.toString().split('\n').first}';
        });
      }
    }
  }

  Future<void> _clearLocation() async {
    await LocationService.clearDefaultLocation();
    if (mounted) {
      setState(() {
        _savedLocation = null;
        _message = 'تم إلغاء الموقع الافتراضي';
        _isSuccess = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          title: const Text('الموقع الافتراضي'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(Responsive.spacing(context, 20)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: EdgeInsets.all(Responsive.spacing(context, 20)),
                decoration: AppTheme.cardDecorationFor(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(Icons.location_on_rounded, color: AppTheme.primary, size: 28),
                        ),
                        SizedBox(width: Responsive.spacing(context, 14)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('العثور على المختبرات القريبة', style: TextStyle(fontSize: Responsive.fontSize(context, 16), fontWeight: FontWeight.w600)),
                              SizedBox(height: 4),
                              Text('احفظ موقعك أو عنوانك الافتراضي لعرض المختبرات الأقرب لك', style: TextStyle(fontSize: Responsive.fontSize(context, 12), color: AppTheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: Responsive.spacing(context, 24)),
              if (_savedLocation != null) ...[
                Container(
                  padding: EdgeInsets.all(Responsive.spacing(context, 16)),
                  decoration: AppTheme.cardDecorationFor(context),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 28),
                      SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_savedLocation!.label ?? 'موقع محفوظ', style: TextStyle(fontSize: Responsive.fontSize(context, 14), fontWeight: FontWeight.w500)),
                            Text('${_savedLocation!.lat.toStringAsFixed(4)}, ${_savedLocation!.lng.toStringAsFixed(4)}', style: TextStyle(fontSize: Responsive.fontSize(context, 11), color: AppTheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: _isLoading ? null : _clearLocation,
                        child: const Text('إلغاء'),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: Responsive.spacing(context, 20)),
              ],
              GradientFilledButtonIcon(
                onPressed: _isLoading ? null : _useCurrentLocation,
                icon: _isLoading ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.my_location),
                label: Text(_savedLocation != null ? 'تحديث بموقعي الحالي' : 'استخدم موقعي الحالي'),
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: Responsive.spacing(context, 14)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              if (_message != null) ...[
                SizedBox(height: Responsive.spacing(context, 16)),
                Container(
                  padding: EdgeInsets.all(Responsive.spacing(context, 12)),
                  decoration: BoxDecoration(
                    color: _isSuccess ? Colors.green.withValues(alpha: 0.1) : AppTheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(_isSuccess ? Icons.check_circle : Icons.info_outline, color: _isSuccess ? Colors.green : AppTheme.error, size: 22),
                      SizedBox(width: 10),
                      Expanded(child: Text(_message!, style: TextStyle(fontSize: Responsive.fontSize(context, 13), color: _isSuccess ? Colors.green : AppTheme.error))),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
