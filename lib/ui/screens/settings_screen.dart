// lib/ui/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/thresholds.dart';
import '../../providers/pump_provider.dart';
import 'hr_scan_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PumpProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Settings',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        backgroundColor:
            isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),
          // Appearance section
          _SectionTitle(title: 'Appearance', isDark: isDark),
          const SizedBox(height: 8),
          _SettingsCard(
            isDark: isDark,
            children: [
              _ToggleTile(
                icon: Icons.dark_mode,
                title: 'Dark Mode',
                subtitle: 'Use dark theme',
                value: provider.isDarkMode,
                onChanged: (v) => provider.setDarkMode(v),
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Alerts section
          _SectionTitle(title: 'Alerts & Sound', isDark: isDark),
          const SizedBox(height: 8),
          _SettingsCard(
            isDark: isDark,
            children: [
              _ToggleTile(
                icon: Icons.volume_up,
                title: 'Alarm Sound',
                subtitle: 'Play audio for alerts',
                value: provider.soundEnabled,
                onChanged: (v) => provider.setSoundEnabled(v),
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 20),



          // ── Heart Rate Monitoring (NEW) ──
          _SectionTitle(title: 'Heart Rate Monitoring', isDark: isDark),
          const SizedBox(height: 4),
          Text(
            'Fingerprint-based heart rate check settings',
            style: GoogleFonts.outfit(
              fontSize: 11,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 8),
          _SettingsCard(
            isDark: isDark,
            children: [
              // HR Check Interval dropdown
              _HrIntervalTile(
                isDark: isDark,
                currentInterval: provider.hrCheckInterval,
                onChanged: (duration) {
                  provider.setHrCheckInterval(duration);
                },
              ),
              Divider(
                  color:
                      isDark ? AppColors.dividerDark : AppColors.dividerLight,
                  height: 1),
              // Manual scan button
              ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.heartColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.fingerprint,
                      color: AppColors.heartColor, size: 20),
                ),
                title: Text(
                  'Scan Now',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                subtitle: Text(
                  'Take a manual fingerprint heart rate reading',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
                trailing: Icon(Icons.arrow_forward_ios,
                    size: 14,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const HrScanScreen(isInterruption: false),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Pressure Thresholds ──
          _SectionTitle(title: 'Pressure Thresholds (FSR)', isDark: isDark),
          const SizedBox(height: 4),
          Text(
            'Adjust when pressure alarms trigger',
            style: GoogleFonts.outfit(
              fontSize: 11,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 8),
          _SettingsCard(
            isDark: isDark,
            children: [
              _ThresholdTile(
                icon: Icons.compress,
                title: 'Warning Level',
                value: Thresholds.fsrOcclusionWarning,
                min: 400,
                max: 900,
                unit: '',
                color: AppColors.warning,
                onChanged: (v) {
                  setState(() => Thresholds.fsrOcclusionWarning = v);
                  Thresholds.saveToPrefs();
                },
                isDark: isDark,
              ),
              Divider(
                  color:
                      isDark ? AppColors.dividerDark : AppColors.dividerLight,
                  height: 1),
              _ThresholdTile(
                icon: Icons.compress,
                title: 'Critical Level',
                value: Thresholds.fsrOcclusionCritical,
                min: 500,
                max: 1023,
                unit: '',
                color: AppColors.danger,
                onChanged: (v) {
                  setState(() => Thresholds.fsrOcclusionCritical = v);
                  Thresholds.saveToPrefs();
                },
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Heart Rate Thresholds ──
          _SectionTitle(title: 'Heart Rate Thresholds', isDark: isDark),
          const SizedBox(height: 4),
          Text(
            'Set safe BPM range for patient monitoring',
            style: GoogleFonts.outfit(
              fontSize: 11,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 8),
          _SettingsCard(
            isDark: isDark,
            children: [
              _ThresholdTile(
                icon: Icons.favorite,
                title: 'Low Warning',
                value: Thresholds.hrMin,
                min: 20,
                max: 80,
                unit: 'BPM',
                color: AppColors.warning,
                onChanged: (v) {
                  setState(() => Thresholds.hrMin = v);
                  Thresholds.saveToPrefs();
                },
                isDark: isDark,
              ),
              Divider(
                  color:
                      isDark ? AppColors.dividerDark : AppColors.dividerLight,
                  height: 1),
              _ThresholdTile(
                icon: Icons.favorite,
                title: 'Low Critical',
                value: Thresholds.hrCriticalMin,
                min: 10,
                max: 50,
                unit: 'BPM',
                color: AppColors.danger,
                onChanged: (v) {
                  setState(() => Thresholds.hrCriticalMin = v);
                  Thresholds.saveToPrefs();
                },
                isDark: isDark,
              ),
              Divider(
                  color:
                      isDark ? AppColors.dividerDark : AppColors.dividerLight,
                  height: 1),
              _ThresholdTile(
                icon: Icons.favorite,
                title: 'High Warning',
                value: Thresholds.hrMax,
                min: 100,
                max: 250,
                unit: 'BPM',
                color: AppColors.warning,
                onChanged: (v) {
                  setState(() => Thresholds.hrMax = v);
                  Thresholds.saveToPrefs();
                },
                isDark: isDark,
              ),
              Divider(
                  color:
                      isDark ? AppColors.dividerDark : AppColors.dividerLight,
                  height: 1),
              _ThresholdTile(
                icon: Icons.favorite,
                title: 'High Critical',
                value: Thresholds.hrCriticalMax,
                min: 150,
                max: 300,
                unit: 'BPM',
                color: AppColors.danger,
                onChanged: (v) {
                  setState(() => Thresholds.hrCriticalMax = v);
                  Thresholds.saveToPrefs();
                },
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Safe Heart Rate Range (NEW) ──
          _SectionTitle(title: 'Safe Heart Rate Range', isDark: isDark),
          const SizedBox(height: 4),
          Text(
            'Fingerprint HR readings outside this range trigger an alarm and pause the syringe',
            style: GoogleFonts.outfit(
              fontSize: 11,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 8),
          _SettingsCard(
            isDark: isDark,
            children: [
              _ThresholdTile(
                icon: Icons.favorite,
                title: 'Min Safe BPM',
                value: Thresholds.safeHrMin,
                min: 20,
                max: 100,
                unit: 'BPM',
                color: AppColors.safe,
                onChanged: (v) {
                  setState(() => Thresholds.safeHrMin = v);
                  Thresholds.saveToPrefs();
                },
                isDark: isDark,
              ),
              Divider(
                  color:
                      isDark ? AppColors.dividerDark : AppColors.dividerLight,
                  height: 1),
              _ThresholdTile(
                icon: Icons.favorite,
                title: 'Max Safe BPM',
                value: Thresholds.safeHrMax,
                min: 80,
                max: 200,
                unit: 'BPM',
                color: AppColors.safe,
                onChanged: (v) {
                  setState(() => Thresholds.safeHrMax = v);
                  Thresholds.saveToPrefs();
                },
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Flow Deviation Thresholds ──
          _SectionTitle(title: 'Flow Deviation Thresholds', isDark: isDark),
          const SizedBox(height: 4),
          Text(
            'Percentage deviation from target flow rate',
            style: GoogleFonts.outfit(
              fontSize: 11,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 8),
          _SettingsCard(
            isDark: isDark,
            children: [
              _ThresholdTile(
                icon: Icons.compare_arrows,
                title: 'Warning Deviation',
                value: Thresholds.flowDeviationWarning,
                min: 5,
                max: 50,
                unit: '%',
                color: AppColors.warning,
                onChanged: (v) {
                  setState(() => Thresholds.flowDeviationWarning = v);
                  Thresholds.saveToPrefs();
                },
                isDark: isDark,
              ),
              Divider(
                  color:
                      isDark ? AppColors.dividerDark : AppColors.dividerLight,
                  height: 1),
              _ThresholdTile(
                icon: Icons.compare_arrows,
                title: 'Critical Deviation',
                value: Thresholds.flowDeviationCritical,
                min: 20,
                max: 80,
                unit: '%',
                color: AppColors.danger,
                onChanged: (v) {
                  setState(() => Thresholds.flowDeviationCritical = v);
                  Thresholds.saveToPrefs();
                },
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Reset button
          Center(
            child: TextButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Reset Thresholds?'),
                    content: const Text(
                        'This will reset all alarm thresholds to their factory default values.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          setState(() {
                            Thresholds.resetToDefaults();
                            Thresholds.saveToPrefs();
                          });
                        },
                        child: const Text('Reset',
                            style: TextStyle(color: AppColors.danger)),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.restart_alt, size: 16),
              label: Text(
                'Reset All Thresholds to Defaults',
                style: GoogleFonts.outfit(fontSize: 12),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // About section
          _SectionTitle(title: 'About', isDark: isDark),
          const SizedBox(height: 8),
          _SettingsCard(
            isDark: isDark,
            children: [
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.2),
                        AppColors.elephantBody.withValues(alpha: 0.2),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text('🐘', style: TextStyle(fontSize: 20)),
                  ),
                ),
                title: Text(
                  'EleCare v1.0.0',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                subtitle: Text(
                  'Smart Syringe Pump Monitor',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─── HR Interval Dropdown Tile ───────────────────────────────────────────────

class _HrIntervalTile extends StatelessWidget {
  final bool isDark;
  final Duration currentInterval;
  final ValueChanged<Duration> onChanged;

  const _HrIntervalTile({
    required this.isDark,
    required this.currentInterval,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.heartColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.timer_outlined,
                color: AppColors.heartColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HR Check Interval',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                Text(
                  'How often to scan heart rate',
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.heartColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.heartColor.withValues(alpha: 0.2),
              ),
            ),
            child: DropdownButton<Duration>(
              value: currentInterval,
              underline: const SizedBox(),
              isDense: true,
              dropdownColor: isDark ? AppColors.cardDark : AppColors.cardLight,
              borderRadius: BorderRadius.circular(12),
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.heartColor,
              ),
              icon: Icon(Icons.expand_more,
                  size: 18, color: AppColors.heartColor),
              items: PumpProvider.hrIntervalOptions.map((duration) {
                return DropdownMenuItem<Duration>(
                  value: duration,
                  child: Text(PumpProvider.formatInterval(duration)),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) onChanged(value);
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared Setting Widgets ──────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  final bool isDark;

  const _SectionTitle({required this.title, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: isDark
            ? AppColors.textSecondaryDark
            : AppColors.textSecondaryLight,
        letterSpacing: 1,
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final bool isDark;
  final List<Widget> children;

  const _SettingsCard({required this.isDark, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? AppColors.dividerDark : AppColors.dividerLight),
      ),
      child: Column(children: children),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isDark;

  const _ToggleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: isDark
              ? AppColors.textPrimaryDark
              : AppColors.textPrimaryLight,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.inter(
          fontSize: 11,
          color: isDark
              ? AppColors.textSecondaryDark
              : AppColors.textSecondaryLight,
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeThumbColor: AppColors.primary,
    );
  }
}

class _ThresholdTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final double value;
  final double min;
  final double max;
  final String unit;
  final Color color;
  final ValueChanged<double> onChanged;
  final bool isDark;

  const _ThresholdTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    required this.color,
    required this.onChanged,
    required this.isDark,
  });

  @override
  State<_ThresholdTile> createState() => _ThresholdTileState();
}

class _ThresholdTileState extends State<_ThresholdTile> {
  late double _val;

  @override
  void initState() {
    super.initState();
    _val = widget.value;
  }

  @override
  void didUpdateWidget(_ThresholdTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _val = widget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(widget.icon, size: 14, color: widget.color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: widget.isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${_val.toStringAsFixed(0)} ${widget.unit}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: widget.color,
                  ),
                ),
              ),
            ],
          ),
          Slider(
            value: _val,
            min: widget.min,
            max: widget.max,
            divisions: (widget.max - widget.min).round(),
            activeColor: widget.color,
            onChanged: (v) {
              setState(() => _val = v);
              widget.onChanged(v);
            },
          ),
        ],
      ),
    );
  }
}

