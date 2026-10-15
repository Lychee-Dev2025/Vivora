import 'package:flutter/material.dart';
import 'package:vivora/core/theme/vivora_palette.dart';

import '../../../../core/services/auth_service.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/primary_button.dart';

class AuthForm extends StatefulWidget {
  const AuthForm({super.key, required this.isLogin, required this.onSuccess});

  final bool isLogin;
  final VoidCallback onSuccess;

  @override
  State<AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<AuthForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();

  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _requiredValidator(String? value, String field) {
    if (value == null || value.trim().isEmpty) {
      return '$field is required';
    }
    return null;
  }

  String? _emailValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    final RegExp emailRegex = RegExp(r'^[\w\.-]+@[\w\.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Enter a valid email';
    }
    return null;
  }

  String? _confirmPasswordValidator(String? value) {
    if (widget.isLogin) {
      return null;
    }
    if (value == null || value.isEmpty) {
      return 'Confirm your password';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: context.palette.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _resendVerification() async {
    final String result = await _authService.resendVerification(
      email: _emailController.text,
      password: _passwordController.text,
    );
    if (!mounted) return;
    result == 'success'
        ? _showSuccess(
            'Verification email sent. Check your inbox and spam folder.',
          )
        : _showError(result);
  }

  Future<void> _forgotPassword() async {
    final String email = _emailController.text.trim();
    if (_emailValidator(email) != null) {
      _showError('Enter your email above first, then tap "Forgot password?".');
      return;
    }
    final String result = await _authService.sendPasswordReset(email);
    if (!mounted) return;
    result == 'success'
        ? _showSuccess(
            'If an account exists for $email, a reset link has been sent.',
          )
        : _showError(result);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    String? result;
    if (widget.isLogin) {
      result = await _authService.signIn(
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (result == 'success') {
        widget.onSuccess();
      } else if (result == 'invalid-email') {
        _showError('Invalid email');
      } else if (result == 'invalid-credentials') {
        _showError('Incorrect email or password.');
      } else if (result == 'email-not-verified') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Please verify your email before logging in.',
              ),
              backgroundColor: context.palette.danger,
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'Resend',
                textColor: Colors.white,
                onPressed: _resendVerification,
              ),
            ),
          );
        }
      } else {
        _showError(result ?? 'An unknown error occurred');
      }
    } else {
      result = await _authService.signUp(
        email: _emailController.text,
        password: _passwordController.text,
        name: _nameController.text,
      );

      if (result == 'success') {
        _showSuccess('Account created! Please check your email to verify.');
        // Optionally switch to login mode here or just stay on signup with the message
      } else {
        _showError(result ?? 'An unknown error occurred');
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: <Widget>[
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: widget.isLogin
                ? const SizedBox.shrink()
                : Padding(
                    key: const ValueKey<String>('name-field'),
                    padding: const EdgeInsets.only(bottom: 14),
                    child: CustomTextField(
                      controller: _nameController,
                      label: 'Full Name',
                      hint: 'Enter your name',
                      validator: (String? value) =>
                          _requiredValidator(value, 'Name'),
                    ),
                  ),
          ),
          CustomTextField(
            controller: _emailController,
            label: 'Email',
            hint: 'alex@example.com',
            keyboardType: TextInputType.emailAddress,
            validator: _emailValidator,
          ),
          const SizedBox(height: 14),
          CustomTextField(
            controller: _passwordController,
            label: 'Password',
            hint: 'Enter your password',
            isPassword: true,
            validator: (String? value) => _requiredValidator(value, 'Password'),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: widget.isLogin
                ? const SizedBox.shrink()
                : Padding(
                    key: const ValueKey<String>('confirm-password-field'),
                    padding: const EdgeInsets.only(top: 14),
                    child: CustomTextField(
                      controller: _confirmPasswordController,
                      label: 'Confirm Password',
                      hint: 'Re-enter password',
                      isPassword: true,
                      validator: _confirmPasswordValidator,
                    ),
                  ),
          ),
          if (widget.isLogin)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _isLoading ? null : _forgotPassword,
                child: const Text('Forgot password?'),
              ),
            )
          else
            const SizedBox(height: 22),
          PrimaryButton(
            label: widget.isLogin ? 'Login' : 'Create Account',
            isLoading: _isLoading,
            onPressed: _isLoading ? null : _submit,
            icon: widget.isLogin
                ? Icons.login_rounded
                : Icons.person_add_alt_1_rounded,
          ),
        ],
      ),
    );
  }
}
