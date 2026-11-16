import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/payment_method_model.dart';
import 'fallback_icons.dart';

class PaymentMethodFilter extends StatelessWidget {
  const PaymentMethodFilter({
    required this.methods,
    required this.selectedId,
    required this.onSelected,
    super.key,
  });

  final List<PaymentMethod> methods;
  final String? selectedId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        ChoiceChip(
          label: const Text('All methods'),
          selected: selectedId == null,
          onSelected: (_) => onSelected(null),
        ),
        for (final method in methods) ...[
          const SizedBox(width: 8),
          ChoiceChip(
            label: Text(method.name),
            avatar: CircleAvatar(
              radius: 6,
              backgroundColor: Color(method.colorHex),
            ),
            selected: selectedId == method.id,
            selectedColor: Color(method.colorHex).withOpacity(0.25),
            onSelected: (_) =>
                onSelected(selectedId == method.id ? null : method.id),
          ),
        ],
      ],
    ),
  );
}

class SubscriptionTile extends StatelessWidget {
  const SubscriptionTile({
    required this.name,
    required this.subtitle,
    required this.amount,
    required this.color,
    required this.autoRenew,
    required this.onTap,
    required this.onDelete,
    this.imageBytes,
    this.iconCode = 0,
    super.key,
  });

  final String name;
  final String subtitle;
  final String amount;
  final Color color;
  final bool autoRenew;
  final Uint8List? imageBytes;
  final int iconCode;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
    leading: imageBytes == null
        ? CircleAvatar(
            radius: 23,
            backgroundColor: color.withOpacity(0.22),
            child: Icon(fallbackIconFor(iconCode), color: color),
          )
        : CircleAvatar(
            radius: 23,
            backgroundColor: color.withOpacity(0.22),
            backgroundImage: MemoryImage(imageBytes!),
          ),
    title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
    subtitle: Text(
      '$subtitle · ${autoRenew ? 'Renews' : 'Manual'}',
      style: const TextStyle(color: AppColors.muted, fontSize: 12),
    ),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(amount, style: const TextStyle(fontWeight: FontWeight.w600)),
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') onTap();
            if (value == 'delete') onDelete();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ],
    ),
    onTap: onTap,
  );
}
