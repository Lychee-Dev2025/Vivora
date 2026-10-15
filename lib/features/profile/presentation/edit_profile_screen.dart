import 'package:flutter/material.dart';

import '../../../core/services/session.dart';
import '../../../core/theme/vivora_palette.dart';
import '../../../core/utils/friendly_error.dart';
import '../../../core/widgets/app_bar_title.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../first_time_setup/data/models/user_profile_model.dart';
import '../../first_time_setup/data/services/user_profile_service.dart';

/// Edits the existing profile fields (same Firestore fields as before).
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, this.loadProfile, this.saveProfile});

  /// Overrides for tests; default to Firestore via [UserProfileService].
  final Future<UserProfile?> Function(String uid)? loadProfile;
  final Future<void> Function(UserProfile profile)? saveProfile;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _profileService = UserProfileService();

  final _nameController = TextEditingController();
  final _institutionController = TextEditingController();
  final _fieldOfStudyController = TextEditingController();

  static const List<String> _ageRanges = <String>[
    'Under 18',
    '18-22',
    '23-26',
    '27-30',
    '30+',
  ];
  static const List<String> _academicLevels = <String>[
    'High School',
    'Undergraduate',
    'Postgraduate',
    'Doctorate',
    'Other',
  ];

  String _ageRange = '18-22';
  String _academicLevel = 'Undergraduate';
  bool _isLoading = true;
  bool _isSaving = false;
  bool _dirty = false;
  String? _loadError;
  UserProfile? _currentProfile;

  @override
  void initState() {
    super.initState();
    for (final TextEditingController c in <TextEditingController>[
      _nameController,
      _institutionController,
      _fieldOfStudyController,
    ]) {
      c.addListener(_markDirty);
    }
    _loadProfile();
  }

  void _markDirty() {
    if (!_dirty && !_isLoading) setState(() => _dirty = true);
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    final String? uid = Session.currentUserId();
    try {
      final UserProfile? profile = uid == null
          ? null
          : await (widget.loadProfile?.call(uid) ??
                    _profileService.getUserProfile(uid))
                .timeout(const Duration(seconds: 10));
      if (!mounted) return;
      setState(() {
        _currentProfile = profile;
        if (profile != null) {
          _nameController.text = profile.fullName;
          _institutionController.text = profile.institution;
          _fieldOfStudyController.text = profile.fieldOfStudy;
          if (profile.ageRange.isNotEmpty) _ageRange = profile.ageRange;
          if (profile.academicLevel.isNotEmpty) {
            _academicLevel = profile.academicLevel;
          }
        } else {
          _loadError = uid == null
              ? 'You are signed out. Please sign in again to edit your profile.'
              : 'No profile was found for this account yet.';
        }
        _isLoading = false;
        _dirty = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = friendlyError(error, action: 'load your profile');
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);
    try {
      final String? uid = Session.currentUserId();
      final UserProfile? current = _currentProfile;
      if (uid == null || current == null) {
        throw StateError('No signed-in user or profile');
      }
      await (widget.saveProfile ?? _profileService.saveUserProfile)(
        UserProfile(
          uid: uid,
          email: Session.currentEmail() ?? current.email,
          fullName: _nameController.text.trim(),
          ageRange: _ageRange,
          academicLevel: _academicLevel,
          institution: _institutionController.text.trim(),
          fieldOfStudy: _fieldOfStudyController.text.trim(),
          routineProfile: current.routineProfile,
          goals: current.goals,
          preferences: current.preferences,
          setupCompleted: true,
          profileCompletedAt: current.profileCompletedAt,
          createdAt: current.createdAt,
          updatedAt: DateTime.now(),
        ),
      );
      if (!mounted) return;
      _dirty = false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated')));
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyError(error, action: 'save your profile')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<bool> _confirmDiscard() async {
    final bool? discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Discard changes?'),
        content: const Text('Your edits have not been saved.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return discard ?? false;
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
    return PopScope(
      canPop: !_dirty || _isSaving,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) {
          setState(() => _dirty = false);
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const AppBarTitle('Edit Profile')),
        body: GradientBackground(child: _body(context)),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return ListView(
        padding: const EdgeInsets.only(top: Space.xl),
        children: <Widget>[
          StateMessage.error(message: _loadError!, onAction: _loadProfile),
        ],
      );
    }
    return Form(
      key: _formKey,
      child: ListView(
        padding: EdgeInsets.only(
          top: Space.lg,
          bottom: Space.xxxl + MediaQuery.viewInsetsOf(context).bottom,
        ),
        children: <Widget>[
          Center(
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _nameController,
              builder: (context, value, _) =>
                  InitialsAvatar(name: value.text, size: 88),
            ),
          ),
          const SizedBox(height: Space.sm),
          Text(
            'Your avatar shows your initials.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.palette.textSecondary,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: Space.xxl),
          SectionCard(
            title: 'PERSONAL',
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(Space.lg),
                child: Column(
                  children: <Widget>[
                    CustomTextField(
                      controller: _nameController,
                      label: 'Full name',
                      hint: 'Enter your name',
                      validator: (String? value) {
                        final String v = (value ?? '').trim();
                        if (v.isEmpty) return 'Name is required';
                        if (v.length > 60) {
                          return 'Please use 60 characters or fewer';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: Space.lg),
                    _dropdown(
                      label: 'Age range',
                      value: _ageRange,
                      options: _ageRanges,
                      onChanged: (v) => setState(() {
                        _ageRange = v;
                        _dirty = true;
                      }),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.xl),
          SectionCard(
            title: 'ACADEMIC',
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(Space.lg),
                child: Column(
                  children: <Widget>[
                    _dropdown(
                      label: 'Academic level',
                      value: _academicLevel,
                      options: _academicLevels,
                      onChanged: (v) => setState(() {
                        _academicLevel = v;
                        _dirty = true;
                      }),
                    ),
                    const SizedBox(height: Space.lg),
                    CustomTextField(
                      controller: _institutionController,
                      label: 'University / Institution (optional)',
                      hint: 'Your university',
                    ),
                    const SizedBox(height: Space.lg),
                    CustomTextField(
                      controller: _fieldOfStudyController,
                      label: 'Field of study (optional)',
                      hint: 'e.g. Computer Science',
                      textInputAction: TextInputAction.done,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.xxl),
          PrimaryButton(
            label: 'Save changes',
            icon: Icons.check_rounded,
            isLoading: _isSaving,
            onPressed: _isSaving ? null : _saveProfile,
          ),
        ],
      ),
    );
  }

  /// A dropdown that also accepts a stored value outside [options] (older
  /// profiles), instead of crashing.
  Widget _dropdown({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String> onChanged,
  }) {
    final List<String> items = <String>[
      ...options,
      if (!options.contains(value)) value,
    ];
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(label: Text(label, softWrap: true)),
      dropdownColor: context.palette.surface,
      items: <DropdownMenuItem<String>>[
        for (final String item in items)
          DropdownMenuItem<String>(
            value: item,
            child: Text(item, overflow: TextOverflow.visible),
          ),
      ],
      onChanged: (String? v) {
        if (v != null) onChanged(v);
      },
    );
  }
}
