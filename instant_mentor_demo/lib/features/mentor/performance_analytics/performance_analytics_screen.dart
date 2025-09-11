import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

// Mock analytics data
final analyticsDataProvider = StateProvider<Map<String, dynamic>>((ref) => {
  'totalStudents': 67,
  'totalSessions': 1247,
  'totalHours': 892,
  'averageRating': 4.9,
  'monthlyEarnings': 3450,
  'responseRate': 98,
  'completionRate': 96,
  'repeatStudents': 78,
  
  // Weekly session data for chart
  'weeklySessionData': [
    {'day': 'Mon', 'sessions': 8, 'hours': 6.5},
    {'day': 'Tue', 'sessions': 12, 'hours': 9.0},
    {'day': 'Wed', 'sessions': 15, 'hours': 11.5},
    {'day': 'Thu', 'sessions': 10, 'hours': 7.5},
    {'day': 'Fri', 'sessions': 14, 'hours': 10.0},
    {'day': 'Sat', 'sessions': 18, 'hours': 13.5},
    {'day': 'Sun', 'sessions': 9, 'hours': 6.5},
  ],
  
  // Subject distribution
  'subjectData': [
    {'subject': 'Mathematics', 'percentage': 45, 'sessions': 561, 'color': Colors.blue},
    {'subject': 'Physics', 'percentage': 30, 'sessions': 374, 'color': Colors.green},
    {'subject': 'Chemistry', 'percentage': 25, 'sessions': 312, 'color': Colors.orange},
  ],
  
  // Monthly earnings data
  'monthlyEarningsData': [
    {'month': 'Jan', 'earnings': 2800},
    {'month': 'Feb', 'earnings': 3200},
    {'month': 'Mar', 'earnings': 3600},
    {'month': 'Apr', 'earnings': 3450},
    {'month': 'May', 'earnings': 3800},
    {'month': 'Jun', 'earnings': 4200},
  ],
  
  // Student ratings distribution
  'ratingsData': [
    {'stars': 5, 'count': 950},
    {'stars': 4, 'count': 230},
    {'stars': 3, 'count': 45},
    {'stars': 2, 'count': 15},
    {'stars': 1, 'count': 7},
  ],
});

final selectedTimeRangeProvider = StateProvider<String>((ref) => 'This Month');

class PerformanceAnalyticsScreen extends ConsumerWidget {
  const PerformanceAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsData = ref.watch(analyticsDataProvider);
    final selectedTimeRange = ref.watch(selectedTimeRangeProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Performance Analytics'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              ref.read(selectedTimeRangeProvider.notifier).state = value;
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'This Week', child: Text('This Week')),
              const PopupMenuItem(value: 'This Month', child: Text('This Month')),
              const PopupMenuItem(value: 'Last 3 Months', child: Text('Last 3 Months')),
              const PopupMenuItem(value: 'This Year', child: Text('This Year')),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Time Range Header
            Text(
              'Analytics for $selectedTimeRange',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            
            // Key Metrics Cards
            _buildMetricsGrid(analyticsData),
            const SizedBox(height: 24),
            
            // Weekly Sessions Chart
            _buildWeeklySessionsChart(analyticsData['weeklySessionData']),
            const SizedBox(height: 24),
            
            // Subject Distribution
            _buildSubjectDistribution(analyticsData['subjectData']),
            const SizedBox(height: 24),
            
            // Monthly Earnings Chart
            _buildMonthlyEarningsChart(analyticsData['monthlyEarningsData']),
            const SizedBox(height: 24),
            
            // Student Ratings
            _buildRatingsDistribution(analyticsData['ratingsData']),
            const SizedBox(height: 24),
            
            // Performance Insights
            _buildPerformanceInsights(analyticsData),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsGrid(Map<String, dynamic> data) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildMetricCard('Total Students', '${data['totalStudents']}', Icons.people, Colors.blue),
        _buildMetricCard('Total Sessions', '${data['totalSessions']}', Icons.video_call, Colors.green),
        _buildMetricCard('Hours Taught', '${data['totalHours']}h', Icons.access_time, Colors.orange),
        _buildMetricCard('Avg Rating', '${data['averageRating']}/5.0', Icons.star, Colors.amber),
        _buildMetricCard('Monthly Earnings', '\$${data['monthlyEarnings']}', Icons.attach_money, Colors.purple),
        _buildMetricCard('Response Rate', '${data['responseRate']}%', Icons.reply, Colors.teal),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklySessionsChart(List<dynamic> weeklyData) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Weekly Sessions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 20,
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < weeklyData.length) {
                            return Text(
                              weeklyData[index]['day'],
                              style: const TextStyle(fontSize: 12),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: weeklyData.asMap().entries.map((entry) {
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value['sessions'].toDouble(),
                          color: Colors.blue,
                          width: 20,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectDistribution(List<dynamic> subjectData) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Subject Distribution',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 150,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 0,
                        centerSpaceRadius: 40,
                        sections: subjectData.map((data) => PieChartSectionData(
                          color: data['color'],
                          value: data['percentage'].toDouble(),
                          title: '${data['percentage']}%',
                          radius: 50,
                          titleStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        )).toList(),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: subjectData.map((data) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: data['color'],
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['subject'],
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                                Text(
                                  '${data['sessions']} sessions',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )).toList(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyEarningsChart(List<dynamic> earningsData) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Monthly Earnings Trend',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < earningsData.length) {
                            return Text(
                              earningsData[index]['month'],
                              style: const TextStyle(fontSize: 12),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: earningsData.asMap().entries.map((entry) {
                        return FlSpot(entry.key.toDouble(), entry.value['earnings'].toDouble());
                      }).toList(),
                      isCurved: true,
                      color: Colors.green,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.green.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingsDistribution(List<dynamic> ratingsData) {
    final totalRatings = ratingsData.fold<int>(0, (sum, item) => sum + (item['count'] as int));
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Student Ratings Distribution',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...ratingsData.map((data) {
              final percentage = (data['count'] / totalRatings * 100).round();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 60,
                      child: Row(
                        children: [
                          Text('${data['stars']}'),
                          const SizedBox(width: 4),
                          const Icon(Icons.star, size: 16, color: Colors.amber),
                        ],
                      ),
                    ),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: data['count'] / ratingsData[0]['count'],
                        backgroundColor: Colors.grey.withOpacity(0.3),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 60,
                      child: Text('$percentage% (${data['count']})', style: const TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceInsights(Map<String, dynamic> data) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Performance Insights',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildInsightItem(
              icon: Icons.trending_up,
              title: 'Strong Performance',
              description: 'Your rating has improved by 0.2 points this month.',
              color: Colors.green,
            ),
            _buildInsightItem(
              icon: Icons.people_outline,
              title: 'Student Retention',
              description: '${data['repeatStudents']}% of your students book follow-up sessions.',
              color: Colors.blue,
            ),
            _buildInsightItem(
              icon: Icons.schedule,
              title: 'Peak Hours',
              description: 'Most sessions are booked on weekends and evenings.',
              color: Colors.orange,
            ),
            _buildInsightItem(
              icon: Icons.subject,
              title: 'Top Subject',
              description: 'Mathematics generates the most bookings and highest ratings.',
              color: Colors.purple,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightItem({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
