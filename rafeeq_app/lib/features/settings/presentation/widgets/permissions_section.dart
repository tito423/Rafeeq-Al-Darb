import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/services/alarm_permissions_service.dart';
import '../../../../core/services/adhan_uri_bridge.dart';
import '../../../../core/theme/app_colors.dart';

/// P3‑41: the owner's real-device feedback asked directly for one place
/// that surfaces every permission the app actually needs — notifications,
/// location, battery-optimization exemption, and the full-screen-intent
/// permission the Adhan's own lock-screen alert depends on (Android 14+
/// can revoke this one independently of notification permission itself).
/// Every check here re-runs whenever the app resumes (the owner grants
/// these from a system settings screen, not an in-app dialog), so the
/// status shown is never stale from before a trip to Settings.
class PermissionsSection extends StatefulWidget {
  const PermissionsSection({super.key});

  @override
  State<PermissionsSection> createState() => _PermissionsSectionState();
}

class _PermissionsSectionState extends State<PermissionsSection>
    with WidgetsBindingObserver {
  bool? _notificationsOk;
  bool? _locationOk;
  bool? _batteryOk;
  bool? _fullScreenOk;
  bool _hasAutostartSettings = false;

  /// Whether this exemption was EVER seen granted on this device. «استثناء
  /// البطارية لما التطبيق بيروح للخلفية بيرجع تاني لوحده»: on Honor/Huawei
  /// the skin's own «إدارة تشغيل التطبيقات» withdraws it while it manages
  /// the app automatically. Nothing in the app revokes it; what the app CAN
  /// do is notice the reversal and say where it is fixed.
  bool _batteryRevoked = false;
  static const _kBatterySeen = 'perm_battery_seen_granted';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshAll();
    AdhanUriBridge.hasKnownAutostartSettings().then((v) {
      if (mounted) setState(() => _hasAutostartSettings = v);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshAll();
  }

  Future<void> _refreshAll() async {
    final notif = await Permission.notification.status;
    final loc = await Geolocator.checkPermission();
    final battery = await AlarmPermissionsService.instance.isBatteryOptimizationExempt();
    final prefs = await SharedPreferences.getInstance();
    if (battery) await prefs.setBool(_kBatterySeen, true);
    final revoked = !battery && (prefs.getBool(_kBatterySeen) ?? false);
    final fullScreen = await AdhanUriBridge.canUseFullScreenIntent();
    if (!mounted) return;
    setState(() {
      _notificationsOk = notif.isGranted;
      _locationOk = loc == LocationPermission.always ||
          loc == LocationPermission.whileInUse;
      _batteryOk = battery;
      _batteryRevoked = revoked;
      _fullScreenOk = fullScreen ?? true; // null = not applicable below API 34
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          _PermissionTile(
            icon: Icons.notifications_active_outlined,
            title: 'settings.perm_notifications'.tr(),
            subtitle: 'settings.perm_notifications_desc'.tr(),
            granted: _notificationsOk,
            onTap: () async {
              final status = await Permission.notification.request();
              if (!status.isGranted) await openAppSettings();
              _refreshAll();
            },
          ),
          const Divider(height: 1),
          _PermissionTile(
            icon: Icons.location_on_outlined,
            title: 'settings.perm_location'.tr(),
            subtitle: 'settings.perm_location_desc'.tr(),
            granted: _locationOk,
            onTap: () async {
              var status = await Geolocator.checkPermission();
              if (status == LocationPermission.denied) {
                status = await Geolocator.requestPermission();
              }
              if (status == LocationPermission.deniedForever) {
                await Geolocator.openAppSettings();
              }
              _refreshAll();
            },
          ),
          const Divider(height: 1),
          _PermissionTile(
            icon: Icons.battery_charging_full_outlined,
            title: 'settings.perm_battery'.tr(),
            subtitle: _batteryRevoked && _hasAutostartSettings
                ? 'settings.perm_battery_revoked'.tr()
                : 'settings.perm_battery_desc'.tr(),
            granted: _batteryOk,
            warn: _batteryRevoked && _hasAutostartSettings,
            onTap: () async {
              // Once the skin has taken it back, asking again only repeats
              // the cycle; the launch manager is where it stays fixed.
              if (_batteryRevoked && _hasAutostartSettings) {
                await AdhanUriBridge.openAutostartSettings();
              } else {
                await AlarmPermissionsService.instance
                    .requestBatteryOptimizationExemption();
              }
              _refreshAll();
            },
          ),
          const Divider(height: 1),
          _PermissionTile(
            icon: Icons.fullscreen_outlined,
            title: 'settings.perm_full_screen'.tr(),
            subtitle: 'settings.perm_full_screen_desc'.tr(),
            granted: _fullScreenOk,
            onTap: () async {
              await AdhanUriBridge.openFullScreenIntentSettings();
              _refreshAll();
            },
          ),
          // P3‑44: no public Android API can report whether this is
          // actually granted (unlike every tile above) — shown only when
          // this device's manufacturer is one with a known settings
          // screen to send the user to, always as a plain "open it"
          // action rather than a pass/fail check it can't honestly make.
          if (_hasAutostartSettings) ...[
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.shield_outlined, color: AppColors.gold),
              title: Text('settings.perm_autostart'.tr()),
              subtitle: Text('settings.perm_autostart_desc'.tr()),
              trailing: const Icon(Icons.chevron_right),
              onTap: AdhanUriBridge.openAutostartSettings,
            ),
          ],
        ],
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool? granted;
  final VoidCallback onTap;
  final bool warn;

  const _PermissionTile({
    this.warn = false,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.granted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ok = granted == true;
    return ListTile(
      leading: Icon(icon, color: scheme.primary),
      title: Text(title),
      subtitle: Text(subtitle,
          style: warn ? TextStyle(color: scheme.error) : null),
      trailing: granted == null
          ? const SizedBox(
              width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(
              ok ? Icons.check_circle : Icons.chevron_right,
              color: ok ? AppColors.success : scheme.outline,
            ),
      onTap: ok ? null : onTap,
    );
  }
}
