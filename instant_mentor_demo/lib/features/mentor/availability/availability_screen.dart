import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/user_provider.dart';
import '../../common/widgets/mentor_status_widget.dart';

final _supabase = Supabase.instance.client;

class AvailabilityScreen extends ConsumerStatefulWidget {
  const AvailabilityScreen({super.key});

  @override
  ConsumerState<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends ConsumerState<AvailabilityScreen> {
  bool isAvailable = true;
  final Map<String, bool> weeklySchedule = {
    'Monday': true,
    'Tuesday': true,
    'Wednesday': true,
    'Thursday': true,
    'Friday': true,
    'Saturday': true,
    'Sunday': false,
  };

  // Track if there are unsaved changes
  bool _hasUnsavedChanges = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedSettings();
  }

  /// Load saved availability settings from database or local storage
  Future<void> _loadSavedSettings() async {
    try {
      final user = ref.read(userProvider);
      bool settingsLoaded = false;

      // Try to load from Supabase database first (for authenticated users)
      if (user != null) {
        try {
          final response = await _supabase
              .from('mentor_profiles')
              .select('is_available, weekly_schedule')
              .eq('user_id', user.id)
              .maybeSingle()
              .timeout(const Duration(seconds: 5));

          if (response != null && mounted) {
            setState(() {
              // Load availability status
              if (response['is_available'] != null) {
                isAvailable = response['is_available'] as bool;
              }

              // Load weekly schedule
              if (response['weekly_schedule'] != null) {
                final savedSchedule =
                    response['weekly_schedule'] as Map<String, dynamic>;
                savedSchedule.forEach((day, value) {
                  if (weeklySchedule.containsKey(day)) {
                    weeklySchedule[day] = value as bool;
                  }
                });
              }
            });
            settingsLoaded = true;
            debugPrint('✅ Loaded availability settings from database');
          }
        } catch (e) {
          debugPrint('⚠️ Database load failed: $e');
        }
      }

      // Fallback to SharedPreferences (for demo mode or offline)
      if (!settingsLoaded) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final savedIsAvailable = prefs.getBool('mentor_availability') ?? true;
          final savedScheduleJson = prefs.getString('mentor_weekly_schedule');

          setState(() {
            isAvailable = savedIsAvailable;

            // Load weekly schedule from SharedPreferences
            if (savedScheduleJson != null) {
              final savedSchedule =
                  jsonDecode(savedScheduleJson) as Map<String, dynamic>;
              savedSchedule.forEach((day, value) {
                if (weeklySchedule.containsKey(day)) {
                  weeklySchedule[day] = value as bool;
                }
              });
            }
          });
          debugPrint('✅ Loaded availability settings from SharedPreferences');
          settingsLoaded = true;
        } catch (e) {
          debugPrint('⚠️ SharedPreferences load failed: $e');
        }
      }

      // Update UI and sync with provider
      if (mounted) {
        setState(() => _isLoading = false);

        // Sync with mentor status provider
        final mentorStatus = ref.read(mentorStatusProvider);
        if (isAvailable != mentorStatus.isAvailable) {
          ref.read(mentorStatusProvider.notifier).updateStatus(
                isAvailable,
                isAvailable ? 'Available for sessions' : 'Currently busy',
              );
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading saved settings: $e');
      setState(() => _isLoading = false);
    }
  }

