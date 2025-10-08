import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpSupportScreen extends ConsumerWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
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
            // FAQ Section
            _buildSectionHeader(
                'Frequently Asked Questions', Icons.help_outline),
            const SizedBox(height: 8),
            Card(
              color: Colors.white,
              child: Column(
                children: [
                  _buildFAQTile(
                    'How do I book a mentoring session?',
                    'Browse mentors, select one, choose an available time slot, and confirm your booking. You\'ll receive a confirmation email with session details.',
                  ),
                  const Divider(height: 1),
                  _buildFAQTile(
                    'How do I join a video call?',
                    'Go to your scheduled sessions and click "Join Call" when the session time arrives. Make sure you have a stable internet connection.',
                  ),
                  const Divider(height: 1),
                  _buildFAQTile(
                    'What if I need to cancel a session?',
                    'You can cancel up to 24 hours before the session starts. Go to "My Sessions" and click "Cancel" next to the session.',
                  ),
                  const Divider(height: 1),
                  _buildFAQTile(
                    'How do payments work?',
                    'Payments are processed securely after session completion. You can add payment methods in Settings > Payment Methods.',
                  ),
                  const Divider(height: 1),
                  _buildFAQTile(
                    'How do I become a mentor?',
                    'Create an account, select "Mentor" during signup, complete your profile with qualifications, and wait for approval.',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Contact Support Section
            _buildSectionHeader('Contact Support', Icons.support_agent),
            const SizedBox(height: 8),
            Card(
              color: Colors.white,
              child: Column(
                children: [
                  _buildContactTile(
                    'Email Support',
                    'Get help via email',
                    Icons.email,
                    () => _launchEmail('support@instantmentor.com'),
                  ),
                  const Divider(height: 1),
                  _buildContactTile(
                    'Live Chat',
                    'Chat with our support team',
                    Icons.chat,
                    () => _showLiveChatDialog(context),
                  ),
                  const Divider(height: 1),
                  _buildContactTile(
                    'Phone Support',
                    '+1 (555) 123-4567',
                    Icons.phone,
                    () => _launchPhone('+15551234567'),
                  ),
                  const Divider(height: 1),
                  _buildContactTile(
                    'WhatsApp Support',
                    'Get instant help on WhatsApp',
                    Icons.message,
                    () => _launchWhatsApp('+15551234567'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Resources Section
            _buildSectionHeader('Resources', Icons.library_books),
            const SizedBox(height: 8),
            Card(
              color: Colors.white,
              child: Column(
                children: [
                  _buildResourceTile(
                    'User Guide',
                    'Complete guide to using InstantMentor',
                    Icons.book,
                    () => _launchURL('https://instantmentor.com/guide'),
                  ),
                  const Divider(height: 1),
                  _buildResourceTile(
                    'Video Tutorials',
                    'Watch step-by-step tutorials',
                    Icons.play_circle,
                    () => _launchURL('https://youtube.com/instantmentor'),
                  ),
                  const Divider(height: 1),
                  _buildResourceTile(
                    'Community Forum',
                    'Connect with other users',
                    Icons.forum,
                    () => _launchURL('https://community.instantmentor.com'),
                  ),
                  const Divider(height: 1),
                  _buildResourceTile(
                    'Terms of Service',
                    'Read our terms and conditions',
                    Icons.description,
                    () => _launchURL('https://instantmentor.com/terms'),
                  ),
                  const Divider(height: 1),
                  _buildResourceTile(
                    'Privacy Policy',
                    'Learn about data privacy',
                    Icons.privacy_tip,
                    () => _launchURL('https://instantmentor.com/privacy'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // App Info Section
            _buildSectionHeader('App Information', Icons.info_outline),
            const SizedBox(height: 8),
            Card(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('App Version', '1.0.0'),
                    const SizedBox(height: 8),
                    _buildInfoRow('Build Number', '100'),
                    const SizedBox(height: 8),
                    _buildInfoRow('Last Updated', 'October 6, 2025'),
                    const SizedBox(height: 16),
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: () => _checkForUpdates(context),
                        icon: const Icon(Icons.system_update),
                        label: const Text('Check for Updates'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
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
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQTile(String question, String answer) {
    return ExpansionTile(
      title: Text(
        question,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Text(
            answer,
            style: const TextStyle(color: Colors.grey),
          ),
        ),
      ],
    );
  }

  Widget _buildContactTile(
      String title, String subtitle, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF2563EB)),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  Widget _buildResourceTile(
      String title, String subtitle, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF2563EB)),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.launch, size: 16),
      onTap: onTap,
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        Text(
          value,
          style: const TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  Future<void> _launchEmail(String email) async {
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=InstantMentor Support Request',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchWhatsApp(String phone) async {
    final uri = Uri.parse(
        'https://wa.me/$phone?text=Hi, I need help with InstantMentor');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showLiveChatDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.chat, color: Colors.blue),
            SizedBox(width: 8),
            Text('Live Chat'),
          ],
        ),
        content: const Text(
          'Live chat is currently available Monday-Friday, 9 AM - 6 PM EST.\n\nWould you like to start a chat session or leave a message?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement actual live chat integration
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'Live chat feature coming soon! Please use email for now.'),
                ),
              );
            },
            child: const Text('Start Chat'),
          ),
        ],
      ),
    );
  }

  void _checkForUpdates(BuildContext context) {
    // Simulate checking for updates
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Checking for updates...'),
          ],
        ),
      ),
    );

    // Simulate network delay
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ You have the latest version!'),
          backgroundColor: Colors.green,
        ),
      );
    });
  }
}
