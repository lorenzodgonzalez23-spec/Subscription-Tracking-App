import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/glass_container.dart';
import '../../../../core/utils/currency_formatter.dart';

class SpendSummaryCard extends StatelessWidget {
  const SpendSummaryCard({
    required this.monthly,
    required this.yearly,
    required this.budget,
    required this.yearlyView,
    required this.onViewChanged,
    required this.currency,
    super.key,
  });

  final double monthly;
  final double yearly;
  final double budget;
  final bool yearlyView;
  final ValueChanged<bool> onViewChanged;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final spend = yearlyView ? yearly : monthly;
    final fraction = budget > 0 ? monthly / budget : 0.0;
    final progressColor = fraction >= 1
        ? AppColors.red
        : fraction >= 0.75
        ? AppColors.amber
        : AppColors.green;
    return GlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final toggle = FittedBox(
                fit: BoxFit.scaleDown,
                child: SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: false, label: Text('Month')),
                    ButtonSegment(value: true, label: Text('Year')),
                  ],
                  selected: {yearlyView},
                  onSelectionChanged: (value) => onViewChanged(value.first),
                ),
              );
              if (constraints.maxWidth < 360) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Recurring spend',
                      style: TextStyle(color: AppColors.muted, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Align(alignment: Alignment.centerRight, child: toggle),
                  ],
                );
              }
              return Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Recurring spend',
                      style: TextStyle(color: AppColors.muted, fontSize: 14),
                    ),
                  ),
                  toggle,
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            CurrencyFormatter.format(spend, currency),
            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700),
          ),
          Text(
            yearlyView ? 'Projected per year' : 'Normalized per month',
            style: const TextStyle(color: AppColors.muted),
          ),
          if (budget > 0) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(child: Text('Monthly budget')),
                Text(
                  '${CurrencyFormatter.format(monthly, currency)} / '
                  '${CurrencyFormatter.format(budget, currency)}',
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: fraction.clamp(0, 1),
                minHeight: 8,
                color: progressColor,
                backgroundColor: Colors.white.withOpacity(0.10),
              ),
            ),
            if (fraction >= 1)
              Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Text(
                  'Over budget by ${CurrencyFormatter.format(monthly - budget, currency)}',
                  style: const TextStyle(color: AppColors.red),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
