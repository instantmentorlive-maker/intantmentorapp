import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/services/supabase_service.dart';
import '../../mentor/availability/availability_screen.dart';
import '../../mentor/profile_management/profile_management_screen.dart'; // Import both provider and screen class

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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ProfileManagementScreen(),
      ),
    );
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Offline Content'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Manage downloaded content for offline access',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.video_library, color: Colors.blue),
                title: const Text('Session Recordings'),
                subtitle: const Text('3 videos • 245 MB'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    Navigator.pop(context);
                    _showSnackBar(context, 'Session recordings cleared');
                  },
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                title: const Text('Study Materials'),
                subtitle: const Text('12 documents • 18 MB'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    Navigator.pop(context);
                    _showSnackBar(context, 'Study materials cleared');
                  },
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.chat, color: Colors.green),
                title: const Text('Chat History'),
                subtitle: const Text('Cached messages • 5 MB'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    Navigator.pop(context);
                    _showSnackBar(context, 'Chat history cleared');
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Storage Used:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    '268 MB',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showSnackBar(context, 'All offline content cleared!');
                  },
                  icon: const Icon(Icons.delete_sweep),
                  label: const Text('Clear All Offline Content'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
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
    final profileAsync = ref.read(mentorProfileProvider);

    if (!profileAsync.hasValue) {
      _showSnackBar(context, 'Profile not loaded yet');
      return;
    }

    final profile = profileAsync.value!;
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
              // Note: Actual save would update database - this is simplified
              ref.invalidate(mentorProfileProvider);
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
    final profileAsync = ref.read(mentorProfileProvider);

    if (!profileAsync.hasValue) {
      _showSnackBar(context, 'Profile not loaded yet');
      return;
    }

    final profile = profileAsync.value!;
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
                        // Note: Actual save would update database - this is simplified
                        ref.invalidate(mentorProfileProvider);
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
            'Learn how to set up your mentor profile and begin accepting sessions.',
        'details': '''
📋 Getting Started Guide

1. Complete Your Profile
   • Add your full name, bio, and profile photo
   • Set your hourly rate
   • List your subjects and expertise areas
   • Add your qualifications and experience

2. Set Your Availability
   • Navigate to Availability screen
   • Set your working hours and time zones
   • Enable instant booking or require approval

3. Accept Your First Session
   • Wait for session requests from students
   • Review request details and student profile
   • Accept or decline based on your availability

4. Prepare for Sessions
   • Test your audio/video setup
   • Review session materials in advance
   • Join sessions on time via the app

Need help? Contact support anytime!
'''
      },
      {
        'title': 'Scheduling Sessions',
        'content':
            'Tips on managing availability and booking sessions with students.',
        'details': '''
📅 Scheduling Sessions

Managing Your Availability:
   • Set recurring weekly schedules
   • Block out unavailable time slots
   • Enable/disable instant booking
   • Set buffer time between sessions

Accepting Requests:
   • Review session requests promptly
   • Check student profiles and needs
   • Accept within 24 hours for best results
   • Communicate with students before sessions

Session Types:
   • One-time sessions
   • Recurring weekly sessions
   • Instant calls (if enabled)
   • Emergency tutoring requests

Best Practices:
   ✓ Keep your calendar updated
   ✓ Respond to requests quickly
   ✓ Set realistic availability
   ✓ Allow prep time between sessions
'''
      },
      {
        'title': 'Earnings & Payouts',
        'content':
            'Understand how hourly rates, session billing, and payouts work.',
        'details': '''
💰 Earnings & Payouts

How You Get Paid:
   • Set your hourly rate in your profile
   • Earn based on actual session duration
   • Platform fee: 20% (subject to change)
   • Payments processed weekly

Payment Schedule:
   • Sessions billed immediately after completion
   • Earnings available after 3-day hold period
   • Payouts every Friday
   • Direct deposit to your bank account

Viewing Your Earnings:
   • Check Earnings screen for details
   • See pending and completed payouts
   • Download monthly statements
   • Track session history

Maximizing Earnings:
   ✓ Maintain high ratings (5-star preferred)
   ✓ Accept more sessions
   ✓ Offer specialized subjects
   ✓ Build student relationships
   ✓ Enable instant booking

Tax Information:
   • You're an independent contractor
   • Responsible for your own taxes
   • 1099 forms provided annually (US)
   • Consult tax professional as needed
'''
      },
      {
        'title': 'Real-time Communication',
        'content': 'Troubleshoot audio/video or chat connectivity issues.',
        'details': '''
🎥 Real-time Communication

Common Issues & Solutions:

Audio Problems:
   ✓ Check microphone permissions in browser
   ✓ Test microphone in device settings
   ✓ Close other apps using microphone
   ✓ Try different browser (Chrome recommended)
   ✓ Check volume levels

Video Problems:
   ✓ Allow camera access in browser
   ✓ Check if camera is already in use
   ✓ Restart browser/device
   ✓ Update browser to latest version
   ✓ Check lighting conditions

Chat Issues:
   ✓ Refresh the page
   ✓ Check internet connection
   ✓ Clear browser cache
   ✓ Try incognito/private mode

Connection Tips:
   • Use stable WiFi or wired connection
   • Close unnecessary browser tabs
   • Disable VPN if having issues
   • Minimum 5 Mbps upload/download speed
   • Restart router if connection drops

Screen Sharing:
   • Click screen share button in session
   • Select window or entire screen
   • Grant permission when prompted
   • Stop sharing when done

Still having issues?
Contact support with:
   • Browser name and version
   • Device type (Windows/Mac/Mobile)
   • Error message screenshot
   • Session ID
'''
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
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              leading: const Icon(Icons.help_outline),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.pop(ctx);
                _showHelpTopicDetails(context, helpTopics[i]);
              },
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

  void _showHelpTopicDetails(BuildContext context, Map<String, String> topic) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.help_outline, color: Colors.blue),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                topic['title']!,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                topic['details']!,
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Need more help? Contact our support team anytime!',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _contactSupport(context);
            },
            child: const Text('Contact Support'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
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
            const SizedBox(height: 8),
            const Text(
              'Our support team is here to help you 24/7',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: subjectController,
              decoration: const InputDecoration(
                labelText: 'Subject',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.subject),
                hintText: 'What do you need help with?',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: messageController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Message',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.message),
                hintText: 'Please describe your issue or question...',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.send),
                label: const Text('Send Message'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  if (subjectController.text.trim().isEmpty ||
                      messageController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text('Please fill in both subject and message'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }
                  // Placeholder: integrate with support ticket API
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          '✅ Support request sent! We\'ll respond within 24 hours.'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 3),
                    ),
                  );
                  subjectController.dispose();
                  messageController.dispose();
                },
              ),
            ),
            const SizedBox(height: 8),
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
          title: Row(
            children: const [
              Icon(Icons.bug_report, color: Colors.red),
              SizedBox(width: 8),
              Text('Report Issue'),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Help us improve by reporting bugs or issues',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Issue Title',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.title),
                      hintText: 'Brief summary of the issue',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.description),
                      hintText: 'Please describe the issue in detail...',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      children: [
                        SwitchListTile(
                          value: includeLogs,
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Include diagnostic information'),
                          subtitle: const Text(
                            'Helps us identify and fix the issue faster',
                            style: TextStyle(fontSize: 12),
                          ),
                          onChanged: (v) => setState(() => includeLogs = v),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                titleController.dispose();
                descController.dispose();
                Navigator.pop(ctx);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.send),
              label: const Text('Submit Report'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                if (titleController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please provide an issue title'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                if (descController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please describe the issue'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                // Placeholder: send to backend issue tracker
                final issueData = {
                  'title': titleController.text.trim(),
                  'description': descController.text.trim(),
                  'includeLogs': includeLogs,
                  'timestamp': DateTime.now().toIso8601String(),
                };
                debugPrint('Issue reported: $issueData');

                titleController.dispose();
                descController.dispose();
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        '✅ Issue reported successfully! Thank you for helping us improve.'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 3),
                  ),
                );
              },
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
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.logout, color: Colors.red),
            SizedBox(width: 8),
            Text('Logout'),
          ],
        ),
        content: const Text(
          'Are you sure you want to logout?\n\nYour session will end and you\'ll need to login again.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(dialogContext); // Close dialog first

              // Show loading overlay
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (loadingContext) => PopScope(
                  canPop: false,
                  child: const Center(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Logging out...'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );

              try {
                // Sign out through auth provider
                await ref.read(authProvider.notifier).signOut();

                // Small delay to ensure state updates propagate
                await Future.delayed(const Duration(milliseconds: 300));

                // Close loading dialog if still mounted
                if (context.mounted) {
                  Navigator.of(context, rootNavigator: true).pop();
                }

                // Force navigation to login
                if (context.mounted) {
                  context.go('/login');
                }

                debugPrint('✅ Logout completed successfully');
              } catch (e) {
                debugPrint('❌ Logout error: $e');

                // Close loading dialog
                if (context.mounted) {
                  Navigator.of(context, rootNavigator: true).pop();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Logout failed: $e'),
                      backgroundColor: Colors.red,
                      action: SnackBarAction(
                        label: 'Retry',
                        textColor: Colors.white,
                        onPressed: () => _showLogoutDialog(context, ref),
                      ),
                    ),
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
