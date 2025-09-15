import 'package:flutter/material.dart';

/// Minimal Security Dashboard used by the security example demo.
///
/// Provides a simple overview screen with placeholder sections so that
/// the demo compiles and runs. You can expand this with real metrics,
/// audit logs, and security checks.
class SecurityDashboard extends StatelessWidget {
  const SecurityDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Security Dashboard'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _SectionCard(
            title: 'System Status',
            lines: [
              'Encryption Service: Active',
              'Biometric Auth: Ready',
              'Key Manager: Initialized',
            ],
          ),
          SizedBox(height: 12),
          _SectionCard(
            title: 'Recent Security Events',
            lines: [
              'No critical alerts in the last 24 hours',
              'Last audit: Completed successfully',
            ],
          ),
          SizedBox(height: 12),
          _SectionCard(
            title: 'Recommendations',
            lines: [
              'Enable MFA for all admin accounts',
              'Rotate data protection keys every 30 days',
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<String> lines;

  const _SectionCard({required this.title, required this.lines});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...lines.map(
              (l) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(l, style: Theme.of(context).textTheme.bodyMedium),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
