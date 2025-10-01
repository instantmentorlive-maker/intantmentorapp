import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/user.dart' as domain;
import '../../../core/providers/mentor_provider.dart';
import '../../../core/providers/sessions_provider.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/routing/routing.dart';
import '../../../core/services/payment_service.dart';

final selectedExamProvider = StateProvider<String?>((ref) => null);
final selectedSubjectProvider = StateProvider<String?>((ref) => null);

class BookSessionScreen extends ConsumerWidget {
  const BookSessionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mentors = ref.watch(mentorsProvider);
    final selectedExam = ref.watch(selectedExamProvider);
    final selectedSubject = ref.watch(selectedSubjectProvider);

    // Filter mentors based on selection
    final filteredMentors = mentors.where((mentor) {
      if (selectedExam != null &&
          !mentor.specializations.contains(selectedExam)) {
        return false;
      }
      if (selectedSubject != null &&
          !mentor.specializations.any((spec) =>
              spec.toLowerCase().contains(selectedSubject.toLowerCase()))) {
        return false;
      }
      return true;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filters Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Filters',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedExam,
                          decoration: const InputDecoration(
                            labelText: 'Exam',
                            prefixIcon: Icon(Icons.school),
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(child: Text('All Exams')),
                            DropdownMenuItem(value: 'JEE', child: Text('JEE')),
                            DropdownMenuItem(
                                value: 'NEET', child: Text('NEET')),
                            DropdownMenuItem(
                                value: 'IELTS', child: Text('IELTS')),
                          ],
                          onChanged: (value) {
                            ref.read(selectedExamProvider.notifier).state =
                                value;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedSubject,
                          decoration: const InputDecoration(
                            labelText: 'Subject',
                            prefixIcon: Icon(Icons.book),
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(child: Text('All Subjects')),
                            DropdownMenuItem(
                                value: 'Mathematics',
                                child: Text('Mathematics')),
                            DropdownMenuItem(
                                value: 'Physics', child: Text('Physics')),
                            DropdownMenuItem(
                                value: 'Chemistry', child: Text('Chemistry')),
                            DropdownMenuItem(
                                value: 'Biology', child: Text('Biology')),
                            DropdownMenuItem(
                                value: 'English', child: Text('English')),
                          ],
                          onChanged: (value) {
                            ref.read(selectedSubjectProvider.notifier).state =
                                value;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (selectedExam != null || selectedSubject != null)
                    TextButton.icon(
                      onPressed: () {
                        ref.read(selectedExamProvider.notifier).state = null;
                        ref.read(selectedSubjectProvider.notifier).state = null;
                      },
                      icon: const Icon(Icons.clear),
                      label: const Text('Clear Filters'),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Results header
          Text('Available Mentors (${filteredMentors.length})',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          // Mentors List
          if (filteredMentors.isEmpty)
            const Center(
              child: Column(
                children: [
                  SizedBox(height: 50),
                  Icon(Icons.search_off, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No mentors found',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  Text(
                    'Try adjusting your filters',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          else
            ...filteredMentors.map((mentor) {
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    child: Text(mentor.name.split(' ').map((n) => n[0]).join()),
                  ),
                  title: Text(mentor.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(mentor.specializations.join(', ')),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.star, size: 16, color: Colors.amber[600]),
                          Text(' ${mentor.rating} • '),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: mentor.isAvailable
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              mentor.isAvailable ? 'Available' : 'Busy',
                              style: TextStyle(
                                color: mentor.isAvailable
                                    ? Colors.green
                                    : Colors.red,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '\$${mentor.hourlyRate}/hr',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () =>
                                context.go(AppRoutes.mentorProfile(mentor.id)),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(50, 30),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            child: const Text('View',
                                style: TextStyle(fontSize: 12)),
                          ),
                          const SizedBox(width: 4),
                          ElevatedButton(
                            onPressed: mentor.isAvailable
                                ? () => _showBookingDialog(context, mentor)
                                : null,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(60, 30),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            child: const Text('Book',
                                style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  isThreeLine: true,
                ),
              );
            }),
        ],
      ),
    );
  }

  void _showBookingDialog(BuildContext context, domain.Mentor mentor) {
    showDialog(
      context: context,
      builder: (context) => BookingDialog(mentor: mentor),
    );
  }
}

class BookingDialog extends ConsumerStatefulWidget {
  final domain.Mentor mentor;

  const BookingDialog({super.key, required this.mentor});

  @override
  ConsumerState<BookingDialog> createState() => _BookingDialogState();
}

class _BookingDialogState extends ConsumerState<BookingDialog> {
  String? selectedDuration;
  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  final messageController = TextEditingController();
  bool _isProcessingInstantCall = false;

  @override
  Widget build(BuildContext context) {
    final price = _calculatePrice();

    return AlertDialog(
      title: Text('Book Session with ${widget.mentor.name}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Subject: ${widget.mentor.specializations.first}'),
            Text('Rate: \$${widget.mentor.hourlyRate}/hour'),
            const SizedBox(height: 16),

            // Duration Selection
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Duration',
                border: OutlineInputBorder(),
              ),
              initialValue: selectedDuration,
              items: [
                DropdownMenuItem(
                  value: '30',
                  child: Text(
                      '30 minutes - \$${(widget.mentor.hourlyRate * 0.5).toStringAsFixed(2)}'),
                ),
                DropdownMenuItem(
                  value: '60',
                  child: Text(
                      '1 hour - \$${widget.mentor.hourlyRate.toStringAsFixed(2)}'),
                ),
                DropdownMenuItem(
                  value: '90',
                  child: Text(
                      '1.5 hours - \$${(widget.mentor.hourlyRate * 1.5).toStringAsFixed(2)}'),
                ),
              ],
              onChanged: (value) => setState(() => selectedDuration = value),
            ),

            const SizedBox(height: 16),

            // Date Selection
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: Text(selectedDate == null
                  ? 'Select Date'
                  : 'Date: ${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}'),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().add(const Duration(hours: 1)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 30)),
                );
                if (date != null) {
                  setState(() => selectedDate = date);
                }
              },
            ),

            // Time Selection
            ListTile(
              leading: const Icon(Icons.access_time),
              title: Text(selectedTime == null
                  ? 'Select Time'
                  : 'Time: ${selectedTime!.format(context)}'),
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                );
                if (time != null) {
                  setState(() => selectedTime = time);
                }
              },
            ),

            const SizedBox(height: 16),

            // Message
            TextField(
              controller: messageController,
              decoration: const InputDecoration(
                labelText: 'Message (Optional)',
                hintText: 'Tell the mentor what you need help with...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),

            const SizedBox(height: 16),

            if (price > 0)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Amount:',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '\$${price.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
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
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (widget.mentor.isAvailable)
          ElevatedButton(
            onPressed: _isProcessingInstantCall
                ? null
                : () => _startInstantCall(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.secondary,
            ),
            child: _isProcessingInstantCall
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Instant Call'),
          ),
        ElevatedButton(
          onPressed: _canBook() ? () => _bookSession(context, ref) : null,
          child: const Text('Book Session'),
        ),
      ],
    );
  }

  double _calculatePrice() {
    if (selectedDuration == null) return 0;

    final duration =
        int.parse(selectedDuration!) / 60; // Convert minutes to hours
    return widget.mentor.hourlyRate * duration;
  }

  bool _canBook() {
    return selectedDuration != null &&
        selectedDate != null &&
        selectedTime != null;
  }

  void _bookSession(BuildContext context, WidgetRef ref) async {
    if (!_canBook()) return;

    try {
      // Get the current user and session service
      final user = ref.read(userProvider);
      final sessionService = ref.read(sessionServiceProvider);

      // For demo purposes, create a demo user if none exists
      final demoUser = user ??
          domain.User(
            id: 'demo_student_${DateTime.now().millisecondsSinceEpoch}',
            name: 'Demo Student',
            email: 'demo@student.com',
            role: domain.UserRole.student,
            createdAt: DateTime.now(),
          );

      // Calculate scheduled date/time
      final scheduledDateTime = DateTime(
        selectedDate!.year,
        selectedDate!.month,
        selectedDate!.day,
        selectedTime!.hour,
        selectedTime!.minute,
      );

      // Create the session in database
      final session = await sessionService.createSession(
        mentorId: widget.mentor.id,
        studentId: demoUser.id,
        scheduledTime: scheduledDateTime,
        durationMinutes: int.parse(selectedDuration!),
        amount: _calculatePrice(),
        subject: 'General', // Default subject for now
        notes: messageController.text.isEmpty ? null : messageController.text,
      );

      // Debug: log which mentor we attempted to book
      print(
          'Booking attempt - mentorId: ${widget.mentor.id}, mentorName: ${widget.mentor.name}');

      if (session != null) {
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Session booked with ${widget.mentor.name}!'),
                Text(
                    '${selectedDate!.day}/${selectedDate!.month} at ${selectedTime!.format(context)}'),
                Text('Amount: \$${_calculatePrice().toStringAsFixed(2)}'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate back to home
        context.go(AppRoutes.studentHome);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to book session. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error booking session: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _startInstantCall(BuildContext context) async {
    setState(() => _isProcessingInstantCall = true);

    try {
      // Determine charge amount: use selected duration if chosen else default 30 minutes
      final durationMinutes = selectedDuration != null
          ? int.tryParse(selectedDuration!) ?? 30
          : 30; // default 30 min
      final amount = (widget.mentor.hourlyRate / 60) * durationMinutes;

      // Create a pseudo session id for instant call
      final sessionId = 'instant_${DateTime.now().millisecondsSinceEpoch}';

      // Setup payment sheet
      final setupOk = await PaymentService.instance.setupPaymentSheet(
        sessionId: sessionId,
        amount: double.parse(amount.toStringAsFixed(2)),
      );

      if (!setupOk) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to prepare payment. Try again.')),
        );
        setState(() => _isProcessingInstantCall = false);
        return;
      }

      // Present payment sheet
      final result =
          await PaymentService.instance.presentPaymentSheet(sessionId);

      if (!mounted) return;

      if (result.isSuccess) {
        // Close dialog first
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Payment successful. Starting call with ${widget.mentor.name}...'),
            backgroundColor: Colors.green,
          ),
        );
        // Navigate to session screen (live session) – this screen can auto-start call or user can initiate
        context.go(AppRoutes.session(sessionId));
      } else if (result.isCancelled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment cancelled.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.error ?? 'Payment failed')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Instant call failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessingInstantCall = false);
      }
    }
  }

  @override
  void dispose() {
    messageController.dispose();
    super.dispose();
  }
}
