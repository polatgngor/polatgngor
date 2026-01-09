import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../rides/data/ride_repository.dart';
import '../../../core/constants/app_constants.dart';

// --- Providers ---

final earningsFilterProvider = NotifierProvider<EarningsFilterNotifier, EarningsFilter>(EarningsFilterNotifier.new);

class EarningsFilterNotifier extends Notifier<EarningsFilter> {
  @override
  EarningsFilter build() => EarningsFilter.daily;

  void setFilter(EarningsFilter filter) => state = filter;
}

enum EarningsFilter { daily, weekly, monthly }


final earningsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final filter = ref.watch(earningsFilterProvider);
  
  // Use server-side period calculation
  String period = 'daily';
  switch (filter) {
    case EarningsFilter.daily: period = 'daily'; break;
    case EarningsFilter.weekly: period = 'weekly'; break;
    case EarningsFilter.monthly: period = 'monthly'; break;
  }

  // Use Repository
  final repository = ref.read(driverRideRepositoryProvider);
  return await repository.getEarnings(period: period);
});


// --- UI ---

class EarningsScreen extends ConsumerWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(earningsFilterProvider);
    final earningsAsync = ref.watch(earningsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('earnings.title'.tr()),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Filter Tabs
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(child: _buildFilterTab(ref, EarningsFilter.daily, 'earnings.daily'.tr(), filter)),
                const SizedBox(width: 12),
                Expanded(child: _buildFilterTab(ref, EarningsFilter.weekly, 'earnings.weekly'.tr(), filter)),
                const SizedBox(width: 12),
                Expanded(child: _buildFilterTab(ref, EarningsFilter.monthly, 'earnings.monthly'.tr(), filter)),
              ],
            ),
          ),
          
          Expanded(
            child: earningsAsync.when(
              data: (data) {
                final double total = (data['total'] ?? 0).toDouble();
                final int count = data['count'] ?? 0;
                final List<dynamic> rides = data['rides'] ?? [];

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Summary Card
                    _buildSummaryCard(context, total, count),
                    
                    const SizedBox(height: 24),
                    
                    // Chart
                    SizedBox(
                      height: 200,
                      child: _buildChart(context, filter, rides),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    Text(
                      'earnings.ride_history'.tr(),
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800]),
                    ),
                    const SizedBox(height: 12),
                    
                    // Transactions
                    if (rides.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Text('earnings.no_earnings'.tr(), style: TextStyle(color: Colors.grey[500])),
                        ),
                      )
                    else
                      ...rides.map((ride) => _buildTransactionCard(context, ride)),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('profile.error'.tr(args: [err.toString()]))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(WidgetRef ref, EarningsFilter tab, String label, EarningsFilter current) {
    final isSelected = tab == current;
    return GestureDetector(
      onTap: () => ref.read(earningsFilterProvider.notifier).setFilter(tab),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1A77F6) : const Color(0xFFF1F4F8),
          borderRadius: BorderRadius.circular(30),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[600],
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, double total, int count) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A77F6), Color(0xFF4C94FA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A77F6).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'earnings.total_earnings'.tr(),
            style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            '₺${total.toStringAsFixed(2)}',
            style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.directions_car, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'earnings.trip_count'.tr(args: [count.toString()]),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildTransactionCard(BuildContext context, Map<String, dynamic> ride) {
    final fare = (ride['fare_actual'] ?? 0).toString();
    final simpleParams = ride['date_formatted'] ?? '';
    final paymentMethod = ride['payment_method'] ?? 'nakit';
    final isCash = paymentMethod == 'nakit';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4F8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.payments_rounded, color: Theme.of(context).primaryColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCash ? 'earnings.payment_cash'.tr() : 'earnings.payment_pos'.tr(),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  simpleParams,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
          ),
          Text(
            '₺$fare',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green),
          ),
        ],
      ),
    );
  }

  // --- Chart Logic ---

  Widget _buildChart(BuildContext context, EarningsFilter filter, List<dynamic> rides) {
    // Process data for chart
    final Map<int, double> spots = {};
    
    // Initialize X axis range
    int minX = 0;
    int maxX = 0;
    
    if (filter == EarningsFilter.daily) {
      // Hours 0-23
      maxX = 23;
      for (int i = 0; i <= 23; i++) spots[i] = 0;
      for (var r in rides) {
        final d = DateTime.tryParse(r['created_at']) ?? DateTime.now();
        final h = d.hour;
        spots[h] = (spots[h] ?? 0) + (double.tryParse(r['fare_actual'].toString()) ?? 0);
      }
    } else if (filter == EarningsFilter.weekly) {
      // Days 1-7 (Mon-Sun)
      minX = 1;
      maxX = 7;
      for (int i = 1; i <= 7; i++) spots[i] = 0;
      for (var r in rides) {
        final d = DateTime.tryParse(r['created_at']) ?? DateTime.now();
        final weekday = d.weekday;
        spots[weekday] = (spots[weekday] ?? 0) + (double.tryParse(r['fare_actual'].toString()) ?? 0);
      }
    } else {
      // Days of month 1-31
      minX = 1;
      maxX = DateTime.now().day; // Up to today
      for (int i = 1; i <= maxX; i++) spots[i] = 0;
      for (var r in rides) {
        final d = DateTime.tryParse(r['created_at']) ?? DateTime.now();
        final day = d.day;
        spots[day] = (spots[day] ?? 0) + (double.tryParse(r['fare_actual'].toString()) ?? 0);
      }
    }

    // Determine max Y for scaling
    double maxY = 0;
    spots.forEach((k, v) {
      if (v > maxY) maxY = v;
    });
    if (maxY == 0) maxY = 100;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY * 1.2,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipRoundedRadius: 8,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '₺${rod.toY.toStringAsFixed(0)}',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                if (filter == EarningsFilter.daily && value % 4 != 0) return const SizedBox.shrink();
                if (filter == EarningsFilter.monthly && value % 5 != 0 && value != 1) return const SizedBox.shrink();
                
                String text = value.toInt().toString();
                if (filter == EarningsFilter.weekly) {
                   // Dynamic locale-aware days
                   final now = DateTime.now();
                   // Calculate the date for the given weekday (1=Mon, ..., 7=Sun)
                   final date = now.subtract(Duration(days: now.weekday - value.toInt()));
                   text = DateFormat('E', context.locale.toString()).format(date);
                }
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(text, style: TextStyle(color: Colors.grey[600], fontSize: 10)),
                );
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: spots.entries.map((e) {
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: e.value,
                color: const Color(0xFF1A77F6),
                width: filter == EarningsFilter.monthly ? 6 : 12,
                borderRadius: BorderRadius.circular(4),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: maxY * 1.2,
                  color: const Color(0xFFF1F4F8),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
