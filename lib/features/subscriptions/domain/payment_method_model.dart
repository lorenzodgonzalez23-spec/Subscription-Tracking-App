class PaymentMethod {
  const PaymentMethod({
    required this.id,
    required this.name,
    required this.colorHex,
    this.lastFour,
  });

  final String id;
  final String name;
  final String? lastFour;
  final int colorHex;

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'last_four': lastFour,
    'color_hex': colorHex,
  };

  factory PaymentMethod.fromMap(Map<String, Object?> map) => PaymentMethod(
    id: map['id']! as String,
    name: map['name']! as String,
    lastFour: map['last_four'] as String?,
    colorHex: map['color_hex']! as int,
  );
}
