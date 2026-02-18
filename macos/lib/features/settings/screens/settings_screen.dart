import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rast/core/api/api_services.dart';
import 'package:rast/core/constants/app_strings.dart';
import 'package:rast/core/providers/app_settings_provider.dart';
import 'package:rast/core/theme/app_theme.dart';
import 'package:rast/core/utils/responsive.dart';
import 'package:rast/features/settings/screens/default_location_screen.dart';
import 'package:url_launcher/url_launcher.dart';

/// إصدار التطبيق (يُحدَّث مع pubspec)
const String kAppVersion = '1.0.0';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _promoEnabled = false;
  Map<String, dynamic>? _siteConfig;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      final config = await Api.home.getConfig();
      final site = config['site'];
      if (mounted && site is Map) {
        setState(() => _siteConfig = Map<String, dynamic>.from(site));
      }
    } catch (_) {}
  }

  Future<void> _openUrl(String? url, {bool isPhone = false, bool isEmail = false}) async {
    if (url == null || url.trim().isEmpty) return;
    final s = url.trim();
    Uri? uri;
    if (isPhone) {
      final digits = s.replaceAll(RegExp(r'[^\d+]'), '');
      uri = Uri.parse('tel:$digits');
    } else if (isEmail || s.contains('@')) {
      uri = Uri.parse('mailto:$s');
    } else {
      uri = Uri.tryParse(s.startsWith('http') ? s : 'https://$s');
    }
    if (uri == null) return;
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    final lang = settings.language;
    return Directionality(
      textDirection: settings.textDirection,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          title: Text(AppStrings.t('settings', lang)),
          elevation: 0,
          backgroundColor: Theme.of(context).colorScheme.surface,
        ),
        body: ListView(
          padding: EdgeInsets.all(Responsive.spacing(context, 20)),
          children: [
            _buildSectionTitle(AppStrings.t('notifications', lang)),
            _buildSettingsCard(
              children: [
                _buildSwitchTile(
                  icon: Icons.notifications_outlined,
                  title: AppStrings.t('bookingReminders', lang),
                  subtitle: AppStrings.t('bookingRemindersDesc', lang),
                  value: _notificationsEnabled,
                  onChanged: (v) => setState(() => _notificationsEnabled = v),
                ),
                Divider(height: 1, color: AppTheme.surfaceVariant),
                _buildSwitchTile(
                  icon: Icons.campaign_outlined,
                  title: AppStrings.t('promoNotifications', lang),
                  subtitle: AppStrings.t('promoNotificationsDesc', lang),
                  value: _promoEnabled,
                  onChanged: (v) => setState(() => _promoEnabled = v),
                ),
              ],
            ),
            SizedBox(height: Responsive.spacing(context, 28)),
            _buildSectionTitle(AppStrings.t('appSection', lang)),
            _buildSettingsCard(
              children: [
                _buildSelectTile(
                  icon: Icons.language_rounded,
                  title: AppStrings.t('language', lang),
                  value: settings.isArabic ? AppStrings.t('arabic', lang) : AppStrings.t('english', lang),
                  onTap: () => _showLanguageSheet(context, settings),
                ),
                Divider(height: 1, color: AppTheme.surfaceVariant),
                _buildSwitchTile(
                  icon: Icons.dark_mode_rounded,
                  title: AppStrings.t('darkMode', lang),
                  subtitle: settings.isDarkMode ? AppStrings.t('darkModeOn', lang) : AppStrings.t('darkModeOff', lang),
                  value: settings.isDarkMode,
                  onChanged: (_) => settings.toggleDarkMode(),
                ),
                Divider(height: 1, color: AppTheme.surfaceVariant),
                _buildNavigationTile(
                  icon: Icons.location_on_outlined,
                  title: AppStrings.t('defaultLocation', lang),
                  subtitle: AppStrings.t('defaultLocationDesc', lang),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DefaultLocationScreen())),
                ),
              ],
            ),
            SizedBox(height: Responsive.spacing(context, 28)),
            _buildSectionTitle(AppStrings.t('support', lang)),
            _buildSettingsCard(
              children: [
                _buildNavigationTile(
                  icon: Icons.help_outline_rounded,
                  title: AppStrings.t('faq', lang),
                  onTap: () {},
                ),
                Divider(height: 1, color: AppTheme.surfaceVariant),
                _buildNavigationTile(
                  icon: Icons.contact_support_outlined,
                  title: AppStrings.t('contactUs', lang),
                  onTap: () {},
                ),
                Divider(height: 1, color: AppTheme.surfaceVariant),
                _buildNavigationTile(
                  icon: Icons.description_outlined,
                  title: AppStrings.t('terms', lang),
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
            _buildSectionTitle('منصات التواصل'),
            _buildSettingsCard(
              children: _buildSocialSectionChildren(),
            ),
            SizedBox(height: Responsive.spacing(context, 28)),
            _buildSectionTitle('حول التطبيق'),
            _buildSettingsCard(
              children: [
                _buildInfoTile(
                  icon: Icons.verified_outlined,
                  title: 'التطبيق',
                  value: _siteConfig?['name']?.toString() ?? 'راست - مختبراتك',
                ),
                Divider(height: 1, color: AppTheme.surfaceVariant),
                _buildInfoTile(
                  icon: Icons.info_outline_rounded,
                  title: 'إصدار التطبيق',
                  value: kAppVersion,
                ),
                Divider(height: 1, color: AppTheme.surfaceVariant),
                _buildInfoTile(
                  icon: Icons.copyright_rounded,
                  title: 'حقوق النشر',
                  value: '© ${DateTime.now().year}',
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
      decoration: AppTheme.cardDecorationFor(context),
      child: Column(children: children),
    );
  }

  List<Widget> _buildSocialSectionChildren() {
    final site = _siteConfig;
    final list = <Widget>[];
    void addTile(IconData icon, String title, dynamic value, {bool isPhone = false, bool isEmail = false}) {
      final v = value?.toString().trim();
      if (v != null && v.isNotEmpty) {
        if (list.isNotEmpty) list.add(Divider(height: 1, color: AppTheme.surfaceVariant));
        list.add(_buildSocialTile(icon, title, v, isPhone: isPhone, isEmail: isEmail));
      }
    }
    addTile(Icons.phone_outlined, 'الهاتف', site?['phone'], isPhone: true);
    addTile(Icons.email_outlined, 'البريد الإلكتروني', site?['email'], isEmail: true);
    addTile(Icons.link_rounded, 'فيسبوك', site?['facebook']);
    addTile(Icons.link_rounded, 'تويتر / X', site?['twitter']);
    addTile(Icons.camera_alt_outlined, 'انستغرام', site?['instagram']);
    if (list.isEmpty) {
      list.add(_buildInfoTile(
        icon: Icons.share_outlined,
        title: 'منصات التواصل',
        value: 'غير متوفرة حالياً',
      ));
    }
    return list;
  }

  Widget _buildSocialTile(IconData icon, String title, String value, {bool isPhone = false, bool isEmail = false}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openUrl(value, isPhone: isPhone, isEmail: isEmail),
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
                  color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 22, color: Theme.of(context).colorScheme.secondary),
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
                    if (value.length > 40)
                      Text(
                        '${value.substring(0, 40)}...',
                        style: TextStyle(
                          fontSize: Responsive.fontSize(context, 12),
                          color: AppTheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    else
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: Responsive.fontSize(context, 12),
                          color: AppTheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Icon(Icons.open_in_new_rounded, size: 18, color: AppTheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
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
