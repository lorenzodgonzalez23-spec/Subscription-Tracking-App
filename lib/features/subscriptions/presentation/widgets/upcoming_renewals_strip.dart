import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/glass_container.dart';
import '../../domain/subscription_model.dart';

class UpcomingRenewalsStrip extends StatelessWidget {
  const UpcomingRenewalsStrip({required this.items, super.key});

  final List<Subscription> items;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final midnight = DateTime(today.year, today.month, today.day);
    final upcoming = items.where((item) {
      final date = DateTime(
        item.nextBillingDate.year,
        item.nextBillingDate.month,
        item.nextBillingDate.day,
      );
      return !date.isBefore(midnight) && date.difference(midnight).inDays <= 7;
    }).toList()..sort((a, b) => a.nextBillingDate.compareTo(b.nextBillingDate));
    if (upcoming.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 2, bottom: 10),
          child: Text(
            'Coming up',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
        SizedBox(
          height: 106,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: upcoming.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final item = upcoming[index];
              final days = DateTime(
                item.nextBillingDate.year,
                item.nextBillingDate.month,
                item.nextBillingDate.day,
              ).difference(midnight).inDays;
              final label = days == 0
                  ? 'Today'
                  : days == 1
                  ? 'Tomorrow'
                  : 'In $days days';
              return SizedBox(
                width: 205,
                child: GlassContainer(
                  padding: const EdgeInsets.all(14),
                  borderRadius: 18,
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Color(item.fallbackColorHex),
                        child: Text(item.name.isEmpty ? '?' : item.name[0]),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              label,
                              style: const TextStyle(
                                color: AppColors.amber,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              DateFormat.MMMd().format(item.nextBillingDate),
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
