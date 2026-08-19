import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../service/auth_service.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final formKey = GlobalKey<FormState>();
  final displayNameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool isSubmitting = false;
  bool obscurePassword = true;
  bool obscureConfirmation = true;
  bool acceptedTerms = false;
  String? errorMessage;

  @override
  void dispose() {
    displayNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  String? validateDisplayName(String? value) {
    final name = value?.trim() ?? '';

    if (name.isEmpty) {
      return 'Enter your name.';
    }

    if (name.length < 2) {
      return 'Enter at least two characters.';
    }

    return null;
  }

  String? validateEmail(String? value) {
    final email = value?.trim() ?? '';

    if (email.isEmpty) {
      return 'Enter your email address.';
    }

    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

    if (!emailPattern.hasMatch(email)) {
      return 'Enter a valid email address.';
    }

    return null;
  }

  String? validatePassword(String? value) {
    final password = value ?? '';

    if (password.isEmpty) {
      return 'Create a password.';
    }

    if (password.length < 8) {
      return 'Use at least eight characters.';
    }

    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'Include at least one uppercase letter.';
    }

    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return 'Include at least one lowercase letter.';
    }

    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return 'Include at least one number.';
    }

    return null;
  }

  String? validateConfirmation(String? value) {
    if (value != passwordController.text) {
      return 'The passwords do not match.';
    }

    return null;
  }

  Future<void> createAccount() async {
    if (!(formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (!acceptedTerms) {
      setState(() {
        errorMessage =
            'You must accept the Privacy Policy and Terms of Service.';
      });
      return;
    }

    setState(() {
      isSubmitting = true;
      errorMessage = null;
    });

    try {
      final response = await AuthService.signUp(
        email: emailController.text,
        password: passwordController.text,
        displayName: displayNameController.text,
      );

      if (!mounted) return;

      if (response.session != null) {
        Navigator.popUntil(context, (route) => route.isFirst);
        return;
      }

      Navigator.pop(context, true);
    } on AuthException catch (error) {
      if (!mounted) return;

      setState(() {
        isSubmitting = false;
        errorMessage = _friendlyAuthMessage(error);
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isSubmitting = false;
        errorMessage = 'Unable to create the account right now.';
      });
    }
  }

  String _friendlyAuthMessage(AuthException error) {
    final message = error.message.toLowerCase();

    if (message.contains('already registered') ||
        message.contains('already exists')) {
      return 'An account already exists for this email address.';
    }

    if (message.contains('password')) {
      return error.message;
    }

    if (message.contains('rate limit')) {
      return 'Too many account requests. Please wait and try again.';
    }

    return error.message;
  }

  Widget buildErrorBanner() {
    if (errorMessage == null) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              errorMessage!,
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Join Rocket Science Shopping',
                          style: TextStyle(
                            fontSize: 27,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create an account to securely save and synchronize your grocery information.',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 24),
                        buildErrorBanner(),
                        if (errorMessage != null) const SizedBox(height: 18),
                        TextFormField(
                          controller: displayNameController,
                          enabled: !isSubmitting,
                          textInputAction: TextInputAction.next,
                          validator: validateDisplayName,
                          decoration: const InputDecoration(
                            labelText: 'Display Name',
                            prefixIcon: Icon(Icons.person_outline),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: emailController,
                          enabled: !isSubmitting,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          validator: validateEmail,
                          decoration: const InputDecoration(
                            labelText: 'Email Address',
                            prefixIcon: Icon(Icons.email_outlined),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: passwordController,
                          enabled: !isSubmitting,
                          obscureText: obscurePassword,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.newPassword],
                          validator: validatePassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            helperText:
                                'At least 8 characters with upper, lower and a number.',
                            prefixIcon: const Icon(Icons.lock_outline),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  obscurePassword = !obscurePassword;
                                });
                              },
                              icon: Icon(
                                obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: confirmPasswordController,
                          enabled: !isSubmitting,
                          obscureText: obscureConfirmation,
                          textInputAction: TextInputAction.done,
                          validator: validateConfirmation,
                          onFieldSubmitted: (_) {
                            if (!isSubmitting) {
                              createAccount();
                            }
                          },
                          decoration: InputDecoration(
                            labelText: 'Confirm Password',
                            prefixIcon: const Icon(Icons.lock_reset_outlined),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  obscureConfirmation = !obscureConfirmation;
                                });
                              },
                              icon: Icon(
                                obscureConfirmation
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        CheckboxListTile(
                          value: acceptedTerms,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          onChanged: isSubmitting
                              ? null
                              : (value) {
                                  setState(() {
                                    acceptedTerms = value ?? false;
                                  });
                                },
                          title: const Text(
                            'I agree to the Privacy Policy and Terms of Service.',
                          ),
                          subtitle: const Text(
                            'The final documents will be available before public release.',
                          ),
                        ),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: isSubmitting ? null : createAccount,
                          icon: isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.person_add_outlined),
                          label: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            child: Text(
                              isSubmitting
                                  ? 'Creating Account...'
                                  : 'Create Account',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
