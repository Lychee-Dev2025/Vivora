import 'package:animate_do/animate_do.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../core/widgets/primary_button.dart';
import '../../first_time_setup/data/models/user_profile_model.dart';
import '../../first_time_setup/data/services/user_profile_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _profileService = UserProfileService();
  final _auth = FirebaseAuth.instance;

  final _nameController = TextEditingController();
  final _institutionController = TextEditingController();
  final _fieldOfStudyController = TextEditingController();
  
  String _ageRange = '18-22';
  String _academicLevel = 'Undergraduate';
  bool _isLoading = true;
  bool _isSaving = false;
  UserProfile? _currentProfile;

  final List<String> _ageRanges = ['Under 18', '18-22', '23-26', '27-30', '30+'];
  final List<String> _academicLevels = [
    'High School',
    'Undergraduate',
    'Postgraduate',
    'Doctorate',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = _auth.currentUser;
    if (user != null) {
      final profile = await _profileService.getUserProfile(user.uid);
      if (profile != null && mounted) {
        setState(() {
          _currentProfile = profile;
          _nameController.text = profile.fullName;
          _institutionController.text = profile.institution;
          _fieldOfStudyController.text = profile.fieldOfStudy;
          _ageRange = profile.ageRange.isNotEmpty ? profile.ageRange : '18-22';
          _academicLevel = profile.academicLevel.isNotEmpty ? profile.academicLevel : 'Undergraduate';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final user = _auth.currentUser;
      if (user != null && _currentProfile != null) {
        final updatedProfile = UserProfile(
          uid: user.uid,
          email: user.email ?? '',
          fullName: _nameController.text,
          ageRange: _ageRange,
          academicLevel: _academicLevel,
          institution: _institutionController.text,
          fieldOfStudy: _fieldOfStudyController.text,
          routineProfile: _currentProfile!.routineProfile,
          goals: _currentProfile!.goals,
          preferences: _currentProfile!.preferences,
          setupCompleted: true,
          profileCompletedAt: _currentProfile!.profileCompletedAt,
          createdAt: _currentProfile!.createdAt,
          updatedAt: DateTime.now(),
        );

        await _profileService.saveUserProfile(updatedProfile);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully!')),
          );
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _institutionController.dispose();
    _fieldOfStudyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.darkText),
      ),
      extendBodyBehindAppBar: true,
      body: GradientBackground(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue))
            : SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FadeInDown(
                          duration: const Duration(milliseconds: 500),
                          child: Center(
                            child: Stack(
                              children: [
                                Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppColors.primaryBlue, width: 4),
                                    image: const DecorationImage(
                                      image: AssetImage('assets/logo/logo.png'),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: const BoxDecoration(
                                      color: AppColors.primaryBlue,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                        FadeInUp(
                          duration: const Duration(milliseconds: 500),
                          delay: const Duration(milliseconds: 100),
                          child: CustomTextField(
                            controller: _nameController,
                            label: 'Full Name',
                            hint: 'Enter your name',
                            validator: (value) => value == null || value.isEmpty ? 'Name is required' : null,
                          ),
                        ),
                        const SizedBox(height: 20),
                        FadeInUp(
                          duration: const Duration(milliseconds: 500),
                          delay: const Duration(milliseconds: 200),
                          child: _buildDropdown(
                            label: 'Age Range',
                            value: _ageRange,
                            items: _ageRanges,
                            onChanged: (val) => setState(() => _ageRange = val!),
                          ),
                        ),
                        const SizedBox(height: 20),
                        FadeInUp(
                          duration: const Duration(milliseconds: 500),
                          delay: const Duration(milliseconds: 300),
                          child: _buildDropdown(
                            label: 'Academic Level',
                            value: _academicLevel,
                            items: _academicLevels,
                            onChanged: (val) => setState(() => _academicLevel = val!),
                          ),
                        ),
                        const SizedBox(height: 20),
                        FadeInUp(
                          duration: const Duration(milliseconds: 500),
                          delay: const Duration(milliseconds: 400),
                          child: CustomTextField(
                            controller: _institutionController,
                            label: 'University / Institution',
                            hint: 'Enter your university',
                          ),
                        ),
                        const SizedBox(height: 20),
                        FadeInUp(
                          duration: const Duration(milliseconds: 500),
                          delay: const Duration(milliseconds: 500),
                          child: CustomTextField(
                            controller: _fieldOfStudyController,
                            label: 'Field of Study',
                            hint: 'e.g. Computer Science',
                          ),
                        ),
                        const SizedBox(height: 40),
                        FadeInUp(
                          duration: const Duration(milliseconds: 500),
                          delay: const Duration(milliseconds: 600),
                          child: PrimaryButton(
                            label: 'Save Changes',
                            isLoading: _isSaving,
                            onPressed: _saveProfile,
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
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
            color: Colors.white,
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
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primaryBlue),
              items: items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(item, style: const TextStyle(color: AppColors.darkText)),
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
