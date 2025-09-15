import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Mock data for incentives and bonuses
final incentivesDataProvider = StateProvider<Map<String, dynamic>>((ref) => {
  'currentTier': 'Gold',
  'nextTier': 'Platinum',
  'progressToNext': 0.75,
  'totalEarned': 1450,
  'thisMonthEarned': 320,
  
  'activeChallenges': [
    {
      'id': '1',
      'title': '30-Session Marathon',
      'description': 'Complete 30 sessions this month',
      'progress': 24,
      'target': 30,
      'reward': 150,
      'type': 'monthly',
      'icon': Icons.directions_run,
      'color': Colors.blue,
      'daysLeft': 7,
    },
    {
      'id': '2',
      'title': 'Perfect Week',
      'description': 'Maintain 5.0 rating for a full week',
      'progress': 5,
      'target': 7,
      'reward': 75,
      'type': 'weekly',
      'icon': Icons.star,
      'color': Colors.amber,
      'daysLeft': 2,
    },
    {
      'id': '3',
      'title': 'Subject Master',
      'description': 'Teach 3 different subjects in one week',
      'progress': 2,
      'target': 3,
      'reward': 100,
      'type': 'weekly',
      'icon': Icons.school,
      'color': Colors.green,
      'daysLeft': 3,
    },
  ],
  
  'completedRewards': [
    {
      'title': 'Early Bird Bonus',
      'description': 'Complete 5 morning sessions',
      'reward': 50,
      'completedDate': DateTime.now().subtract(const Duration(days: 2)),
      'icon': Icons.wb_sunny,
      'color': Colors.orange,
    },
    {
      'title': 'Student Favorite',
      'description': 'Receive 20 five-star ratings',
      'reward': 200,
      'completedDate': DateTime.now().subtract(const Duration(days: 5)),
      'icon': Icons.favorite,
      'color': Colors.red,
    },
    {
      'title': 'Quick Response',
      'description': 'Respond to messages within 5 minutes for a week',
      'reward': 75,
      'completedDate': DateTime.now().subtract(const Duration(days: 10)),
      'icon': Icons.flash_on,
      'color': Colors.blue,
    },
  ],
  
  'tierBenefits': {
    'Bronze': ['5% bonus on weekend sessions', 'Basic mentor badge'],
    'Silver': ['10% bonus on weekend sessions', 'Priority in search results', 'Silver mentor badge'],
    'Gold': ['15% bonus on weekend sessions', 'Top placement in search', 'Featured mentor status', 'Gold mentor badge'],
    'Platinum': ['20% bonus on all sessions', 'Premium mentor badge', 'Exclusive student access', 'Priority support'],
  },
  
  'referralProgram': {
    'totalReferred': 8,
    'activeReferrals': 5,
    'earningsFromReferrals': 400,
    'bonusPerReferral': 50,
  },
});

