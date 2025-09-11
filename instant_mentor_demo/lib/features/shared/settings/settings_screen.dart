import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/providers/auth_provider.dart';

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
                    onChanged: (value) {
                      ref.read(pushNotificationsProvider.notifier).state =
                          value;
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.email),
                    title: const Text('Email Notifications'),
                    subtitle: const Text('Get updates via email'),
                    value: ref.watch(emailNotificationsProvider),
                    onChanged: (value) {
                      ref.read(emailNotificationsProvider.notifier).state =
                          value;
                    },
                  ),
                  if (isStudent) ...[
                    const Divider(height: 1),
                    SwitchListTile(
                      secondary: const Icon(Icons.schedule),
                      title: const Text('Study Reminders'),
                      subtitle: const Text('Daily study session reminders'),
                      value: ref.watch(studyRemindersProvider),
                      onChanged: (value) {
                        ref.read(studyRemindersProvider.notifier).state = value;
                      },
                    ),
                  ],
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.event),
                    title: const Text('Session Reminders'),
                    subtitle: const Text('Upcoming session notifications'),
                    value: ref.watch(sessionRemindersProvider),
                    onChanged: (value) {
                      ref.read(sessionRemindersProvider.notifier).state = value;
                    },
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              obscureText: true,
              decoration: InputDecoration(labelText: 'Current Password'),
            ),
            SizedBox(height: 16),
            TextField(
              obscureText: true,
              decoration: InputDecoration(labelText: 'New Password'),
            ),
            SizedBox(height: 16),
            TextField(
              obscureText: true,
              decoration: InputDecoration(labelText: 'Confirm New Password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showSnackBar(context, 'Password changed successfully!');
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
    _showSnackBar(context, 'Availability settings coming soon!');
  }

  void _showPricingSettings(BuildContext context) {
    _showSnackBar(context, 'Pricing settings coming soon!');
  }

  void _showSubjectsSettings(BuildContext context) {
    _showSnackBar(context, 'Subjects settings coming soon!');
  }

  void _showHelpCenter(BuildContext context) {
    _showSnackBar(context, 'Help center coming soon!');
  }

  void _contactSupport(BuildContext context) {
    _showSnackBar(context, 'Contact support coming soon!');
  }

  void _reportIssue(BuildContext context) {
    _showSnackBar(context, 'Report issue coming soon!');
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
                  // Don't manually navigate - let the router's redirect logic handle it
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
              color: const Color(0xFF2563EB).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF2563EB),
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
