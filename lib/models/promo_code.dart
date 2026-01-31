
class PromoCode {
  final String? id;
  final String code;
  final String discountType; // 'fixed' or 'percent'
  final int discountValue;
  final List<String> applicableTypes; // ['Посетитель', 'Мастер', etc.]
  final bool isActive;

  PromoCode({
    this.id,
    required this.code,
    required this.discountType,
    required this.discountValue,
    required this.applicableTypes,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'discountType': discountType,
      'discountValue': discountValue,
      'applicableTypes': applicableTypes,
      'isActive': isActive,
      'createdAt': DateTime.now().toIso8601String(),
    };
  }

  factory PromoCode.fromMap(Map<String, dynamic> map, String id) {
    return PromoCode(
      id: id,
      code: map['code'] ?? '',
      discountType: map['discountType'] ?? 'fixed',
      discountValue: map['discountValue'] ?? 0,
      applicableTypes: List<String>.from(map['applicableTypes'] ?? []),
      isActive: map['isActive'] ?? true,
    );
  }
}
