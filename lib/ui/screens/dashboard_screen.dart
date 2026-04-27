// lib/ui/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/alarm_event.dart';
import '../../providers/pump_provider.dart';
import '../widgets/alarm_banner.dart';
import '../widgets/flow_gauge.dart';
import '../widgets/heart_rate_wave.dart';
import '../widgets/kids_character.dart';
import '../widgets/syringe_progress.dart';
import '../widgets/system_status_banner.dart';
import '../widgets/vitals_card.dart';
import 'connection_screen.dart';
import 'drug_library_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PumpProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Kids mode full-screen overlay
    if (provider.kidsMode && provider.hasActiveSession) {
      return KidsCharacter(
        progress: provider.session!.progressPercent,
        flowRatio: provider.session!.desiredFlowRate > 0
            ? provider.latestData.flowRate /
                provider.session!.desiredFlowRate
            : 1.0,
        onClose: () => provider.setKidsMode(false),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('EleCare',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800, fontSize: 18)),
            Text('Syringe Pump Monitor',
                style: GoogleFonts.inter(
                    fontSize: 10,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight)),
          ],
        ),
        backgroundColor:
            isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        elevation: 0,
        actions: [
          // BT status chip
          GestureDetector(
            onTap: () {
              if (provider.isConnected) {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Disconnect?'),
                    content: Text(
                        'Disconnect from ${provider.connectedDeviceName}?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel')),
                      TextButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            if (provider.demoMode) {
                              provider.disableDemoMode();
                            } else {
                              await provider.disconnect();
                            }
                            if (mounted) {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const ConnectionScreen()),
                              );
                            }
                          },
                          child: const Text('Disconnect',
                              style: TextStyle(color: AppColors.danger))),
                    ],
                  ),
                );
              }
            },
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: provider.isConnected
                    ? AppColors.safe.withValues(alpha: 0.15)
                    : AppColors.danger.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: provider.isConnected
                        ? AppColors.safe
                        : AppColors.danger,
                    width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    provider.isConnected
                        ? Icons.bluetooth_connected
                        : Icons.bluetooth_disabled,
                    size: 14,
                    color: provider.isConnected
                        ? AppColors.safe
                        : AppColors.danger,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    provider.isConnected
                        ? provider.connectedDeviceName
                        : 'Disconnected',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: provider.isConnected
                            ? AppColors.safe
                            : AppColors.danger),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      drawer: _AppDrawer(isDark: isDark, provider: provider),
      body: const _DashboardBody(),
    );
  }
}

// ─── Side Navigation Drawer ──────────────────────────────────────────────────

class _AppDrawer extends StatelessWidget {
  final bool isDark;
  final PumpProvider provider;

  const _AppDrawer({required this.isDark, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      child: SafeArea(
        child: Column(
          children: [
            // Drawer header with branding
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.15),
                    AppColors.accent.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Elephant icon circle
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: 0.3),
                          AppColors.elephantBody.withValues(alpha: 0.3),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text('🐘', style: TextStyle(fontSize: 28)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'EleCare',
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Smart Syringe Pump Monitor',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // BT Status in drawer
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: provider.isConnected
                          ? AppColors.safe.withValues(alpha: 0.12)
                          : AppColors.danger.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          provider.isConnected
                              ? Icons.bluetooth_connected
                              : Icons.bluetooth_disabled,
                          size: 12,
                          color: provider.isConnected
                              ? AppColors.safe
                              : AppColors.danger,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          provider.isConnected
                              ? provider.connectedDeviceName
                              : 'Disconnected',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: provider.isConnected
                                ? AppColors.safe
                                : AppColors.danger,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Navigation items
            _DrawerItem(
              icon: Icons.dashboard_rounded,
              label: 'Dashboard',
              isActive: true,
              isDark: isDark,
              onTap: () => Navigator.pop(context),
            ),
            _DrawerItem(
              icon: Icons.medication_rounded,
              label: 'Drug Calculator',
              isDark: isDark,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const DrugLibraryScreen()),
                );
              },
            ),
            _DrawerItem(
              icon: Icons.bar_chart_rounded,
              label: 'History',
              isDark: isDark,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const HistoryScreen()),
                );
              },
            ),
            _DrawerItem(
              icon: Icons.settings_rounded,
              label: 'Settings',
              isDark: isDark,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const SettingsScreen()),
                );
              },
            ),

            const Spacer(),

            // Disconnect button at bottom
            if (provider.isConnected)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      if (provider.demoMode) {
                        provider.disableDemoMode();
                      } else {
                        await provider.disconnect();
                      }
                      if (context.mounted) {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                              builder: (_) => const ConnectionScreen()),
                        );
                      }
                    },
                    icon:
                        const Icon(Icons.power_settings_new, size: 18),
                    label: const Text('Disconnect'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.danger),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            // Version
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'EleCare v1.0.0',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final bool isDark;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    this.isActive = false,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.primary.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 20,
            color: isActive
                ? AppColors.primary
                : (isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight),
          ),
        ),
        title: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: isActive
                ? AppColors.primary
                : (isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight),
          ),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: isActive
            ? AppColors.primary.withValues(alpha: 0.06)
            : Colors.transparent,
      ),
    );
  }
}

