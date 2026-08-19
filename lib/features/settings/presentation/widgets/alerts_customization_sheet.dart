import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/alert_settings_provider.dart';

class AlertsCustomizationSheet extends ConsumerWidget {
  const AlertsCustomizationSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final alertState = ref.watch(alertSettingsProvider);
    final alertNotifier = ref.read(alertSettingsProvider.notifier);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.notifications_active_rounded,
                          color: theme.colorScheme.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'مواعيد تنبيهات السور',
                        style: GoogleFonts.amiri(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Surah Al-Baqarah
              _buildSurahAlertCard(
                context,
                title: 'سورة البقرة',
                icon: Icons.menu_book_rounded,
                time: alertState.baqarahTime,
                isEnabled: alertState.isBaqarahEnabled,
                onToggle: (val) => alertNotifier.setBaqarahAlert(val, alertState.baqarahTime),
                onTimeChanged: (newTime) => alertNotifier.setBaqarahAlert(alertState.isBaqarahEnabled, newTime),
              ),
              const SizedBox(height: 12),

              // Surah Al-Kahf
              _buildSurahAlertCard(
                context,
                title: 'سورة الكهف',
                icon: Icons.auto_stories_rounded,
                time: alertState.kahfTime,
                isEnabled: alertState.isKahfEnabled,
                onToggle: (val) => alertNotifier.setKahfAlert(val, alertState.kahfTime),
                onTimeChanged: (newTime) => alertNotifier.setKahfAlert(alertState.isKahfEnabled, newTime),
              ),
              const SizedBox(height: 12),

              // Surah As-Sajdah
              _buildSurahAlertCard(
                context,
                title: 'سورة السجدة',
                icon: Icons.accessibility_new_rounded,
                time: alertState.sajdahTime,
                isEnabled: alertState.isSajdahEnabled,
                onToggle: (val) => alertNotifier.setSajdahAlert(val, alertState.sajdahTime),
                onTimeChanged: (newTime) => alertNotifier.setSajdahAlert(alertState.isSajdahEnabled, newTime),
              ),
              const SizedBox(height: 12),

              // Surah Al-Mulk
              _buildSurahAlertCard(
                context,
                title: 'سورة الملك',
                icon: Icons.nights_stay_rounded,
                time: alertState.mulkTime,
                isEnabled: alertState.isMulkEnabled,
                onToggle: (val) => alertNotifier.setMulkAlert(val, alertState.mulkTime),
                onTimeChanged: (newTime) => alertNotifier.setMulkAlert(alertState.isMulkEnabled, newTime),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSurahAlertCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required TimeOfDay time,
    required bool isEnabled,
    required Function(bool) onToggle,
    required Function(TimeOfDay) onTimeChanged,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isEnabled
            ? theme.colorScheme.primary.withValues(alpha: 0.05)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isEnabled
              ? theme.colorScheme.primary.withValues(alpha: 0.25)
              : theme.dividerColor.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isEnabled
                  ? theme.colorScheme.primary.withValues(alpha: 0.15)
                  : theme.disabledColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: isEnabled ? theme.colorScheme.primary : theme.disabledColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),

          // Title & Dedicated Time Picker Button
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.amiri(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isEnabled ? theme.colorScheme.onSurface : theme.disabledColor,
                  ),
                ),
                const SizedBox(height: 6),
                // Dedicated button to select/change time
                InkWell(
                  onTap: isEnabled
                      ? () async {
                          final newTime = await showTimePicker(
                            context: context,
                            initialTime: time,
                            helpText: 'تحديد موعد تنبيه $title',
                            cancelText: 'إلغاء',
                            confirmText: 'حفظ الموعد',
                          );
                          if (newTime != null) {
                            onTimeChanged(newTime);
                          }
                        }
                      : () {
                          // If disabled, enable and open time picker
                          onToggle(true);
                        },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isEnabled
                          ? theme.colorScheme.primary.withValues(alpha: 0.12)
                          : theme.dividerColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isEnabled
                            ? theme.colorScheme.primary.withValues(alpha: 0.3)
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.access_time_filled_rounded,
                          size: 15,
                          color: isEnabled ? theme.colorScheme.primary : theme.disabledColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'تحديد الموعد: ${time.format(context)}',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isEnabled ? theme.colorScheme.primary : theme.disabledColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Switch
          Switch(
            value: isEnabled,
            onChanged: onToggle,
            activeColor: theme.colorScheme.primary,
          ),
        ],
      ),
    );
  }
}
