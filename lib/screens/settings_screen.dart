import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/app_settings.dart';
import '../service/auth_service.dart';
import '../service/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final formKey = GlobalKey<FormState>();
  final budgetController = TextEditingController();

  bool isLoading = true;
  bool isSaving = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadSettings();
  }

  @override
  void dispose() {
    budgetController.dispose();
    super.dispose();
  }

  Future<void> loadSettings() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final settings = await SettingsService.load();

      if (!mounted) return;

      budgetController.text = settings.monthlyBudget.toStringAsFixed(2);

      setState(() {
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = 'Unable to load settings: $error';
      });
    }
  }

  Future<void> saveSettings() async {
    if (!(formKey.currentState?.validate() ?? false)) {
      return;
    }

    final monthlyBudget = double.tryParse(
      budgetController.text.trim().replaceAll(',', ''),
    );

    if (monthlyBudget == null) {
      return;
    }

    setState(() {
      isSaving = true;
      errorMessage = null;
    });

    try {
      await SettingsService.updateMonthlyBudget(monthlyBudget);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved successfully.')),
      );

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isSaving = false;
        errorMessage = 'Unable to save settings: $error';
      });
    }
  }

  Future<void> resetBudget() async {
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Reset Grocery Budget?'),
          content: const Text(
            'Your monthly grocery budget will return to the default amount of \$600.00.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );

    if (shouldReset != true) {
      return;
    }

    setState(() {
      isSaving = true;
      errorMessage = null;
    });

    try {
      await SettingsService.reset();

      if (!mounted) return;

      budgetController.text = AppSettings.defaultMonthlyBudget.toStringAsFixed(
        2,
      );

      setState(() {
        isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Monthly budget reset to \$600.00.')),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isSaving = false;
        errorMessage = 'Unable to reset settings: $error';
      });
    }
  }

  Future<void> signOut() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Sign Out?'),
          content: const Text(
            'You will need to sign in again to access your SmartCart information.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );

    if (shouldSignOut != true) {
      return;
    }

    setState(() {
      isSaving = true;
      errorMessage = null;
    });

    try {
      await AuthService.signOut();

      if (!mounted) return;

      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isSaving = false;
        errorMessage = 'Unable to sign out right now: $error';
      });
    }
  }

  String? validateBudget(String? value) {
    final normalizedValue = value?.trim().replaceAll(',', '');

    if (normalizedValue == null || normalizedValue.isEmpty) {
      return 'Enter a monthly grocery budget.';
    }

    final budget = double.tryParse(normalizedValue);

    if (budget == null) {
      return 'Enter a valid dollar amount.';
    }

    if (budget <= 0) {
      return 'The monthly budget must be greater than \$0.00.';
    }

    if (budget > 1000000) {
      return 'Enter a monthly budget below \$1,000,000.';
    }

    return null;
  }

  Widget buildLoadingState() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget buildErrorBanner() {
    if (errorMessage == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              errorMessage!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildBudgetSection() {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.account_balance_wallet_outlined,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Grocery Budget',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Used by Budget Intelligence and spending forecasts.',
                          style: TextStyle(color: Colors.grey, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              TextFormField(
                controller: budgetController,
                enabled: !isSaving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'^\d{0,7}([.]\d{0,2})?'),
                  ),
                ],
                validator: validateBudget,
                decoration: const InputDecoration(
                  labelText: 'Monthly Grocery Budget',
                  hintText: '600.00',
                  prefixText: '\$ ',
                  helperText:
                      'This amount applies to your current monthly grocery forecast.',
                  border: OutlineInputBorder(),
                ),
                onFieldSubmitted: (_) {
                  if (!isSaving) {
                    saveSettings();
                  }
                },
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: isSaving ? null : resetBudget,
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Reset Default'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: isSaving ? null : saveSettings,
                    icon: isSaving
                        ? const SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(isSaving ? 'Saving...' : 'Save Settings'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildAccountSection() {
    final user = AuthService.currentUser;
    final displayName = user?.userMetadata?['display_name']?.toString().trim();

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person_outline)),
            title: Text(
              displayName != null && displayName.isNotEmpty
                  ? displayName
                  : 'SmartCart Account',
            ),
            subtitle: Text(user?.email ?? 'Signed-in user'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign Out'),
            subtitle: const Text('Sign out of SmartCart on this device'),
            trailing: const Icon(Icons.chevron_right),
            enabled: !isSaving,
            onTap: isSaving ? null : signOut,
          ),
        ],
      ),
    );
  }

  Widget buildAboutSection() {
    return Card(
      child: Column(
        children: [
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('SmartCart Canada'),
            subtitle: Text('Version 1.0.0'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            subtitle: const Text('Coming before Version 1 release'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'The Privacy Policy will be added before release.',
                  ),
                ),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Terms of Service'),
            subtitle: const Text('Coming before Version 1 release'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'The Terms of Service will be added before release.',
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget buildContent() {
    if (isLoading) {
      return buildLoadingState();
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        buildErrorBanner(),
        if (errorMessage != null) const SizedBox(height: 14),
        Text(
          'Personalize how SmartCart tracks and analyzes your grocery spending.',
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 15,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Account',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        buildAccountSection(),
        const SizedBox(height: 24),
        const Text(
          'Preferences',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        buildBudgetSection(),
        const SizedBox(height: 24),
        const Text(
          'About',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        buildAboutSection(),
        const SizedBox(height: 32),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(child: buildContent()),
    );
  }
}
