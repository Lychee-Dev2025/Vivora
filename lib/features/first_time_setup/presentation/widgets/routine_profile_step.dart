import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:vivora/core/theme/vivora_palette.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/primary_button.dart';

class RoutineProfileStep extends StatefulWidget {
  final Function(String, String, String, String, String, String) onContinue;

  const RoutineProfileStep({super.key, required this.onContinue});

  @override
  State<RoutineProfileStep> createState() => _RoutineProfileStepState();
}

class _RoutineProfileStepState extends State<RoutineProfileStep> {
  TimeOfDay _wakeUpTime = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay _sleepTime = const TimeOfDay(hour: 23, minute: 0);
  double _studyHours = 4;
  String _preferredStudyTime = 'Morning';
  String _currentScreenTime = '5h';
  String _mainChallenge = 'Procrastination';

  final List<String> _studyTimeOptions = [
    'Morning',
    'Afternoon',
    'Evening',
    'Late Night',
  ];
  final List<String> _screenTimeOptions = [
    '1-2h',
    '3-4h',
    '5-6h',
    '7-8h',
    '9h+',
  ];
  final List<String> _challenges = [
    'Procrastination',
    'Excessive screen time',
    'Poor sleep',
    'Lack of consistency',
    'Low focus',
    'Time management',
  ];

  Future<void> _selectTime(BuildContext context, bool isWakeUp) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isWakeUp ? _wakeUpTime : _sleepTime,
    );
    if (picked != null) {
      setState(() {
        if (isWakeUp) {
          _wakeUpTime = picked;
        } else {
          _sleepTime = picked;
        }
      });
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeInDown(
            child: Text(
              'Your Daily Routine',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: context.palette.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 10),
          FadeInDown(
            delay: const Duration(milliseconds: 100),
            child: Text(
              'Let’s understand your current habits.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 30),
          FadeInUp(
            delay: const Duration(milliseconds: 200),
            child: Row(
              children: [
                Expanded(
                  child: _buildTimeCard(
                    label: 'Wake up',
                    time: _formatTime(_wakeUpTime),
                    icon: Icons.wb_sunny_rounded,
                    onTap: () => _selectTime(context, true),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTimeCard(
                    label: 'Sleep at',
                    time: _formatTime(_sleepTime),
                    icon: Icons.nightlight_round,
                    onTap: () => _selectTime(context, false),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          FadeInUp(
            delay: const Duration(milliseconds: 300),
            child: _buildSliderLabel(
              'Avg Study Hours',
              '${_studyHours.toInt()}h',
            ),
          ),
          FadeInUp(
            delay: const Duration(milliseconds: 400),
            child: Slider(
              value: _studyHours,
              min: 1,
              max: 12,
              divisions: 11,
              activeColor: context.brand,
              inactiveColor: context.brand.withValues(alpha: 0.1),
              onChanged: (val) => setState(() => _studyHours = val),
            ),
          ),
          const SizedBox(height: 20),
          FadeInUp(
            delay: const Duration(milliseconds: 500),
            child: _buildSelectionGrid(
              label: 'Preferred Study Time',
              options: _studyTimeOptions,
              selectedOption: _preferredStudyTime,
              onSelected: (val) => setState(() => _preferredStudyTime = val),
            ),
          ),
          const SizedBox(height: 20),
          FadeInUp(
            delay: const Duration(milliseconds: 600),
            child: _buildSelectionGrid(
              label: 'Current Screen Time',
              options: _screenTimeOptions,
              selectedOption: _currentScreenTime,
              onSelected: (val) => setState(() => _currentScreenTime = val),
            ),
          ),
          const SizedBox(height: 20),
          FadeInUp(
            delay: const Duration(milliseconds: 700),
            child: _buildSelectionGrid(
              label: 'Main Daily Challenge',
              options: _challenges,
              selectedOption: _mainChallenge,
              onSelected: (val) => setState(() => _mainChallenge = val),
              crossAxisCount: 2,
            ),
          ),
          const SizedBox(height: 40),
          FadeInUp(
            delay: const Duration(milliseconds: 800),
            child: PrimaryButton(
              label: 'Continue',
              onPressed: () {
                widget.onContinue(
                  _formatTime(_wakeUpTime),
                  _formatTime(_sleepTime),
                  '${_studyHours.toInt()}h',
                  _preferredStudyTime,
                  _currentScreenTime,
                  _mainChallenge,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeCard({
    required String label,
    required String time,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.palette.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: context.palette.shadow.withValues(alpha: 0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: context.palette.shadow.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: context.brand, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: context.palette.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: context.palette.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderLabel(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: context.palette.textPrimary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: context.brand,
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionGrid({
    required String label,
    required List<String> options,
    required String selectedOption,
    required ValueChanged<String> onSelected,
    int crossAxisCount = 2,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: context.palette.textPrimary,
          ),
        ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: isSelected ? AppColors.buttonGradient : null,
                  color: isSelected ? null : context.palette.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: isSelected
                      ? null
                      : Border.all(
                          color: context.palette.shadow.withValues(alpha: 0.1),
                        ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: context.brand.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  option,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? AppColors.white
                        : context.palette.textPrimary,
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