// ─── Dashboard Body ────────────────────────────────────────────────────────

class _DashboardBody extends StatelessWidget {
  const _DashboardBody();

  Color _statusColor(bool isAlarm, bool isCritical) {
    if (!isAlarm) return AppColors.safe;
    return isCritical ? AppColors.danger : AppColors.warning;
  }

  String _statusText(bool isAlarm, bool isCritical) {
    if (!isAlarm) return 'NORMAL';
    return isCritical ? 'CRITICAL' : 'WARNING';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PumpProvider>();
    final d = provider.latestData;
    final alarms = provider.alarms;
    final session = provider.session;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    bool paramHasAlarm(AlarmParameter p) =>
        alarms.any((a) => a.parameter == p);
    bool paramIsCritical(AlarmParameter p) =>
        alarms.any((a) => a.parameter == p && a.isCritical);

    // FSR status
    final fsrAlarm = paramHasAlarm(AlarmParameter.occlusion);
    final fsrCritical = paramIsCritical(AlarmParameter.occlusion);
    final fsrWarning = fsrAlarm && !fsrCritical;

    // IR status
    final irAlarm = d.irBlocked;

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        // Alarm banner
        AlarmBanner(alarms: alarms),
        const SizedBox(height: 8),

        // No session banner
        if (!provider.hasActiveSession)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.15),
                  AppColors.accent.withValues(alpha: 0.1),
                ],
              ),
              border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No Active Infusion',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                      Text(
                        'Open the menu and go to Drug Calculator to set up',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 8),

        // ── System Status Banner (replaces FSR + IR raw data) ──
        SystemStatusBanner(
          fsrWarning: fsrWarning,
          fsrCritical: fsrCritical,
          irBlocked: irAlarm,
          hasAnyAlarm: fsrAlarm || irAlarm,
        ),

        const SizedBox(height: 12),

        // ── Vitals grid (Flow Rate + Heart Rate ONLY — kept as-is) ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.9,
            children: [
              VitalsCard(
                label: 'Flow Rate',
                value: d.flowRate.toStringAsFixed(1),
                unit: 'mL/hr',
                icon: Icons.water_drop,
                color: AppColors.flowColor,
                statusColor: _statusColor(
                    paramHasAlarm(AlarmParameter.flowDeviation),
                    paramIsCritical(AlarmParameter.flowDeviation)),
                statusText: _statusText(
                    paramHasAlarm(AlarmParameter.flowDeviation),
                    paramIsCritical(AlarmParameter.flowDeviation)),
                isAlarming: paramHasAlarm(AlarmParameter.flowDeviation),
              ),
              VitalsCard(
                label: 'Heart Rate',
                value: d.heartRate.toStringAsFixed(0),
                unit: 'BPM',
                icon: Icons.favorite,
                color: AppColors.heartColor,
                statusColor: _statusColor(
                    paramHasAlarm(AlarmParameter.heartRateHigh) ||
                        paramHasAlarm(AlarmParameter.heartRateLow),
                    paramIsCritical(AlarmParameter.heartRateHigh) ||
                        paramIsCritical(AlarmParameter.heartRateLow)),
                statusText: _statusText(
                    paramHasAlarm(AlarmParameter.heartRateHigh) ||
                        paramHasAlarm(AlarmParameter.heartRateLow),
                    paramIsCritical(AlarmParameter.heartRateHigh) ||
                        paramIsCritical(AlarmParameter.heartRateLow)),
                isAlarming: paramHasAlarm(AlarmParameter.heartRateHigh) ||
                    paramHasAlarm(AlarmParameter.heartRateLow),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Syringe progress (if infusion active)
        if (session != null) ...[
          SyringeProgress(
            progress: session.progressPercent,
            volumeDelivered: session.volumeDelivered,
            totalVolume: session.syringeVolumeMl,
            timeRemaining: session.timeRemainingFormatted,
            elapsed: session.elapsedFormatted,
            flowRate: d.flowRate,
          ),
          const SizedBox(height: 16),
          // Flow comparison
          FlowGauge(
            actualFlow: d.flowRate,
            desiredFlow: session.desiredFlowRate,
            flowHistory: provider.flowHistory,
          ),
          const SizedBox(height: 12),
          // Kids mode + Stop buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => provider.toggleKidsMode(),
                    icon: const Text('🐘', style: TextStyle(fontSize: 16)),
                    label: const Text('Kids Mode'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.kidsBackground,
                      foregroundColor: AppColors.kidsPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Stop Infusion?'),
                          content: Text(
                              'Stop ${session.drug.name} infusion? ${session.volumeDelivered.toStringAsFixed(1)} mL delivered so far.'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel')),
                            TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  provider.stopInfusion();
                                },
                                child: const Text('Stop',
                                    style:
                                        TextStyle(color: AppColors.danger))),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(Icons.stop_circle, size: 18),
                    label: const Text('Stop Infusion'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 16),

        // Heart rate waveform
        HeartRateWave(
          buffer: provider.hrHistory,
          currentHR: d.heartRate,
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
