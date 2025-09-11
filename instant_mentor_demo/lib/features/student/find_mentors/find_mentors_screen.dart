import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../common/widgets/mentor_presence_widgets.dart';
import '../../../core/providers/mentor_presence_provider.dart';
import '../../../core/models/user.dart';

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
      body: Column(
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
                          'Mathematics', _selectedSubject == 'Mathematics', () {
                        setState(() => _selectedSubject = 'Mathematics');
                      }),
                      _FilterChip('Physics', _selectedSubject == 'Physics', () {
                        setState(() => _selectedSubject = 'Physics');
                      }),
                      _FilterChip('Chemistry', _selectedSubject == 'Chemistry',
                          () {
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
                _buildMentorsList(_getAllMentors()),
                _buildMentorsList(_getTopRatedMentors()),
                _buildMentorsList(_getAvailableMentors()),
              ],
            ),
          ),
        ],
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

      final matchesAvailability = !_onlineOnly || mentor['isOnline'] == true;

      return matchesSearch && matchesSubject && matchesAvailability;
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
      builder: (context) => AlertDialog(
        title: const Text('Advanced Filters'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _selectedExam,
                decoration:
                    const InputDecoration(labelText: 'Exam Preparation'),
                items: ['All', 'JEE', 'NEET', 'IELTS', 'SAT', 'GMAT']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (value) => setState(() => _selectedExam = value!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedLanguage,
                decoration:
                    const InputDecoration(labelText: 'Teaching Language'),
                items: ['All', 'English', 'Hindi', 'Tamil', 'Telugu', 'Bengali']
                    .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                    .toList(),
                onChanged: (value) =>
                    setState(() => _selectedLanguage = value!),
              ),
              const SizedBox(height: 16),
              Text('Maximum Price: \$${_maxPrice.toInt()}/hour'),
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
                onChanged: (value) => setState(() => _onlineOnly = value!),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _selectedSubject = 'All';
                _selectedExam = 'All';
                _selectedLanguage = 'All';
                _maxPrice = 100;
                _onlineOnly = false;
              });
              Navigator.pop(context);
            },
            child: const Text('Reset'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getAllMentors() {
    return [
      {
        'id': '1',
        'name': 'Dr. Sarah Smith',
        'subjects': 'Mathematics, Statistics',
        'expertise': 'Calculus, Linear Algebra, JEE Math',
        'rating': 4.9,
        'totalSessions': 1250,
        'experience': '8 years',
        'price': 55,
        'isOnline': true,
        'languages': 'English, Hindi',
        'education': 'PhD Mathematics - MIT',
        'bio':
            'Passionate mathematics teacher with expertise in advanced calculus and competitive exam preparation.',
        'responseTime': '< 2 hours',
        'achievements': ['Top Performer', 'JEE Expert', '1000+ Sessions'],
      },
      {
        'id': '2',
        'name': 'Prof. Raj Kumar',
        'subjects': 'Physics, Engineering',
        'expertise': 'Quantum Physics, Mechanics, NEET Physics',
        'rating': 4.8,
        'totalSessions': 980,
        'experience': '12 years',
        'price': 48,
        'isOnline': false,
        'languages': 'English, Hindi, Tamil',
        'education': 'PhD Physics - IIT Delhi',
        'bio':
            'Former IIT professor specializing in conceptual physics and problem-solving techniques.',
        'responseTime': '< 4 hours',
        'achievements': ['NEET Expert', 'IIT Faculty', 'Physics Guru'],
      },
      {
        'id': '3',
        'name': 'Dr. Priya Sharma',
        'subjects': 'Chemistry, Biochemistry',
        'expertise': 'Organic Chemistry, NEET Chemistry, Lab Techniques',
        'rating': 4.7,
        'totalSessions': 750,
        'experience': '6 years',
        'price': 42,
        'isOnline': true,
        'languages': 'English, Hindi',
        'education': 'PhD Chemistry - Delhi University',
        'bio':
            'Chemistry expert with focus on organic chemistry and practical applications.',
        'responseTime': '< 3 hours',
        'achievements': [
          'Organic Chemistry Expert',
          'Lab Specialist',
          'NEET Guide'
        ],
      },
      {
        'id': '4',
        'name': 'Mr. Vikash Singh',
        'subjects': 'English, Literature',
        'expertise': 'Grammar, Writing, IELTS, Creative Writing',
        'rating': 4.6,
        'totalSessions': 650,
        'experience': '5 years',
        'price': 35,
        'isOnline': true,
        'languages': 'English, Hindi',
        'education': 'MA English Literature - JNU',
        'bio':
            'English language expert specializing in grammar, writing skills, and test preparation.',
        'responseTime': '< 1 hour',
        'achievements': ['IELTS Expert', 'Writing Mentor', 'Grammar Guru'],
      },
      {
        'id': '5',
        'name': 'Dr. Anjali Gupta',
        'subjects': 'Biology, Life Sciences',
        'expertise': 'Cell Biology, Genetics, NEET Biology',
        'rating': 4.9,
        'totalSessions': 1100,
        'experience': '10 years',
        'price': 50,
        'isOnline': true,
        'languages': 'English, Hindi',
        'education': 'PhD Biology - AIIMS',
        'bio':
            'Medical researcher and educator with expertise in life sciences and medical entrance preparation.',
        'responseTime': '< 2 hours',
        'achievements': [
          'Medical Expert',
          'Research Scholar',
          'NEET Topper Mentor'
        ],
      },
    ];
  }

  List<Map<String, dynamic>> _getTopRatedMentors() {
    return _getAllMentors().where((m) => m['rating'] >= 4.8).toList()
      ..sort(
          (a, b) => (b['rating'] as double).compareTo(a['rating'] as double));
  }

  List<Map<String, dynamic>> _getAvailableMentors() {
    return _getAllMentors().where((m) => m['isOnline'] == true).toList();
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
                      '\$${mentor['price']}/hr',
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
            Text(
              mentor['bio'].toString(),
              style: TextStyle(color: Colors.grey[700]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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

            Row(
              children: [
                Icon(Icons.schedule, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'Responds ${mentor['responseTime']}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(width: 16),
                Icon(Icons.language, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  mentor['languages'].toString(),
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const Spacer(),
                Row(
                  mainAxisSize: MainAxisSize.min,
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MentorProfileScreen(mentor: mentor),
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
            Text('Rate: \$${mentor['price']}/hour'),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Duration'),
              items: [
                DropdownMenuItem(
                    value: '30',
                    child: Text(
                        '30 minutes - \$${(mentor['price'] / 2).toInt()}')),
                DropdownMenuItem(
                    value: '60', child: Text('1 hour - \$${mentor['price']}')),
                DropdownMenuItem(
                    value: '90',
                    child: Text(
                        '1.5 hours - \$${(mentor['price'] * 1.5).toInt()}')),
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

class MentorProfileScreen extends StatelessWidget {
  final Map<String, dynamic> mentor;

  const MentorProfileScreen({super.key, required this.mentor});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(mentor['name'].toString()),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.share)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.favorite_border)),
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
                        '\$${mentor['price']}/hour',
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
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(achievement),
                );
              }).toList(),
            ),

            const SizedBox(height: 32),

            // Action Buttons
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: mentor['isOnline'] == true ? () {} : null,
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
                onPressed: () {},
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
