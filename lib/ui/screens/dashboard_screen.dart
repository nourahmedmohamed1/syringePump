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
import 'hr_scan_screen.dart';
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

    // Kids mode full-screen overlay — accessible even before infusion starts
    if (provider.kidsMode) {
      return KidsCharacter(
        progress: provider.hasActiveSession
            ? provider.session!.progressPercent
            : 0.0,
        isIdle: !provider.hasActiveSession,
        flowRatio: (provider.hasActiveSession &&
                provider.session!.desiredFlowRate > 0)
            ? provider.latestData.flowRate /
                provider.session!.desiredFlowRate
            : 1.0,
        onClose: () => provider.setKidsMode(false),
        hrReadings: provider.hrReadings,
        latestBpm: provider.latestData.heartRate,
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

        // ── System Status Banner (FSR pressure/occlusion only — IR handled by hardware alarm string) ──
        SystemStatusBanner(
          fsrWarning: fsrWarning,
          fsrCritical: fsrCritical,
          irBlocked: provider.fluidEmptyAlarmActive,
          hasAnyAlarm: fsrAlarm || provider.fluidEmptyAlarmActive,
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
              // Heart Rate — shows camera PPG reading when available
              provider.hrReadings.isNotEmpty
                  ? _buildCameraHrCard(provider, isDark)
                  : VitalsCard(
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

        const SizedBox(height: 16),

        // ── Kids Mode Button (Always visible) ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
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
              minimumSize: const Size.fromHeight(50),
            ),
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
          // Stop Infusion Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
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
                minimumSize: const Size.fromHeight(50),
              ),
            ),
          ),
        ],

        const SizedBox(height: 16),

        // ── Manual Motor Control Card ──────────────────────────────────────
        _MotorControlCard(
          isConnected: provider.isConnected || provider.demoMode,
          isDemo: provider.demoMode,
          onForward: () => provider.sendMotorForward(),
          onBackward: () => provider.sendMotorBackward(),
          onStop: () => provider.sendStopCommand(),
          isDark: isDark,
        ),
        const SizedBox(height: 12),

        // ── Quick Flowrate Card ────────────────────────────────────────────
        _QuickFlowrateCard(
          isConnected: provider.isConnected || provider.demoMode,
          isDemo: provider.demoMode,
          onSetRate: (v) => provider.sendSetRate(v),
          onStartInfusion: (v) => provider.sendStartInfusionVolume(v),
          isDark: isDark,
        ),
        const SizedBox(height: 16),


        HeartRateWave(
          buffer: provider.hrHistory,
          currentHR: d.heartRate,
          hrReadings: provider.hrReadings,
        ),
        const SizedBox(height: 12),

        // Manual HR Scan button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const HrScanScreen(isInterruption: false),
                  ),
                );
              },
              icon: Icon(Icons.fingerprint, size: 18, color: AppColors.heartColor),
              label: Text(
                'Scan Heart Rate',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: AppColors.heartColor,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.heartColor.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  /// Camera-measured HR card that replaces the generic VitalsCard
  /// when PPG readings are available.
  Widget _buildCameraHrCard(PumpProvider provider, bool isDark) {
    final reading = provider.hrReadings.last;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.heartColor.withValues(alpha: 0.15),
            AppColors.heartColor.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.heartColor.withValues(alpha: 0.3),
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.favorite, color: AppColors.heartColor, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Heart Rate',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.heartColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '👆',
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ],
          ),
          const Spacer(),
          Center(
            child: Text(
              reading.bpm.toStringAsFixed(0),
              style: GoogleFonts.outfit(
                fontSize: 42,
                fontWeight: FontWeight.w900,
                color: AppColors.heartColor,
                letterSpacing: -2,
                height: 1.0,
              ),
            ),
          ),
          Center(
            child: Text(
              'BPM',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.heartColor.withValues(alpha: 0.7),
              ),
            ),
          ),
          const Spacer(),
          // Timestamp
          Center(
            child: Text(
              _formatTimeAgo(reading.timestamp),
              style: GoogleFonts.inter(
                fontSize: 10,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ─── Motor Control Card ───────────────────────────────────────────────────────

class _MotorControlCard extends StatelessWidget {
  final bool isConnected;
  final bool isDemo;
  final VoidCallback onForward;
  final VoidCallback onBackward;
  final VoidCallback onStop;
  final bool isDark;

  const _MotorControlCard({
    required this.isConnected,
    required this.isDemo,
    required this.onForward,
    required this.onBackward,
    required this.onStop,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : AppColors.cardLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
          ),
          boxShadow: isDark
              ? []
              : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.tune_rounded,
                      color: AppColors.primary, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Manual Motor Control',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                      Text(
                        isConnected
                            ? (isDemo ? 'Demo Mode (Simulated)' : 'Sends f / b / s to Arduino')
                            : 'Connect via Bluetooth to use',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isConnected)
                  const Icon(Icons.lock_outline,
                      size: 16, color: AppColors.warning),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _motorBtn(
                    label: 'Forward',
                    icon: Icons.arrow_forward_rounded,
                    color: AppColors.safe,
                    onTap: isConnected ? onForward : null,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _motorBtn(
                    label: 'Backward',
                    icon: Icons.arrow_back_rounded,
                    color: AppColors.flowColor,
                    onTap: isConnected ? onBackward : null,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _motorBtn(
                    label: 'Stop',
                    icon: Icons.stop_rounded,
                    color: AppColors.danger,
                    onTap: isConnected ? onStop : null,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _motorBtn({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
    required bool isDark,
  }) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: disabled
              ? null
              : LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.18),
                    color.withValues(alpha: 0.08),
                  ],
                ),
          color: disabled
              ? (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.04))
              : null,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: disabled
                ? (isDark ? Colors.white12 : Colors.black12)
                : color.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 22,
                color: disabled ? Colors.grey.withValues(alpha: 0.4) : color),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: disabled ? Colors.grey.withValues(alpha: 0.5) : color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Quick Flowrate Card ──────────────────────────────────────────────────────

class _QuickFlowrateCard extends StatefulWidget {
  final bool isConnected;
  final bool isDemo;
  final void Function(double) onSetRate;
  final void Function(double) onStartInfusion;
  final bool isDark;

  const _QuickFlowrateCard({
    required this.isConnected,
    required this.isDemo,
    required this.onSetRate,
    required this.onStartInfusion,
    required this.isDark,
  });

  @override
  State<_QuickFlowrateCard> createState() => _QuickFlowrateCardState();
}

class _QuickFlowrateCardState extends State<_QuickFlowrateCard> {
  final _rateController = TextEditingController();
  final _volumeController = TextEditingController();
  String? _rateError;
  String? _volumeError;
  String? _rateSuccess;
  String? _volumeSuccess;

  @override
  void dispose() {
    _rateController.dispose();
    _volumeController.dispose();
    super.dispose();
  }

  void _handleSetRate() {
    final val = double.tryParse(_rateController.text.trim());
    if (val == null || val <= 0) {
      setState(() {
        _rateError = 'Enter a valid positive number';
        _rateSuccess = null;
      });
      return;
    }
    widget.onSetRate(val);
    setState(() {
      _rateError = null;
      _rateSuccess = 'Sent: R $val';
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _rateSuccess = null);
    });
  }

  void _handleStartInfusion() {
    final val = double.tryParse(_volumeController.text.trim());
    if (val == null || val <= 0) {
      setState(() {
        _volumeError = 'Enter a valid positive number';
        _volumeSuccess = null;
      });
      return;
    }
    widget.onStartInfusion(val);
    setState(() {
      _volumeError = null;
      _volumeSuccess = 'Sent: I $val';
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _volumeSuccess = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: widget.isDark ? AppColors.cardDark : AppColors.cardLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: widget.isDark ? AppColors.dividerDark : AppColors.dividerLight,
          ),
          boxShadow: widget.isDark
              ? []
              : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.flowColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.water_drop_rounded,
                      color: AppColors.flowColor, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quick Flowrate',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: widget.isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                      Text(
                        widget.isConnected
                            ? (widget.isDemo ? 'Demo Mode (Simulated)' : 'Sends R (rate) or I (volume) to Arduino')
                            : 'Connect via Bluetooth to use',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: widget.isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!widget.isConnected)
                  const Icon(Icons.lock_outline,
                      size: 16, color: AppColors.warning),
              ],
            ),
            const SizedBox(height: 14),

            // ── Row 1: Set Rate ──
            _inputRow(
              controller: _rateController,
              label: 'Desired Flow Rate',
              unit: 'mL/hr',
              hint: 'e.g. 12.5',
              buttonLabel: 'Set Rate',
              buttonColor: AppColors.flowColor,
              icon: Icons.speed_rounded,
              error: _rateError,
              success: _rateSuccess,
              onPressed: widget.isConnected ? _handleSetRate : null,
            ),

            const SizedBox(height: 12),

            // ── Row 2: Infusion Volume ──
            _inputRow(
              controller: _volumeController,
              label: 'Infusion Volume',
              unit: 'mL',
              hint: 'e.g. 50',
              buttonLabel: 'Start',
              buttonColor: AppColors.safe,
              icon: Icons.science_rounded,
              error: _volumeError,
              success: _volumeSuccess,
              onPressed: widget.isConnected ? _handleStartInfusion : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _inputRow({
    required TextEditingController controller,
    required String label,
    required String unit,
    required String hint,
    required String buttonLabel,
    required Color buttonColor,
    required IconData icon,
    required String? error,
    required String? success,
    required VoidCallback? onPressed,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: widget.isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                enabled: onPressed != null,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: widget.isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: GoogleFonts.inter(
                    fontSize: 13,
                    color: widget.isDark ? Colors.white24 : Colors.black26,
                  ),
                  suffixText: unit,
                  suffixStyle: GoogleFonts.inter(
                    fontSize: 12,
                    color: widget.isDark ? Colors.white38 : Colors.black38,
                  ),
                  prefixIcon:
                      Icon(icon, size: 18, color: buttonColor.withValues(alpha: 0.7)),
                  filled: true,
                  fillColor: onPressed != null
                      ? (widget.isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.03))
                      : (widget.isDark
                          ? Colors.white.withValues(alpha: 0.02)
                          : Colors.black.withValues(alpha: 0.02)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: widget.isDark
                          ? AppColors.dividerDark
                          : AppColors.dividerLight,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: widget.isDark
                          ? AppColors.dividerDark
                          : AppColors.dividerLight,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: buttonColor, width: 1.5),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: widget.isDark ? Colors.white12 : Colors.black12,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 46,
              child: ElevatedButton(
                onPressed: onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: onPressed != null
                      ? buttonColor
                      : Colors.grey.withValues(alpha: 0.3),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Text(
                  buttonLabel,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(
              error,
              style: GoogleFonts.inter(
                  fontSize: 10, color: AppColors.danger),
            ),
          ),
        if (success != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline,
                    size: 12, color: AppColors.safe),
                const SizedBox(width: 4),
                Text(
                  success,
                  style: GoogleFonts.inter(
                      fontSize: 10, color: AppColors.safe),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
