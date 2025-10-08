import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/models/user.dart';
import '../../../core/repositories/mentor_repository.dart';
import '../../common/widgets/mentor_presence_widgets.dart';
import '../../payments/payment_checkout_sheet.dart';
// Use the shared/global MentorProfileScreen to ensure a single source of truth
import '../../shared/profile/mentor_profile_screen.dart' as shared_profile;

class FindMentorsScreen extends ConsumerStatefulWidget {
  const FindMentorsScreen({super.key});

  @override
  ConsumerState<FindMentorsScreen> createState() => _FindMentorsScreenState();
}

class _FindMentorsScreenState extends ConsumerState<FindMentorsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  String _selectedSubject = 'All';
  String _selectedExam = 'All';
  String _selectedLanguage = 'All';
  double _maxPrice = 100;
  bool _onlineOnly = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final mentorsAsync = ref.watch(mentorSearchResultsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Mentors'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).colorScheme.onPrimary,
          labelColor: Theme.of(context).colorScheme.onPrimary,
          unselectedLabelColor:
              Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
          tabs: const [
            Tab(text: 'All Mentors'),
            Tab(text: 'Top Rated'),
            Tab(text: 'Available Now'),
          ],
        ),
      ),
      body: mentorsAsync.when(
        data: (mentors) => Column(
          children: [
            // Search and Filters
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Search Bar
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by name, subject, or expertise...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        onPressed: () => _showFilterDialog(),
                        icon: const Icon(Icons.tune),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (value) => setState(() {}),
                  ),

                  const SizedBox(height: 12),

                  // Quick Filters
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip('All Subjects', _selectedSubject == 'All',
                            () {
                          setState(() => _selectedSubject = 'All');
                        }),
                        _FilterChip(
                            'Mathematics', _selectedSubject == 'Mathematics',
                            () {
                          setState(() => _selectedSubject = 'Mathematics');
                        }),
                        _FilterChip('Physics', _selectedSubject == 'Physics',
                            () {
                          setState(() => _selectedSubject = 'Physics');
                        }),
                        _FilterChip(
                            'Chemistry', _selectedSubject == 'Chemistry', () {
                          setState(() => _selectedSubject = 'Chemistry');
                        }),
                        _FilterChip('Available Now', _onlineOnly, () {
                          setState(() => _onlineOnly = !_onlineOnly);
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Real-time Mentor Stats
            const MentorAvailabilityStats(),

            // Mentors List
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildMentorsList(_convertMentorsToMap(mentors)),
                  _buildMentorsList(_getTopRatedMentors(mentors)),
                  _buildMentorsList(_getAvailableMentors(mentors)),
                ],
              ),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Failed to load mentors: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(mentorSearchResultsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMentorsList(List<Map<String, dynamic>> mentors) {
    final filteredMentors = mentors.where((mentor) {
      final matchesSearch = _searchController.text.isEmpty ||
          mentor['name']
              .toString()
              .toLowerCase()
              .contains(_searchController.text.toLowerCase()) ||
          mentor['subjects']
              .toString()
              .toLowerCase()
              .contains(_searchController.text.toLowerCase()) ||
          mentor['expertise']
              .toString()
              .toLowerCase()
              .contains(_searchController.text.toLowerCase());

      final matchesSubject = _selectedSubject == 'All' ||
          mentor['subjects'].toString().contains(_selectedSubject);

      final matchesExam = _selectedExam == 'All' ||
          mentor['expertise']
              .toString()
              .toLowerCase()
              .contains(_selectedExam.toLowerCase()) ||
          mentor['subjects']
              .toString()
              .toLowerCase()
              .contains(_selectedExam.toLowerCase());

      final matchesLanguage = _selectedLanguage == 'All' ||
          mentor['languages'].toString().contains(_selectedLanguage);

      final matchesPrice = mentor['price'] <= _maxPrice;

      final matchesAvailability = !_onlineOnly || mentor['isOnline'] == true;

      return matchesSearch &&
          matchesSubject &&
          matchesExam &&
          matchesLanguage &&
          matchesPrice &&
          matchesAvailability;
    }).toList();

    if (filteredMentors.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No mentors found',
                style: TextStyle(fontSize: 18, color: Colors.grey)),
            SizedBox(height: 8),
            Text('Try adjusting your search criteria',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredMentors.length,
      itemBuilder: (context, index) =>
          _MentorCard(mentor: filteredMentors[index]),
    );
  }

  Widget _FilterChip(String label, bool isSelected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
        selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
        checkmarkColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => FilterDialog(
        selectedExam: _selectedExam,
        selectedLanguage: _selectedLanguage,
        maxPrice: _maxPrice,
        onlineOnly: _onlineOnly,
        onApply: (exam, language, price, online) {
          setState(() {
            _selectedExam = exam;
            _selectedLanguage = language;
            _maxPrice = price;
            _onlineOnly = online;
          });
        },
      ),
    );
  }

  List<Map<String, dynamic>> _getAllMentors(List<Mentor> mentors) {
    return _convertMentorsToMap(mentors);
  }

  List<Map<String, dynamic>> _getTopRatedMentors(List<Mentor> mentors) {
    final mentorMaps = _convertMentorsToMap(mentors);
    return mentorMaps.where((m) => m['rating'] >= 4.8).toList()
      ..sort(
          (a, b) => (b['rating'] as double).compareTo(a['rating'] as double));
  }

  List<Map<String, dynamic>> _getAvailableMentors(List<Mentor> mentors) {
    final mentorMaps = _convertMentorsToMap(mentors);
    return mentorMaps.where((m) => m['isOnline'] == true).toList();
  }

  List<Map<String, dynamic>> _convertMentorsToMap(List<Mentor> mentors) {
    return mentors
        .map((mentor) => {
              'id': mentor.id,
              'name': mentor.name,
              'subjects': mentor.specializations.join(', '),
              'expertise': mentor.qualifications.join(', '),
              'rating': mentor.rating,
              'totalSessions': mentor.totalSessions,
              'experience': '${mentor.yearsOfExperience} years',
              'price': mentor.hourlyRate.toInt(),
              'isOnline': mentor.isAvailable,
              'languages':
                  'English, Hindi', // Default languages since not in Mentor model
              'education': mentor.qualifications.join(', '),
              'bio': mentor.bio,
              'responseTime':
                  '< 2 hours', // Default response time since not in Mentor model
              'achievements': [
                '${mentor.totalSessions} Sessions'
              ], // Default achievements
            })
        .toList();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}

class _MentorCard extends StatelessWidget {
  final Map<String, dynamic> mentor;

  const _MentorCard({required this.mentor});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      child: Text(
                        mentor['name']
                            .toString()
                            .split(' ')
                            .map((n) => n[0])
                            .join(),
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (mentor['isOnline'] == true)
                      Positioned(
                        right: 2,
                        bottom: 2,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mentor['name'].toString(),
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        mentor['education'].toString(),
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.star, color: Colors.amber[600], size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '${mentor['rating']} (${mentor['totalSessions']} sessions)',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${mentor['price']}/hr',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: mentor['isOnline'] == true
                            ? Colors.green.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        mentor['isOnline'] == true ? 'Available' : 'Offline',
                        style: TextStyle(
                          color: mentor['isOnline'] == true
                              ? Colors.green
                              : Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            Text(
              'Subjects: ${mentor['subjects']}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Text(
              'Expertise: ${mentor['expertise']}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            // Replace Flexible (which can conflict with a shrink-wrapped Column)
            // with a constrained text block to avoid layout overflows on small
            // screens while still clamping to two lines.
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 40),
              child: Text(
                mentor['bio'].toString(),
                style: TextStyle(color: Colors.grey[700]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            const SizedBox(height: 12),

            // Achievements
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children:
                  (mentor['achievements'] as List<String>).map((achievement) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    achievement,
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 12),

            // Use Column layout for small screens to prevent overflow
            Column(
              children: [
                // Info row with response time and languages
                Row(
                  children: [
                    Icon(Icons.schedule, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Responds ${mentor['responseTime']}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.language, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        mentor['languages'].toString(),
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Buttons row
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => _viewProfile(context, mentor),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      child: const Text('View Profile',
                          style: TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: mentor['isOnline'] == true
                          ? () => _bookSession(context, mentor)
                          : null,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      child: Text(
                        mentor['isOnline'] == true ? 'Book Now' : 'Schedule',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _viewProfile(BuildContext context, Map<String, dynamic> mentor) {
    // Navigate to the shared MentorProfileScreen by id so the global lookup
    // logic is used (prevents mismatches between multiple local/global screens).
    final id = (mentor['id'] ?? mentor['name']).toString();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => shared_profile.MentorProfileScreen(mentorId: id),
      ),
    );
  }

  void _bookSession(BuildContext context, Map<String, dynamic> mentor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Book Session with ${mentor['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rate: ₹${mentor['price']}/hour'),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Duration'),
              items: [
                DropdownMenuItem(
                    value: '30',
                    child:
                        Text('30 minutes - ₹${(mentor['price'] / 2).toInt()}')),
                DropdownMenuItem(
                    value: '60', child: Text('1 hour - ₹${mentor['price']}')),
                DropdownMenuItem(
                    value: '90',
                    child: Text(
                        '1.5 hours - ₹${(mentor['price'] * 1.5).toInt()}')),
              ],
              onChanged: (value) {},
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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Session booked with ${mentor['name']}!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Book Now'),
          ),
        ],
      ),
    );
  }
}

class InlineMentorProfileScreen extends StatelessWidget {
  final Map<String, dynamic> mentor;

  const InlineMentorProfileScreen({super.key, required this.mentor});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(mentor['name'].toString()),
        actions: [
          IconButton(
            onPressed: () => _shareProfile(context, mentor),
            icon: const Icon(Icons.share),
          ),
          IconButton(
            onPressed: () => _toggleFavorite(context, mentor),
            icon: const Icon(Icons.favorite_border),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header
            Row(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  child: Text(
                    mentor['name']
                        .toString()
                        .split(' ')
                        .map((n) => n[0])
                        .join(),
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mentor['name'].toString(),
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        mentor['education'].toString(),
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.star, color: Colors.amber[600], size: 20),
                          const SizedBox(width: 4),
                          Text(
                              '${mentor['rating']} • ${mentor['totalSessions']} sessions'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '₹${mentor['price']}/hour',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // About Section
            const Text('About',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(mentor['bio'].toString()),

            const SizedBox(height: 20),

            // Details
            _DetailRow('Experience', mentor['experience'].toString()),
            _DetailRow('Subjects', mentor['subjects'].toString()),
            _DetailRow('Expertise', mentor['expertise'].toString()),
            _DetailRow('Languages', mentor['languages'].toString()),
            _DetailRow('Response Time', mentor['responseTime'].toString()),

            const SizedBox(height: 20),

            // Achievements
            const Text('Achievements',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  (mentor['achievements'] as List<String>).map((achievement) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue
                        .withOpacity(0.1), // Light blue instead of dark
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: Colors.blue.withOpacity(
                            0.3)), // Add border for better visibility
                  ),
                  child: Text(
                    achievement,
                    style: const TextStyle(
                      color: Colors.black87, // Dark text for better contrast
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 32),

            // Action Buttons
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: mentor['isOnline'] == true
                    ? () => _bookSessionFromProfile(context, mentor)
                    : () => _scheduleSession(context, mentor),
                icon: const Icon(Icons.book_online),
                label: Text(mentor['isOnline'] == true
                    ? 'Book Session Now'
                    : 'Schedule Session'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _sendMessage(context, mentor),
                icon: const Icon(Icons.chat),
                label: const Text('Send Message'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _shareProfile(BuildContext context, Map<String, dynamic> mentor) {
    final id = mentor['id'] ?? mentor['name'];
    final link = 'https://instantmentor.app/mentor/$id';
    Share.share('Check out mentor ${mentor['name']} on InstantMentor: $link');
  }

  void _toggleFavorite(BuildContext context, Map<String, dynamic> mentor) {
    // Toggle favorite status
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${mentor['name']} added to favorites!'),
        backgroundColor: Colors.red,
        action: SnackBarAction(
          label: 'View Favorites',
          onPressed: () {
            // Navigate to favorites screen
          },
        ),
      ),
    );
  }

  void _bookSessionFromProfile(
      BuildContext context, Map<String, dynamic> mentor) {
    // Show booking dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Book Session with ${mentor['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rate: ₹${mentor['price']}/hour'),
            const SizedBox(height: 16),
            const Text('Select Duration:'),
            const SizedBox(height: 8),
            Column(
              children: [
                ListTile(
                  title: Text('30 minutes - ₹${(mentor['price'] / 2).toInt()}'),
                  leading: Radio<int>(
                    value: 30,
                    groupValue: 60,
                    onChanged: (value) {},
                  ),
                ),
                ListTile(
                  title: Text('1 hour - ₹${mentor['price']}'),
                  leading: Radio<int>(
                    value: 60,
                    groupValue: 60,
                    onChanged: (value) {},
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          // Show Instant Call button only for available mentors
          if (mentor['isOnline'] == true)
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _startInstantCall(context, mentor);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Instant Call'),
            ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Session booked with ${mentor['name']}!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Book Now'),
          ),
        ],
      ),
    );
  }

  void _scheduleSession(BuildContext context, Map<String, dynamic> mentor) {
    // Show scheduling dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Schedule Session with ${mentor['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('This mentor is currently offline.'),
            const SizedBox(height: 16),
            const Text(
                'You can schedule a session for when they become available.'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Schedule feature coming soon!'),
                    backgroundColor: Colors.orange,
                  ),
                );
              },
              child: const Text('Schedule for Later'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _sendMessage(BuildContext context, Map<String, dynamic> mentor) {
    // Show message dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Send Message to ${mentor['name']}'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: 'Your Message',
                hintText: 'Type your message here...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            SizedBox(height: 16),
            Text(
              'This will start a new chat conversation with the mentor.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Message sent to ${mentor['name']}!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _startInstantCall(BuildContext context, Map<String, dynamic> mentor) {
    // First show payment page, then proceed to video call
    _showPaymentSheet(context, mentor);
  }

  void _showPaymentSheet(BuildContext context, Map<String, dynamic> mentor) {
    final double hourlyRate = (mentor['price'] as num).toDouble();
    const int minutes = 30; // Default 30-minute session
    final double amount =
        (hourlyRate / 60) * minutes; // Prorated for 30 minutes

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: PaymentCheckoutSheet(
          mentorName: mentor['name'],
          hourlyRate: hourlyRate,
          minutes: minutes,
          amount: amount,
          onConfirm: () {
            _processPaymentAndStartCall(context, mentor, amount);
          },
        ),
      ),
    );
  }

  void _processPaymentAndStartCall(
      BuildContext context, Map<String, dynamic> mentor, double amount) async {
    try {
      // Show payment processing indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Processing payment of ₹${amount.toStringAsFixed(2)}...'),
              const SizedBox(height: 8),
              const Text(
                'Demo mode - payment simulation',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      );

      // Simulate payment processing with more realistic timing
      await Future.delayed(const Duration(seconds: 3));

      // Close payment processing dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Show payment success dialog
      if (context.mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Payment Successful!'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Amount: ₹${amount.toStringAsFixed(2)}'),
                Text('Mentor: ${mentor['name']}'),
                const Text('Session: 30 minutes'),
                const SizedBox(height: 16),
                const Text('Starting video call...'),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Continue'),
              ),
            ],
          ),
        );
      }

      // Navigate to live session screen for instant video call
      if (context.mounted) {
        Navigator.pushNamed(
          context,
          '/live-session',
          arguments: {
            'sessionId':
                'instant_${mentor['id']}_${DateTime.now().millisecondsSinceEpoch}',
            'mentorId': mentor['id'],
            'mentorName': mentor['name'],
            'isInstantCall': true,
            'amount': amount,
            'paymentStatus': 'paid',
            'sessionDuration': 30, // minutes
          },
        );

        // Show success snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎥 Video call started with ${mentor['name']}!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'View',
              textColor: Colors.white,
              onPressed: () {
                // Additional action if needed
              },
            ),
          ),
        );
      }
    } catch (e) {
      // Close payment processing dialog if still open
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Show error message
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error, color: Colors.red),
                SizedBox(width: 8),
                Text('Payment Failed'),
              ],
            ),
            content: Text(
                'Error: ${e.toString()}\n\nPlease try again or contact support.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class FilterDialog extends StatefulWidget {
  final String selectedExam;
  final String selectedLanguage;
  final double maxPrice;
  final bool onlineOnly;
  final Function(String, String, double, bool) onApply;

  const FilterDialog({
    super.key,
    required this.selectedExam,
    required this.selectedLanguage,
    required this.maxPrice,
    required this.onlineOnly,
    required this.onApply,
  });

  @override
  State<FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<FilterDialog> {
  late String _selectedExam;
  late String _selectedLanguage;
  late double _maxPrice;
  late bool _onlineOnly;

  @override
  void initState() {
    super.initState();
    _selectedExam = widget.selectedExam;
    _selectedLanguage = widget.selectedLanguage;
    _maxPrice = widget.maxPrice;
    _onlineOnly = widget.onlineOnly;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Advanced Filters'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _selectedExam,
              decoration: const InputDecoration(labelText: 'Exam Preparation'),
              items: ['All', 'JEE', 'NEET', 'IELTS', 'SAT', 'GMAT']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedExam = value);
                }
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedLanguage,
              decoration: const InputDecoration(labelText: 'Teaching Language'),
              items: ['All', 'English', 'Hindi', 'Tamil', 'Telugu', 'Bengali']
                  .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedLanguage = value);
                }
              },
            ),
            const SizedBox(height: 16),
            Text('Maximum Price: ₹${_maxPrice.toInt()}/hour'),
            Slider(
              value: _maxPrice,
              min: 10,
              max: 200,
              divisions: 19,
              onChanged: (value) => setState(() => _maxPrice = value),
            ),
            CheckboxListTile(
              title: const Text('Show only available mentors'),
              value: _onlineOnly,
              onChanged: (value) {
                if (value != null) {
                  setState(() => _onlineOnly = value);
                }
              },
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            setState(() {
              _selectedExam = 'All';
              _selectedLanguage = 'All';
              _maxPrice = 100;
              _onlineOnly = false;
            });
          },
          child: const Text('Reset'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onApply(
                _selectedExam, _selectedLanguage, _maxPrice, _onlineOnly);
            Navigator.pop(context);
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