class IncentivesBonusesScreen extends ConsumerWidget {
  const IncentivesBonusesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incentivesData = ref.watch(incentivesDataProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Incentives & Bonuses'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Earnings Summary
            _buildEarningsSummary(incentivesData),
            const SizedBox(height: 24),
            
            // Tier Progress
            _buildTierProgress(incentivesData),
            const SizedBox(height: 24),
            
            // Active Challenges
            _buildActiveChallenges(incentivesData['activeChallenges']),
            const SizedBox(height: 24),
            
            // Completed Rewards
            _buildCompletedRewards(incentivesData['completedRewards']),
            const SizedBox(height: 24),
            
            // Referral Program
            _buildReferralProgram(incentivesData['referralProgram']),
            const SizedBox(height: 24),
            
            // Tier Benefits
            _buildTierBenefits(incentivesData['tierBenefits'], incentivesData['currentTier']),
          ],
        ),
      ),
    );
  }

  Widget _buildEarningsSummary(Map<String, dynamic> data) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.monetization_on, color: Colors.green, size: 28),
                SizedBox(width: 12),
                Text(
                  'Bonus Earnings',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildEarningCard(
                    'Total Earned',
                    '\$${data['totalEarned']}',
                    Icons.account_balance_wallet,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildEarningCard(
                    'This Month',
                    '\$${data['thisMonthEarned']}',
                    Icons.calendar_month,
                    Colors.blue,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEarningCard(String title, String amount, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            amount,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTierProgress(Map<String, dynamic> data) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.grade, color: Colors.amber, size: 28),
                SizedBox(width: 12),
                Text(
                  'Mentor Tier Progress',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Current: ${data['currentTier']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Next: ${data['nextTier']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Progress to next tier'),
                    Text('${(data['progressToNext'] * 100).round()}%'),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: data['progressToNext'],
                  backgroundColor: Colors.grey.withOpacity(0.3),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveChallenges(List<dynamic> challenges) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Active Challenges',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...challenges.map((challenge) => _buildChallengeCard(challenge)),
      ],
    );
  }

  Widget _buildChallengeCard(Map<String, dynamic> challenge) {
    final progress = challenge['progress'] / challenge['target'];
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (challenge['color'] as Color).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    challenge['icon'],
                    color: challenge['color'],
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            challenge['title'],
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '\$${challenge['reward']}',
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        challenge['description'],
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${challenge['progress']}/${challenge['target']}'),
                    Text(
                      '${challenge['daysLeft']} days left',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey.withOpacity(0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(challenge['color']),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedRewards(List<dynamic> rewards) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Rewards',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: rewards.map((reward) => ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (reward['color'] as Color).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(reward['icon'], color: reward['color']),
              ),
              title: Text(reward['title']),
              subtitle: Text(reward['description']),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${reward['reward']}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _formatDate(reward['completedDate']),
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            )).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildReferralProgram(Map<String, dynamic> referralData) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.people_alt, color: Colors.purple, size: 28),
                SizedBox(width: 12),
                Text(
                  'Referral Program',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Earn \$${referralData['bonusPerReferral']} for each mentor you refer!',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildReferralStat(
                    'Total Referred',
                    '${referralData['totalReferred']}',
                    Icons.person_add,
                  ),
                ),
                Expanded(
                  child: _buildReferralStat(
                    'Active',
                    '${referralData['activeReferrals']}',
                    Icons.people,
                  ),
                ),
                Expanded(
                  child: _buildReferralStat(
                    'Earned',
                    '\$${referralData['earningsFromReferrals']}',
                    Icons.attach_money,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _shareReferralLink(),
                icon: const Icon(Icons.share),
                label: const Text('Share Referral Link'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReferralStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.purple),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.purple,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildTierBenefits(Map<String, dynamic> tierBenefits, String currentTier) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tier Benefits',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...tierBenefits.entries.map((entry) {
              final isCurrentTier = entry.key == currentTier;
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isCurrentTier ? Colors.amber.withOpacity(0.1) : null,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isCurrentTier ? Colors.amber : Colors.grey.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _getTierIcon(entry.key),
                          color: _getTierColor(entry.key),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          entry.key,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isCurrentTier ? Colors.amber.shade700 : null,
                          ),
                        ),
                        if (isCurrentTier) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'CURRENT',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...(entry.value as List).map((benefit) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                          Expanded(child: Text(benefit)),
                        ],
                      ),
                    )),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  IconData _getTierIcon(String tier) {
    switch (tier) {
      case 'Bronze': return Icons.looks_3;
      case 'Silver': return Icons.looks_two;
      case 'Gold': return Icons.looks_one;
      case 'Platinum': return Icons.star;
      default: return Icons.grade;
    }
  }

  Color _getTierColor(String tier) {
    switch (tier) {
      case 'Bronze': return Colors.brown;
      case 'Silver': return Colors.grey;
      case 'Gold': return Colors.amber;
      case 'Platinum': return Colors.purple;
      default: return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;
    
    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else {
      return '$difference days ago';
    }
  }

  void _shareReferralLink() {
    // In a real app, this would share the actual referral link
    // For now, we'll just show a dialog
  }
}
