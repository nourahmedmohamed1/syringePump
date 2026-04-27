// lib/ui/screens/infusion_setup_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/drug.dart';
import '../../core/utils/flow_calculator.dart';
import '../../providers/pump_provider.dart';

class InfusionSetupScreen extends StatefulWidget {
  final Drug drug;
  const InfusionSetupScreen({super.key, required this.drug});

  @override
  State<InfusionSetupScreen> createState() => _InfusionSetupScreenState();
}

class _InfusionSetupScreenState extends State<InfusionSetupScreen> {
  final _weightController = TextEditingController();
  final _doseController = TextEditingController();
  final _volumeController = TextEditingController();

  double _calculatedFlowRate = 0;
  bool _doseOutOfRange = false;
  String _doseWarning = '';

  @override
  void dispose() {
    _weightController.dispose();
    _doseController.dispose();
    _volumeController.dispose();
    super.dispose();
  }

  void _recalculate() {
    final weight = double.tryParse(_weightController.text) ?? 0;
    final dose = double.tryParse(_doseController.text) ?? 0;

    if (dose > 0 && (weight > 0 || !widget.drug.isWeightBased)) {
      final rate = FlowCalculator.calculateFlowRate(
        drug: widget.drug,
        dose: dose,
        patientWeight: weight,
      );
      setState(() {
        _calculatedFlowRate = rate;
        _doseOutOfRange = !widget.drug.isDoseSafe(dose);
        _doseWarning = widget.drug.doseSafetyStatus(dose);
      });
    } else {
      setState(() {
        _calculatedFlowRate = 0;
        _doseOutOfRange = false;
        _doseWarning = '';
      });
    }
  }

  void _startInfusion() {
    final weight = double.tryParse(_weightController.text) ?? 0;
    final dose = double.tryParse(_doseController.text) ?? 0;
    final volume = double.tryParse(_volumeController.text) ?? 0;

    if (dose <= 0 || volume <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    if (widget.drug.isWeightBased && weight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Patient weight required for this drug')),
      );
      return;
    }

    if (_doseOutOfRange) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('⚠️ Dose Out of Range'),
          content: Text(
              '$_doseWarning\n\nAre you sure you want to continue with this dose?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _confirmStart(weight, dose, volume);
                },
                child: const Text('Continue Anyway',
                    style: TextStyle(color: AppColors.danger))),
          ],
        ),
      );
    } else {
      _confirmStart(weight, dose, volume);
    }
  }

  void _confirmStart(double weight, double dose, double volume) {
    context.read<PumpProvider>().startInfusion(
          drug: widget.drug,
          patientWeight: weight,
          doseRate: dose,
          syringeVolumeMl: volume,
        );
    Navigator.of(context).pop(); // Go back to dashboard
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Infusion Setup',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        backgroundColor:
            isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Drug info card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.15),
                  AppColors.accent.withValues(alpha: 0.08),
                ],
              ),
              border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.medication,
                          color: AppColors.primary, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.drug.name,
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight,
                            ),
                          ),
                          Text(
                            '${widget.drug.concentration} ${widget.drug.concentrationUnit}',
                            style: GoogleFonts.inter(
                              fontSize: 13,
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
                const SizedBox(height: 12),
                Row(
                  children: [
                    _DetailChip(
                      label: 'Dose Unit',
                      value: widget.drug.dosingUnit,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _DetailChip(
                      label: 'Range',
                      value: '${widget.drug.minDose}–${widget.drug.maxDose}',
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _DetailChip(
                      label: 'Type',
                      value: widget.drug.isWeightBased
                          ? 'Weight-based'
                          : 'Fixed dose',
                      isDark: isDark,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Patient weight (if weight-based)
          if (widget.drug.isWeightBased) ...[
            _InputLabel(
                label: 'Patient Weight (kg)',
                required: true,
                isDark: isDark),
            const SizedBox(height: 8),
            _StyledInput(
              controller: _weightController,
              hint: 'e.g. 70',
              suffix: 'kg',
              isDark: isDark,
              onChanged: (_) => _recalculate(),
            ),
            const SizedBox(height: 20),
          ],

          // Dose rate
          _InputLabel(
            label: 'Dose Rate (${widget.drug.dosingUnit})',
            required: true,
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          _StyledInput(
            controller: _doseController,
            hint: 'e.g. ${widget.drug.minDose}',
            suffix: widget.drug.dosingUnit.split('/').first,
            isDark: isDark,
            onChanged: (_) => _recalculate(),
          ),
          if (_doseOutOfRange) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.danger.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning,
                      color: AppColors.danger, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _doseWarning,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),

          // Syringe volume
          _InputLabel(
            label: 'Syringe Volume (mL)',
            required: true,
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          _StyledInput(
            controller: _volumeController,
            hint: 'e.g. 50',
            suffix: 'mL',
            isDark: isDark,
            onChanged: (_) => _recalculate(),
          ),
          const SizedBox(height: 8),
          // Quick-select volume buttons
          Wrap(
            spacing: 8,
            children: [1, 3, 5, 10, 20, 50].map((vol) {
              return ActionChip(
                label: Text('$vol mL',
                    style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w600)),
                onPressed: () {
                  _volumeController.text = vol.toString();
                  _recalculate();
                },
                backgroundColor: isDark
                    ? AppColors.cardDark
                    : AppColors.cardLight,
                side: BorderSide(
                    color: isDark
                        ? AppColors.dividerDark
                        : AppColors.dividerLight),
              );
            }).toList(),
          ),
          const SizedBox(height: 30),

          // Calculated result
          if (_calculatedFlowRate > 0)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D2137), Color(0xFF0A3A5C)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'CALCULATED FLOW RATE',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.flowColor,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _calculatedFlowRate.toStringAsFixed(2),
                        style: GoogleFonts.inter(
                          fontSize: 46,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -2,
                          height: 1,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6, left: 6),
                        child: Text(
                          'mL/hr',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.flowColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (widget.drug.isWeightBased)
                    Text(
                      'Formula: (${_doseController.text} × ${_weightController.text} ${widget.drug.isPerMinute ? '× 60' : ''}) / ${widget.drug.concentration}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                      textAlign: TextAlign.center,
                    )
                  else
                    Text(
                      'Formula: ${_doseController.text} ${widget.drug.isPerMinute ? '× 60 ' : ''}/ ${widget.drug.concentration}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                      textAlign: TextAlign.center,
                    ),
                ],
              ),
            ),
          const SizedBox(height: 24),

          // Start button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _calculatedFlowRate > 0 ? _startInfusion : null,
              icon: const Icon(Icons.play_arrow, size: 22),
              label: Text(
                'START INFUSION',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800, letterSpacing: 1),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.05),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 4,
                shadowColor: AppColors.primary.withValues(alpha: 0.4),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _InputLabel extends StatelessWidget {
  final String label;
  final bool required;
  final bool isDark;

  const _InputLabel({
    required this.label,
    this.required = false,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
          ),
        ),
        if (required)
          Text(' *',
              style: GoogleFonts.inter(
                  color: AppColors.danger, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _StyledInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String suffix;
  final bool isDark;
  final ValueChanged<String>? onChanged;

  const _StyledInput({
    required this.controller,
    required this.hint,
    required this.suffix,
    required this.isDark,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isDark ? AppColors.dividerDark : AppColors.dividerLight),
      ),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: onChanged,
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: isDark
              ? AppColors.textPrimaryDark
              : AppColors.textPrimaryLight,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
          suffixText: suffix,
          suffixStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;

  const _DetailChip({
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
