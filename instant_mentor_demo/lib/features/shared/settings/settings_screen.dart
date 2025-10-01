import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../mentor/availability/availability_screen.dart';
import '../../../core/providers/auth_provider.dart';
import '../../mentor/profile_management/profile_management_screen.dart'
    show mentorProfileProvider; // reuse provider
import 'package:go_router/go_router.dart';

import '../../../core/providers/user_provider.dart';
import '../../../core/services/supabase_service.dart';

// Settings providers for state management
final notificationsEnabledProvider = StateProvider<bool>((ref) => true);
final pushNotificationsProvider = StateProvider<bool>((ref) => true);
final emailNotificationsProvider = StateProvider<bool>((ref) => true);
final studyRemindersProvider = StateProvider<bool>((ref) => true);
final sessionRemindersProvider = StateProvider<bool>((ref) => true);
final soundEffectsProvider = StateProvider<bool>((ref) => true);
final vibrationProvider = StateProvider<bool>((ref) => true);
final darkModeProvider = StateProvider<bool>((ref) => false);
final languageProvider = StateProvider<String>((ref) => 'English');
final autoSyncProvider = StateProvider<bool>((ref) => true);
final dataUsageProvider = StateProvider<String>((ref) => 'WiFi Only');

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isStudent = ref.watch(isStudentProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
        backgroundColor: const Color(0xFF0B1C49),
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0B1C49),
              Color(0xFF1E3A8A),
            ],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Account Section
            _buildModernSectionHeader('Account', Icons.person_outline),
            const SizedBox(height: 8),
            Card(
              color: Colors.white,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.person),
                    title: const Text('Profile'),
                    subtitle: const Text('Manage your profile information'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () => _navigateToProfile(context),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.security),
                    title: const Text('Privacy & Security'),
                    subtitle: const Text('Password, privacy settings'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () => _showPrivacySettings(context),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.payment),
                    title: const Text('Payment Methods'),
                    subtitle: const Text('Manage cards and billing'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () => _showPaymentMethods(context),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Notifications
            _buildSectionHeader(
                context, 'Notifications', Icons.notifications_outlined),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.notifications),
                    title: const Text('Push Notifications'),
                    subtitle:
                        const Text('Receive notifications on your device'),
                    value: ref.watch(pushNotificationsProvider),
                    onChanged: (value) => _updateToggle(
                        ref,
                        'push_notifications',
                        pushNotificationsProvider,
                        value,
                        context),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.email),
                    title: const Text('Email Notifications'),
                    subtitle: const Text('Get updates via email'),
                    value: ref.watch(emailNotificationsProvider),
                    onChanged: (value) => _updateToggle(
                        ref,
                        'email_notifications',
                        emailNotificationsProvider,
                        value,
                        context),
                  ),
                  if (isStudent) ...[
                    const Divider(height: 1),
                    SwitchListTile(
                      secondary: const Icon(Icons.schedule),
                      title: const Text('Study Reminders'),
                      subtitle: const Text('Daily study session reminders'),
                      value: ref.watch(studyRemindersProvider),
                      onChanged: (value) => _updateToggle(
                          ref,
                          'study_reminders',
                          studyRemindersProvider,
                          value,
                          context),
                    ),
                  ],
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.event),
                    title: const Text('Session Reminders'),
                    subtitle: const Text('Upcoming session notifications'),
                    value: ref.watch(sessionRemindersProvider),
                    onChanged: (value) => _updateToggle(
                        ref,
                        'session_reminders',
                        sessionRemindersProvider,
                        value,
                        context),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.tune),
                    title: const Text('Notification Settings'),
                    subtitle: const Text('Customize notification preferences'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () =>
                        _showDetailedNotificationSettings(context, ref),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // App Preferences
            _buildSectionHeader(
                context, 'App Preferences', Icons.settings_outlined),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.dark_mode),
                    title: const Text('Dark Mode'),
                    subtitle: const Text('Use dark theme'),
                    value: ref.watch(darkModeProvider),
                    onChanged: (value) {
                      ref.read(darkModeProvider.notifier).state = value;
                      _showSnackBar(
                          context, 'Theme will change on app restart');
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.language),
                    title: const Text('Language'),
                    subtitle: Text('Currently: ${ref.watch(languageProvider)}'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () => _showLanguageSelector(context, ref),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.volume_up),
                    title: const Text('Sound Effects'),
                    subtitle: const Text('Play sounds for app actions'),
                    value: ref.watch(soundEffectsProvider),
                    onChanged: (value) {
                      ref.read(soundEffectsProvider.notifier).state = value;
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.vibration),
                    title: const Text('Vibration'),
                    subtitle: const Text('Vibrate for notifications'),
                    value: ref.watch(vibrationProvider),
                    onChanged: (value) {
                      ref.read(vibrationProvider.notifier).state = value;
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Data & Storage
            _buildSectionHeader(
                context, 'Data & Storage', Icons.storage_outlined),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.sync),
                    title: const Text('Auto Sync'),
                    subtitle: const Text('Automatically sync data'),
                    value: ref.watch(autoSyncProvider),
                    onChanged: (value) {
                      ref.read(autoSyncProvider.notifier).state = value;
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.data_usage),
                    title: const Text('Data Usage'),
                    subtitle: Text(
                        'Download content: ${ref.watch(dataUsageProvider)}'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () => _showDataUsageSettings(context, ref),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.cleaning_services),
                    title: const Text('Clear Cache'),
                    subtitle: const Text('Free up storage space'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () => _showClearCacheDialog(context),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.download),
                    title: const Text('Offline Content'),
                    subtitle: const Text('Manage downloaded materials'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () => _showOfflineContentManager(context),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Learning Preferences (Student only)
            if (isStudent) ...[
              _buildSectionHeader(context, 'Learning', Icons.school_outlined),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.timer),
                      title: const Text('Session Preferences'),
                      subtitle: const Text('Default session duration, breaks'),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () => _showSessionPreferences(context),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.book),
                      title: const Text('Learning Goals'),
                      subtitle: const Text('Set your study targets'),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () => _showLearningGoals(context),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.assessment),
                      title: const Text('Performance Tracking'),
                      subtitle: const Text('How we track your progress'),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () => _showPerformanceSettings(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Teaching Preferences (Mentor only)
            if (!isStudent) ...[
              _buildSectionHeader(context, 'Teaching', Icons.person_outline),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.schedule),
                      title: const Text('Availability Settings'),
                      subtitle: const Text('Manage your teaching schedule'),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () => _showAvailabilitySettings(context),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.attach_money),
                      title: const Text('Pricing'),
                      subtitle: const Text('Set your hourly rates'),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () => _showPricingSettings(context),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.subject),
                      title: const Text('Subjects & Expertise'),
                      subtitle: const Text('Manage teaching subjects'),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () => _showSubjectsSettings(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Help & Support
            _buildSectionHeader(context, 'Support', Icons.help_outline),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.help_center),
                    title: const Text('Help Center'),
                    subtitle: const Text('FAQs and guides'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () => _showHelpCenter(context),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.chat_bubble),
                    title: const Text('Contact Support'),
                    subtitle: const Text('Get help from our team'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () => _contactSupport(context),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.bug_report),
                    title: const Text('Report Issue'),
                    subtitle: const Text('Found a bug? Let us know'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () => _reportIssue(context),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // About
            _buildSectionHeader(context, 'About', Icons.info_outline),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.info),
                    title: const Text('App Version'),
                    subtitle: const Text('1.0.0 (Build 100)'),
                    trailing: TextButton(
                      onPressed: () => _checkForUpdates(context),
                      child: const Text('Check Updates'),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.description),
                    title: const Text('Terms of Service'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () => _showTerms(context),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.privacy_tip),
                    title: const Text('Privacy Policy'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () => _showPrivacyPolicy(context),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.star),
                    title: const Text('Rate App'),
                    subtitle: const Text('Help us improve'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () => _rateApp(context),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Logout
            Card(
              child: ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title:
                    const Text('Logout', style: TextStyle(color: Colors.red)),
                onTap: () => _showLogoutDialog(context, ref),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
      BuildContext context, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ],
      ),
    );
  }

  void _navigateToProfile(BuildContext context) {
    Navigator.pushNamed(context, '/profile');
  }

  // Persist toggle with optimistic update
  void _updateToggle<T>(WidgetRef ref, String key, StateProvider<bool> provider,
      bool newValue, BuildContext context) async {
    final previousValue = ref.read(provider);

    print(
        '🔵 SettingsScreen: Toggle "$key" changing from $previousValue to $newValue');

    try {
      print('🔵 SettingsScreen: Setting optimistic state for "$key"');
      ref.read(provider.notifier).state = newValue; // optimistic update

      print(
          '🔵 SettingsScreen: Calling SupabaseService.updateUserPreferences for "$key"');
      await SupabaseService.instance.updateUserPreferences({key: newValue});

      print('🟢 SettingsScreen: Toggle "$key" saved successfully');
      if (context.mounted) {
        _showSnackBar(context, 'Setting "$key" saved successfully');
      }
    } catch (e) {
      print('🔴 SettingsScreen: Toggle "$key" save failed: $e');
      // revert on failure
      ref.read(provider.notifier).state = previousValue;
      print('🔴 SettingsScreen: Reverted "$key" back to $previousValue');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to save "$key": $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showPrivacySettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy & Security'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.lock),
              title: const Text('Change Password'),
              onTap: () {
                Navigator.pop(context);
                _showChangePassword(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.fingerprint),
              title: const Text('Biometric Login'),
              onTap: () {
                Navigator.pop(context);
                _showSnackBar(context, 'Biometric setup coming soon!');
              },
            ),
            ListTile(
              leading: const Icon(Icons.security),
              title: const Text('Two-Factor Auth'),
              onTap: () {
                Navigator.pop(context);
                _showSnackBar(context, '2FA setup coming soon!');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showPaymentMethods(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payment Methods'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              leading: Icon(Icons.credit_card),
              title: Text('**** **** **** 1234'),
              subtitle: Text('Visa • Expires 12/25'),
              trailing: Icon(Icons.more_vert),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: const Text('Add New Payment Method'),
              onTap: () {
                Navigator.pop(context);
                _showSnackBar(context, 'Add payment method coming soon!');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showDetailedNotificationSettings(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notification Preferences'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text('Session Reminders'),
                subtitle: const Text('15 minutes before session'),
                value: true,
                onChanged: (value) {},
              ),
              SwitchListTile(
                title: const Text('New Messages'),
                subtitle: const Text('When you receive messages'),
                value: true,
                onChanged: (value) {},
              ),
              SwitchListTile(
                title: const Text('Weekly Progress'),
                subtitle: const Text('Weekly learning summary'),
                value: false,
                onChanged: (value) {},
              ),
              SwitchListTile(
                title: const Text('Promotion Updates'),
                subtitle: const Text('Offers and discounts'),
                value: false,
                onChanged: (value) {},
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showLanguageSelector(BuildContext context, WidgetRef ref) {
    final languages = [
      'English',
      'Hindi',
      'Tamil',
      'Telugu',
      'Bengali',
      'Spanish',
      'French'
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: languages.map((language) {
            return RadioListTile<String>(
              title: Text(language),
              value: language,
              groupValue: ref.watch(languageProvider),
              onChanged: (value) {
                if (value != null) {
                  ref.read(languageProvider.notifier).state = value;
                  Navigator.pop(context);
                  _showSnackBar(context, 'Language changed to $value');
                }
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showDataUsageSettings(BuildContext context, WidgetRef ref) {
    final options = ['WiFi Only', 'WiFi + Cellular', 'Always Ask'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Data Usage'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((option) {
            return RadioListTile<String>(
              title: Text(option),
              value: option,
              groupValue: ref.watch(dataUsageProvider),
              onChanged: (value) {
                if (value != null) {
                  ref.read(dataUsageProvider.notifier).state = value;
                  Navigator.pop(context);
                  _showSnackBar(context, 'Data usage set to $value');
                }
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showChangePassword(BuildContext context) {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: currentCtrl,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'Current Password'),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Enter current password' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: newCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New Password'),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter new password';
                  if (v.length < 8) return 'Min 8 characters';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: confirmCtrl,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'Confirm New Password'),
                validator: (v) =>
                    v != newCtrl.text ? 'Passwords do not match' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(context); // close dialog
              // show progress
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) =>
                    const Center(child: CircularProgressIndicator()),
              );
              try {
                // Note: Supabase requires re-auth for true current password validation; here we just set new.
                // Use Riverpod ref via Navigator ancestor context: wrap call in a ProviderScope consumer
                // Since this method is inside ConsumerWidget, we can access a ProviderContainer through ProviderScope.containerOf
                final container =
                    ProviderScope.containerOf(context, listen: false);
                await container
                    .read(authProvider.notifier)
                    .setNewPassword(newCtrl.text.trim());
                Navigator.of(context).pop();
                _showSnackBar(context, 'Password updated');
              } catch (e) {
                Navigator.of(context).pop();
                _showSnackBar(context, 'Failed: $e');
              }
            },
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  // Helper methods for other dialogs
  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text(
            'This will clear 245 MB of cached data. The app may take longer to load content initially.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showSnackBar(context, 'Cache cleared successfully!');
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showOfflineContentManager(BuildContext context) {
    _showSnackBar(context, 'Offline content manager coming soon!');
  }

  void _showSessionPreferences(BuildContext context) {
    _showSnackBar(context, 'Session preferences coming soon!');
  }

  void _showLearningGoals(BuildContext context) {
    _showSnackBar(context, 'Learning goals setup coming soon!');
  }

  void _showPerformanceSettings(BuildContext context) {
    _showSnackBar(context, 'Performance tracking settings coming soon!');
  }

  void _showAvailabilitySettings(BuildContext context) {
    // Navigate to dedicated availability screen inside a scaffold
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Availability Settings')),
          body: const AvailabilityScreen(),
        ),
      ),
    );
  }

  void _showPricingSettings(BuildContext context) {
    final ref = ProviderScope.containerOf(context, listen: false);
    final profile = ref.read(mentorProfileProvider);
    final controller =
        TextEditingController(text: profile['hourlyRate'].toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pricing'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Set your hourly rate (USD)'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                prefixText: '\$',
                border: OutlineInputBorder(),
                labelText: 'Hourly Rate',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final value = double.tryParse(controller.text.trim());
              if (value == null || value <= 0) {
                _showSnackBar(context, 'Enter a valid positive amount');
                return;
              }
              final updated = {...profile, 'hourlyRate': value};
              ref.read(mentorProfileProvider.notifier).state = updated;
              ref.read(authProvider.notifier).updateProfile(updated);
              Navigator.pop(ctx);
              _showSnackBar(context,
                  'Hourly rate updated to \$${value.toStringAsFixed(2)}');
            },
            child: const Text('Save'),
          )
        ],
      ),
    );
  }

  void _showSubjectsSettings(BuildContext context) {
    final ref = ProviderScope.containerOf(context, listen: false);
    final profile = ref.read(mentorProfileProvider);
    final List<String> subjects = List<String>.from(profile['subjects'] ?? []);
    final controller = TextEditingController();

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) {
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: StatefulBuilder(
              builder: (ctx, setState) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Subjects & Expertise',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w600)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      )
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: subjects
                        .map((s) => Chip(
                              label: Text(s),
                              deleteIcon: const Icon(Icons.close, size: 16),
                              onDeleted: () {
                                setState(() => subjects.remove(s));
                              },
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          decoration: const InputDecoration(
                            labelText: 'Add subject',
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) =>
                              _addSubject(controller, subjects, setState),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () =>
                            _addSubject(controller, subjects, setState),
                        child: const Text('Add'),
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('Save Subjects'),
                      onPressed: () {
                        if (subjects.isEmpty) {
                          _showSnackBar(context, 'Add at least one subject');
                          return;
                        }
                        final updated = {...profile, 'subjects': subjects};
                        ref.read(mentorProfileProvider.notifier).state =
                            updated;
                        ref.read(authProvider.notifier).updateProfile(updated);
                        Navigator.pop(ctx);
                        _showSnackBar(context, 'Subjects updated');
                      },
                    ),
                  )
                ],
              ),
            ),
          );
        });
  }

  void _addSubject(TextEditingController controller, List<String> subjects,
      void Function(void Function()) setState) {
    final text = controller.text.trim();
    if (text.isEmpty) return;
    if (!subjects.contains(text)) {
      setState(() => subjects.add(text));
    }
    controller.clear();
  }

  void _showHelpCenter(BuildContext context) {
    final helpTopics = [
      {
        'title': 'Getting Started',
        'content':
            'Learn how to set up your mentor profile and begin accepting sessions.'
      },
      {
        'title': 'Scheduling Sessions',
        'content':
            'Tips on managing availability and booking sessions with students.'
      },
      {
        'title': 'Earnings & Payouts',
        'content':
            'Understand how hourly rates, session billing, and payouts work.'
      },
      {
        'title': 'Real-time Communication',
        'content': 'Troubleshoot audio/video or chat connectivity issues.'
      },
    ];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Help Center'),
        content: SizedBox(
          width: 400,
          child: ListView.separated(
            shrinkWrap: true,
            itemBuilder: (_, i) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(helpTopics[i]['title']!),
              subtitle: Text(helpTopics[i]['content']!,
                  style: const TextStyle(fontSize: 12)),
              leading: const Icon(Icons.help_outline),
            ),
            separatorBuilder: (_, __) => const Divider(height: 12),
            itemCount: helpTopics.length,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close'))
        ],
      ),
    );
  }

  void _contactSupport(BuildContext context) {
    final subjectController = TextEditingController();
    final messageController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                    child: Text('Contact Support',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600))),
                IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close))
              ],
            ),
            TextField(
              controller: subjectController,
              decoration: const InputDecoration(
                  labelText: 'Subject', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: messageController,
              maxLines: 5,
              decoration: const InputDecoration(
                  labelText: 'Message', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.send),
                label: const Text('Send Message'),
                onPressed: () {
                  if (subjectController.text.trim().isEmpty ||
                      messageController.text.trim().isEmpty) {
                    _showSnackBar(context, 'Please fill subject & message');
                    return;
                  }
                  // Placeholder: integrate with support ticket API
                  Navigator.pop(ctx);
                  _showSnackBar(context, 'Support request sent');
                },
              ),
            )
          ],
        ),
      ),
    );
  }

  void _reportIssue(BuildContext context) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    bool includeLogs = true;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Report Issue'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                        labelText: 'Title', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    maxLines: 5,
                    decoration: const InputDecoration(
                        labelText: 'Description', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: includeLogs,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Include diagnostic info'),
                    onChanged: (v) => setState(() => includeLogs = v),
                  )
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (titleController.text.trim().isEmpty) {
                  _showSnackBar(context, 'Provide a title');
                  return;
                }
                // Placeholder: send to backend issue tracker
                Navigator.pop(ctx);
                _showSnackBar(context, 'Issue reported. Thank you!');
              },
              child: const Text('Submit'),
            )
          ],
        ),
      ),
    );
  }

  void _checkForUpdates(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('App Updates'),
        content:
            const Text('You are using the latest version of InstantMentor!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showTerms(BuildContext context) {
    _showSnackBar(context, 'Terms of service coming soon!');
  }

  void _showPrivacyPolicy(BuildContext context) {
    _showSnackBar(context, 'Privacy policy coming soon!');
  }

  void _rateApp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rate InstantMentor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('How would you rate your experience?'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _showSnackBar(
                        context, 'Thank you for rating us ${index + 1} stars!');
                  },
                  icon: Icon(Icons.star_border, color: Colors.amber[600]),
                );
              }),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // Show loading indicator
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(),
                ),
              );

              try {
                // Properly sign out through auth provider
                await ref.read(authProvider.notifier).signOut();
                // Navigation will be handled by router redirect logic automatically
                if (context.mounted) {
                  Navigator.of(context).pop(); // Close loading
                  // Explicitly navigate to login after logout to ensure redirect works
                  context.go('/login');
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.of(context).pop(); // Close loading
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Logout failed: $e')),
                  );
                }
              }
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildModernSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8, left: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB)
                  .withOpacity(0.1), // Original blue color
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF2563EB), // Original blue color
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              fontFamily: 'SF Pro Display',
            ),
          ),
        ],
      ),
    );
  }
}