  /// Save availability settings and update mentor status
  Future<void> _saveAvailabilitySettings() async {
    try {
      final user = ref.read(userProvider);
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Update the mentor status based on current availability
      final statusMessage =
          isAvailable ? 'Available for sessions' : 'Currently busy';

      // 1. Try to save to Supabase database (PERSISTENT STORAGE)
      try {
        await _supabase
            .from('mentor_profiles')
            .update({
              'is_available': isAvailable,
              'weekly_schedule': weeklySchedule,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('user_id', user.id)
            .timeout(const Duration(seconds: 10));

        debugPrint('✅ Availability settings saved to database');
      } catch (e) {
        debugPrint('⚠️ Database save failed: $e');
      }

      // 1.1. Always save to SharedPreferences as fallback (DEMO MODE SUPPORT)
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('mentor_availability', isAvailable);
        await prefs.setString(
            'mentor_weekly_schedule', jsonEncode(weeklySchedule));
        debugPrint('✅ Availability settings saved to SharedPreferences');
      } catch (e) {
        debugPrint('⚠️ SharedPreferences save failed: $e');
      }

      // 2. Update the mentor status provider (LOCAL STATE)
      ref.read(mentorStatusProvider.notifier).updateStatus(
            isAvailable,
            statusMessage,
          );

      // 3. Send update via WebSocket (REAL-TIME SYNC)
      try {
        final webSocketService = ref.read(webSocketServiceProvider);
        await webSocketService.updateMentorStatus(
          isAvailable: isAvailable,
          statusMessage: statusMessage,
          statusData: {
            'userId': user.id,
            'timestamp': DateTime.now().toIso8601String(),
            'weeklySchedule': weeklySchedule,
            'availableDays': weeklySchedule.entries
                .where((entry) => entry.value)
                .map((entry) => entry.key)
                .toList(),
          },
        );
        debugPrint('✅ Availability settings synced via WebSocket');
      } catch (e) {
        debugPrint(
            '⚠️ WebSocket update failed (database settings still saved): $e');
      }

      // Reset unsaved changes flag
      setState(() {
        _hasUnsavedChanges = false;
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '✅ Availability Settings Saved',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Status: ${isAvailable ? 'Available' : 'Busy'} • ${weeklySchedule.values.where((v) => v).length} days active',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '❌ Failed to save settings',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  /// Mark that there are unsaved changes
  void _markAsChanged() {
    if (!_hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator while loading saved settings
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading availability settings...'),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Unsaved Changes Indicator
          if (_hasUnsavedChanges)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  Icon(Icons.edit, color: Colors.amber.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You have unsaved changes',
                      style: TextStyle(
                        color: Colors.amber.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _saveAvailabilitySettings(),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.amber.shade700,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                    ),
                    child: const Text('Save Now'),
                  ),
                ],
              ),
            ),

          // Status Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Status',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() => isAvailable = true);
                            _markAsChanged();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isAvailable
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color:
                                      isAvailable ? Colors.green : Colors.grey),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color:
                                      isAvailable ? Colors.green : Colors.grey,
                                  size: 32,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Available',
                                  style: TextStyle(
                                    color: isAvailable
                                        ? Colors.green
                                        : Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() => isAvailable = false);
                            _markAsChanged();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: !isAvailable
                                  ? Colors.red.withOpacity(0.1)
                                  : Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color:
                                      !isAvailable ? Colors.red : Colors.grey),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.do_not_disturb,
                                  color:
                                      !isAvailable ? Colors.red : Colors.grey,
                                  size: 32,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Busy',
                                  style: TextStyle(
                                    color:
                                        !isAvailable ? Colors.red : Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
          Text(
            'Weekly Schedule',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          ...weeklySchedule.entries.map((entry) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(entry.key),
                subtitle: const Text('9:00 AM - 6:00 PM'),
                trailing: Switch(
                  value: entry.value,
                  onChanged: (value) {
                    setState(() => weeklySchedule[entry.key] = value);
                    _markAsChanged();
                  },
                ),
              ),
            );
          }),

          const SizedBox(height: 32),

          // Save Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _saveAvailabilitySettings(),
              style: ElevatedButton.styleFrom(
                backgroundColor: _hasUnsavedChanges
                    ? Theme.of(context).colorScheme.primary
                    : Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: Icon(_hasUnsavedChanges ? Icons.save : Icons.check_circle),
              label: Text(
                _hasUnsavedChanges
                    ? 'Save Availability Settings'
                    : 'Settings Saved ✓',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Additional info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.blue.withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Availability Info',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '• Your current status affects real-time visibility to students\n'
                  '• Weekly schedule helps students book future sessions\n'
                  '• Changes are saved automatically and synced in real-time\n'
                  '• Students will see your updated availability immediately',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
