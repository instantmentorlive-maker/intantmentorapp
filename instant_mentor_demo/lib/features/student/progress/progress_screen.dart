import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/models/session.dart';

// Mock progress data providers
final progressDataProvider = Provider<List<Progress>>((ref) {
  final user = ref.watch(userProvider);
  if (user == null) return [];
  
  return [
    Progress(
      studentId: user.id,
      subject: 'Mathematics',
      completionPercentage: 75.0,
      totalSessions: 16,
      completedSessions: 12,
      weakAreas: ['Calculus', 'Trigonometry'],
      topicProgress: {
        'Algebra': 0.9,
        'Geometry': 0.8,
        'Calculus': 0.6,
        'Trigonometry': 0.55,
        'Statistics': 0.85,
      },
      lastUpdated: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    Progress(
      studentId: user.id,
      subject: 'Physics',
      completionPercentage: 60.0,
      totalSessions: 10,
      completedSessions: 6,
      weakAreas: ['Electromagnetism', 'Quantum Physics'],
      topicProgress: {
        'Mechanics': 0.85,
        'Thermodynamics': 0.7,
        'Electromagnetism': 0.45,
        'Optics': 0.6,
        'Quantum Physics': 0.3,
      },
      lastUpdated: DateTime.now().subtract(const Duration(days: 1)),
    ),
    Progress(
      studentId: user.id,
      subject: 'Chemistry',
      completionPercentage: 45.0,
      totalSessions: 8,
      completedSessions: 4,
      weakAreas: ['Organic Chemistry', 'Physical Chemistry'],
      topicProgress: {
        'Inorganic Chemistry': 0.8,
        'Organic Chemistry': 0.3,
        'Physical Chemistry': 0.25,
      },
      lastUpdated: DateTime.now().subtract(const Duration(days: 3)),
    ),
  ];
});

final overallStatsProvider = Provider<Map<String, dynamic>>((ref) {
  final progressList = ref.watch(progressDataProvider);
  
  final totalSessions = progressList.fold<int>(0, (sum, progress) => sum + progress.completedSessions);
  final totalPlanned = progressList.fold<int>(0, (sum, progress) => sum + progress.totalSessions);
  final averageProgress = progressList.isEmpty 
    ? 0.0 
    : progressList.fold<double>(0, (sum, progress) => sum + progress.completionPercentage) / progressList.length;
    
  return {
    'completed_sessions': totalSessions,
    'total_planned': totalPlanned,
    'in_progress': totalPlanned - totalSessions,
    'average_progress': averageProgress,
    'weak_areas_count': progressList.fold<int>(0, (sum, progress) => sum + progress.weakAreas.length),
  };
});

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressList = ref.watch(progressDataProvider);
    final stats = ref.watch(overallStatsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overall Progress Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Overall Progress',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Progress Chart
                  SizedBox(
                    height: 200,
                    child: _OverallProgressChart(
                      completed: stats['completed_sessions'],
                      inProgress: stats['in_progress'],
                      averageProgress: stats['average_progress'],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Stats Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatItem(
                        icon: Icons.check_circle,
                        label: 'Completed',
                        value: '${stats['completed_sessions']}',
                        color: Colors.green,
                      ),
                      _StatItem(
                        icon: Icons.schedule,
                        label: 'In Progress',
                        value: '${stats['in_progress']}',
                        color: Colors.orange,
                      ),
                      _StatItem(
                        icon: Icons.warning,
                        label: 'Weak Areas',
                        value: '${stats['weak_areas_count']}',
                        color: Colors.red,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Subject Progress
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Subject Progress',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () => _showDetailedProgress(context, progressList),
                child: const Text('View Details'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          ...progressList.map((progress) => _SubjectProgressCard(progress: progress)),
          
          const SizedBox(height: 24),
          
          // Weekly Progress Chart
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Weekly Session Activity',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: _WeeklyProgressChart(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDetailedProgress(BuildContext context, List<Progress> progressList) {
    showDialog(
      context: context,
      builder: (context) => _DetailedProgressDialog(progressList: progressList),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _OverallProgressChart extends StatelessWidget {
  final int completed;
  final int inProgress;
  final double averageProgress;

  const _OverallProgressChart({
    required this.completed,
    required this.inProgress,
    required this.averageProgress,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Pie Chart
        Expanded(
          flex: 2,
          child: PieChart(
            PieChartData(
              sections: [
                PieChartSectionData(
                  value: completed.toDouble(),
                  color: Colors.green,
                  title: 'Completed\n$completed',
                  titleStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  radius: 60,
                ),
                PieChartSectionData(
                  value: inProgress.toDouble(),
                  color: Colors.orange,
                  title: 'In Progress\n$inProgress',
                  titleStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  radius: 60,
                ),
              ],
              sectionsSpace: 2,
              centerSpaceRadius: 40,
            ),
          ),
        ),
        
        // Progress Indicator
        Expanded(
          flex: 1,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                value: averageProgress / 100,
                strokeWidth: 8,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${averageProgress.toInt()}%',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                'Average\nProgress',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SubjectProgressCard extends StatelessWidget {
  final Progress progress;

  const _SubjectProgressCard({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  progress.subject,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text('${progress.completionPercentage.toInt()}%'),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress.completionPercentage / 100,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sessions: ${progress.completedSessions}/${progress.totalSessions}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (progress.weakAreas.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${progress.weakAreas.length} weak areas',
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WeeklyProgressChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                if (value.toInt() < days.length) {
                  return Text(days[value.toInt()]);
                }
                return const Text('');
              },
              reservedSize: 30,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text('${value.toInt()}h');
              },
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: const [
              FlSpot(0, 2),
              FlSpot(1, 1.5),
              FlSpot(2, 3),
              FlSpot(3, 2.5),
              FlSpot(4, 4),
              FlSpot(5, 1),
              FlSpot(6, 2),
            ],
            isCurved: true,
            color: Theme.of(context).colorScheme.primary,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            ),
          ),
        ],
        minX: 0,
        maxX: 6,
        minY: 0,
        maxY: 5,
      ),
    );
  }
}

class _DetailedProgressDialog extends StatelessWidget {
  final List<Progress> progressList;

  const _DetailedProgressDialog({required this.progressList});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Detailed Progress'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: ListView.builder(
          itemCount: progressList.length,
          itemBuilder: (context, index) {
            final progress = progressList[index];
            return ExpansionTile(
              title: Text(progress.subject),
              subtitle: Text('${progress.completionPercentage.toInt()}% complete'),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Topic Progress:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ...progress.topicProgress.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(entry.key),
                              ),
                              Expanded(
                                flex: 3,
                                child: LinearProgressIndicator(
                                  value: entry.value,
                                  backgroundColor: Colors.grey[300],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text('${(entry.value * 100).toInt()}%'),
                            ],
                          ),
                        );
                      }),
                      if (progress.weakAreas.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Weak Areas:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          children: progress.weakAreas.map((area) {
                            return Chip(
                              label: Text(area),
                              backgroundColor: Colors.red.withOpacity(0.1),
                              labelStyle: const TextStyle(color: Colors.red),
                            );
                          }).toList(),
                        ),
                      ],
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Progress report will be available soon!'),
              ),
            );
          },
          child: const Text('Export Report'),
        ),
      ],
    );
  }
}
