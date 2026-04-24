import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/primary_button.dart';

class PersonalInfoStep extends StatefulWidget {
  final Function(String, String, String, String, String) onContinue;

  const PersonalInfoStep({super.key, required this.onContinue});

  @override
  State<PersonalInfoStep> createState() => _PersonalInfoStepState();
}

class _PersonalInfoStepState extends State<PersonalInfoStep> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _institutionController = TextEditingController();
  final _fieldOfStudyController = TextEditingController();
  
  String _ageRange = '18-22';
  String _academicLevel = 'Undergraduate';

  final List<String> _ageRanges = ['Under 18', '18-22', '23-26', '27-30', '30+'];
  final List<String> _academicLevels = [
    'High School',
    'Undergraduate',
    'Postgraduate',
    'Doctorate',
    'Other'
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _institutionController.dispose();
    _fieldOfStudyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FadeInDown(
              child: Text(
                'Tell us about yourself',
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
                'Help us categorize your productivity metrics.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.lightText,
                    ),
              ),
            ),
            const SizedBox(height: 30),
            FadeInUp(
              delay: const Duration(milliseconds: 200),
              child: CustomTextField(
                controller: _nameController,
                label: 'Full Name',
                hint: 'Enter your name',
                validator: (value) =>
                    value == null || value.isEmpty ? 'Name is required' : null,
              ),
            ),
            const SizedBox(height: 20),
            FadeInUp(
              delay: const Duration(milliseconds: 300),
              child: _buildDropdown(
                label: 'Age Range',
                value: _ageRange,
                items: _ageRanges,
                onChanged: (val) => setState(() => _ageRange = val!),
              ),
            ),
            const SizedBox(height: 20),
            FadeInUp(
              delay: const Duration(milliseconds: 400),
              child: _buildDropdown(
                label: 'Academic Level',
                value: _academicLevel,
                items: _academicLevels,
                onChanged: (val) => setState(() => _academicLevel = val!),
              ),
            ),
            const SizedBox(height: 20),
            FadeInUp(
              delay: const Duration(milliseconds: 500),
              child: CustomTextField(
                controller: _institutionController,
                label: 'University / Institution',
                hint: 'Enter your university (optional)',
              ),
            ),
            const SizedBox(height: 20),
            FadeInUp(
              delay: const Duration(milliseconds: 600),
              child: CustomTextField(
                controller: _fieldOfStudyController,
                label: 'Field of Study',
                hint: 'e.g. Computer Science (optional)',
              ),
            ),
            const SizedBox(height: 40),
            FadeInUp(
              delay: const Duration(milliseconds: 700),
              child: PrimaryButton(
                label: 'Continue',
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    widget.onContinue(
                      _nameController.text,
                      _ageRange,
                      _academicLevel,
                      _institutionController.text,
                      _fieldOfStudyController.text,
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.darkText,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.shadowColor.withValues(alpha: 0.1)),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowColor.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                  color: AppColors.primaryBlue),
              items: items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(item,
                      style: const TextStyle(color: AppColors.darkText)),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
