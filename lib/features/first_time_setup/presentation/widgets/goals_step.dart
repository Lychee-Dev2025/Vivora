import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/primary_button.dart';

class GoalsStep extends StatefulWidget {
  final Function(String, String, String, String, String) onContinue;

  const GoalsStep({super.key, required this.onContinue});

  @override
  State<GoalsStep> createState() => _GoalsStepState();
}

class _GoalsStepState extends State<GoalsStep> {
  double _targetSleep = 8;
  double _targetStudy = 6;
  double _targetFocus = 4;
  String _targetScreenLimit = '3h';
  String _productivityGoal = 'Improve focus';

  final List<String> _screenLimitOptions = ['1h', '2h', '3h', '4h', '5h+'];
  final List<String> _goalTypes = [
    'Improve focus',
    'Reduce distractions',
    'Build better habits',
    'Sleep on time',
    'Be more consistent'
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeInDown(
            child: Text(
              'Set Your Goals',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkText,
                  ),
            ),
          ),
          const SizedBox(height: 10),
          FadeInDown(
            delay: const Duration(milliseconds: 100),
            child: Text(
              'What do you want to achieve with Vivora?',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.lightText,
                  ),
            ),
          ),
          const SizedBox(height: 30),
          FadeInUp(
            delay: const Duration(milliseconds: 200),
            child: _buildSliderLabel('Target Sleep Hours', '${_targetSleep.toInt()}h'),
          ),
          FadeInUp(
            delay: const Duration(milliseconds: 300),
            child: Slider(
              value: _targetSleep,
              min: 4,
              max: 12,
              divisions: 8,
              activeColor: AppColors.primaryBlue,
              onChanged: (val) => setState(() => _targetSleep = val),
            ),
          ),
          const SizedBox(height: 20),
          FadeInUp(
            delay: const Duration(milliseconds: 400),
            child: _buildSliderLabel('Target Study Hours', '${_targetStudy.toInt()}h'),
          ),
          FadeInUp(
            delay: const Duration(milliseconds: 500),
            child: Slider(
              value: _targetStudy,
              min: 1,
              max: 14,
              divisions: 13,
              activeColor: AppColors.softPurple,
              onChanged: (val) => setState(() => _targetStudy = val),
            ),
          ),
          const SizedBox(height: 20),
          FadeInUp(
            delay: const Duration(milliseconds: 600),
            child: _buildSliderLabel('Target Focus Hours', '${_targetFocus.toInt()}h'),
          ),
          FadeInUp(
            delay: const Duration(milliseconds: 700),
            child: Slider(
              value: _targetFocus,
              min: 1,
              max: 10,
              divisions: 9,
              activeColor: AppColors.accentGreen,
              onChanged: (val) => setState(() => _targetFocus = val),
            ),
          ),
          const SizedBox(height: 20),
          FadeInUp(
            delay: const Duration(milliseconds: 800),
            child: _buildSelectionGrid(
              label: 'Daily Screen Time Limit',
              options: _screenLimitOptions,
              selectedOption: _targetScreenLimit,
              onSelected: (val) => setState(() => _targetScreenLimit = val),
            ),
          ),
          const SizedBox(height: 20),
          FadeInUp(
            delay: const Duration(milliseconds: 900),
            child: _buildSelectionGrid(
              label: 'Productivity Goal Type',
              options: _goalTypes,
              selectedOption: _productivityGoal,
              onSelected: (val) => setState(() => _productivityGoal = val),
            ),
          ),
          const SizedBox(height: 40),
          FadeInUp(
            delay: const Duration(milliseconds: 1000),
            child: PrimaryButton(
              label: 'Continue',
              onPressed: () {
                widget.onContinue(
                  '${_targetSleep.toInt()}h',
                  '${_targetStudy.toInt()}h',
                  '${_targetFocus.toInt()}h',
                  _targetScreenLimit,
                  _productivityGoal,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderLabel(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.darkText)),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primaryBlue)),
      ],
    );
  }

  Widget _buildSelectionGrid({
    required String label,
    required List<String> options,
    required String selectedOption,
    required ValueChanged<String> onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.darkText)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: options.map((option) {
            final isSelected = selectedOption == option;
            return InkWell(
              onTap: () => onSelected(option),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: isSelected ? AppColors.buttonGradient : null,
                  color: isSelected ? null : AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: isSelected ? null : Border.all(color: AppColors.shadowColor.withValues(alpha: 0.1)),
                  boxShadow: isSelected ? [
                    BoxShadow(
                      color: AppColors.primaryBlue.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ] : null,
                ),
                child: Text(
                  option,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? AppColors.white : AppColors.darkText,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
