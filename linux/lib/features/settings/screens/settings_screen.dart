import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/core/theme/app_theme.dart';
import 'package:rast/core/utils/responsive.dart';
import 'package:rast/features/settings/screens/default_location_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _promoEnabled = false;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    return Directionality(
      textDirection: settings.textDirection,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          title: const Text('الإعدادات'),
          elevation: 0,
          backgroundColor: Theme.of(context).colorScheme.surface,
        ),
        body: ListView(
          padding: EdgeInsets.all(Responsive.spacing(context, 20)),
          children: [
            _buildSectionTitle('التنبيهات'),
            _buildSettingsCard(
              children: [
                _buildSwitchTile(
                  icon: Icons.notifications_outlined,
                  title: 'إشعارات الحجوزات',
                  subtitle: 'استلام تذكيرات بالمواعيد والتحديثات',
                  value: _notificationsEnabled,
                  onChanged: (v) => setState(() => _notificationsEnabled = v),
                ),
                Divider(height: 1, color: AppTheme.surfaceVariant),
                _buildSwitchTile(
                  icon: Icons.campaign_outlined,
                  title: 'العروض والإعلانات',
                  subtitle: 'إشعارات بالعروض والخصومات',
                  value: _promoEnabled,
                  onChanged: (v) => setState(() => _promoEnabled = v),
                ),
              ],
            ),
            SizedBox(height: Responsive.spacing(context, 28)),
            _buildSectionTitle('التطبيق'),
            _buildSettingsCard(
              children: [
                _buildSelectTile(
                  icon: Icons.language_rounded,
                  title: 'اللغة',
                  value: settings.isArabic ? 'العربية' : 'English',
                  onTap: () => _showLanguageSheet(context, settings),
                ),
                Divider(height: 1, color: AppTheme.surfaceVariant),
                _buildSwitchTile(
                  icon: Icons.dark_mode_rounded,
                  title: 'الوضع الداكن',
                  subtitle: settings.isDarkMode ? 'مفعّل' : 'معطّل',
                  value: settings.isDarkMode,
                  onChanged: (_) => settings.toggleDarkMode(),
                ),
                Divider(height: 1, color: AppTheme.surfaceVariant),
                _buildNavigationTile(
                  icon: Icons.location_on_outlined,
                  title: 'الموقع الافتراضي',
                  subtitle: 'للعثور على المختبرات القريبة',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DefaultLocationScreen())),
                ),
              ],
            ),
            SizedBox(height: Responsive.spacing(context, 28)),
            _buildSectionTitle('الدعم'),
            _buildSettingsCard(
              children: [
                _buildNavigationTile(
                  icon: Icons.help_outline_rounded,
                  title: 'الأسئلة الشائعة',
                  onTap: () {},
                ),
                Divider(height: 1, color: AppTheme.surfaceVariant),
                _buildNavigationTile(
                  icon: Icons.contact_support_outlined,
                  title: 'تواصل معنا',
                  onTap: () {},
                ),
                Divider(height: 1, color: AppTheme.surfaceVariant),
                _buildNavigationTile(
                  icon: Icons.description_outlined,
                  title: 'الشروط والأحكام',
                  onTap: () {},
                ),
                Divider(height: 1, color: AppTheme.surfaceVariant),
                _buildNavigationTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'سياسة الخصوصية',
                  onTap: () {},
                ),
              ],
            ),
            SizedBox(height: Responsive.spacing(context, 28)),
            _buildSectionTitle('حول التطبيق'),
            _buildSettingsCard(
              children: [
                _buildInfoTile(
                  icon: Icons.info_outline_rounded,
                  title: 'الإصدار',
                  value: '1.0.0',
                ),
                Divider(height: 1, color: AppTheme.surfaceVariant),
                _buildInfoTile(
                  icon: Icons.verified_outlined,
                  title: 'راست - مختبراتك',
                  value: '© 2024',
                ),
              ],
            ),
            SizedBox(height: Responsive.spacing(context, 40)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(
        right: Responsive.spacing(context, 4),
        bottom: Responsive.spacing(context, 10),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: Responsive.fontSize(context, 14),
          fontWeight: FontWeight.w600,
          color: AppTheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildSettingsCard({required List<Widget> children}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: AppTheme.cardDecoration(
        color: isDark ? const Color(0xFF1A2332) : Colors.white,
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.spacing(context, 18),
        vertical: Responsive.spacing(context, 14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 22, color: AppTheme.primary),
          ),
          SizedBox(width: Responsive.spacing(context, 14)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 15),
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onSurface,
                  ),
                ),
                if (subtitle != null) ...[
                  SizedBox(height: Responsive.spacing(context, 2)),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: Responsive.fontSize(context, 13),
                      color: AppTheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppTheme.primary.withValues(alpha: 0.5),
            activeThumbColor: AppTheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.spacing(context, 18),
            vertical: Responsive.spacing(context, 14),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 22, color: AppTheme.primary),
              ),
              SizedBox(width: Responsive.spacing(context, 14)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: Responsive.fontSize(context, 15),
                        fontWeight: FontWeight.w600,
                        color: AppTheme.onSurface,
                      ),
                    ),
                    if (subtitle != null) ...[
                      SizedBox(height: Responsive.spacing(context, 2)),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: Responsive.fontSize(context, 13),
                          color: AppTheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectTile({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.spacing(context, 18),
            vertical: Responsive.spacing(context, 14),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 22, color: AppTheme.primary),
              ),
              SizedBox(width: Responsive.spacing(context, 14)),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 15),
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onSurface,
                  ),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 14),
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
              SizedBox(width: Responsive.spacing(context, 6)),
              Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.spacing(context, 18),
        vertical: Responsive.spacing(context, 14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 22, color: AppTheme.primary),
          ),
          SizedBox(width: Responsive.spacing(context, 14)),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: Responsive.fontSize(context, 15),
                fontWeight: FontWeight.w600,
                color: AppTheme.onSurface,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 14),
              color: AppTheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  void _showLanguageSheet(BuildContext context, AppSettingsProvider settings) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: settings.textDirection,
        child: Container(
          padding: EdgeInsets.all(Responsive.spacing(context, 24)),
          decoration: BoxDecoration(
            color: Theme.of(ctx).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: Responsive.spacing(context, 20)),
              Text(
                'اختر اللغة',
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 18),
                  fontWeight: FontWeight.bold,
                  color: Theme.of(ctx).colorScheme.onSurface,
                ),
              ),
              SizedBox(height: Responsive.spacing(context, 16)),
              ListTile(
                leading: Icon(
                  Icons.check,
                  color: settings.isArabic ? AppTheme.primary : Colors.transparent,
                ),
                title: const Text('العربية'),
                onTap: () {
                  settings.setLanguage('ar');
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.check,
                  color: settings.isArabic ? Colors.transparent : AppTheme.primary,
                ),
                title: const Text('English'),
                onTap: () {
                  settings.setLanguage('en');
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
