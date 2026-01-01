import 'package:hive/hive.dart';

part 'calculation.g.dart'; // Файл будет сгенерирован

@HiveType(typeId: 0)
class Calculation {
  @HiveField(0)
  int? id;
  
  @HiveField(1)
  final String name;
  
  @HiveField(2)
  final String birthDate;
  
  @HiveField(3)
  final String gender;
  
  @HiveField(4)
  final List<int> numbers;
  
  @HiveField(5)
  final DateTime createdAt;
  
  @HiveField(6)
  String? group;
  
  @HiveField(7)
  String? notes;
  
  @HiveField(8)
  int decryption;
  
  Calculation({
    this.id,
    required this.name,
    required this.birthDate,
    required this.gender,
    required this.numbers,
    required this.createdAt,
    this.group,
    this.notes,
    this.decryption = 0,
  });
  
  Calculation copyWith({
    int? id,
    String? name,
    String? birthDate,
    String? gender,
    List<int>? numbers,
    DateTime? createdAt,
    String? group,
    String? notes,
    int? decryption,
  }) {
    return Calculation(
      id: id ?? this.id,
      name: name ?? this.name,
      birthDate: birthDate ?? this.birthDate,
      gender: gender ?? this.gender,
      numbers: numbers ?? this.numbers,
      createdAt: createdAt ?? this.createdAt,
      group: group ?? this.group,
      notes: notes ?? this.notes,
      decryption: decryption ?? this.decryption,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'birthDate': birthDate,
      'gender': gender,
      'numbers': numbers,
      'createdAt': createdAt.toIso8601String(),
      'group': group,
      'notes': notes,
      'decryption': decryption,
    };
  }
  
  factory Calculation.fromMap(Map<String, dynamic> map) {
    // Helper to get value checking multiple keys
    String? getString(List<String> keys) {
      for (var k in keys) {
        if (map[k] != null) return map[k] as String;
      }
      return null;
    }

    String? calcDateStr = getString(['createdAt', 'calculation_date']);
    DateTime parsedDate;
    if (calcDateStr != null) {
      // Create flexible parser or standard tryParse
      parsedDate = DateTime.tryParse(calcDateStr) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    return Calculation(
      name: map['name'] as String? ?? 'Без имени',
      birthDate: (map['birthDate'] ?? map['birth_date']) as String? ?? '',
      gender: map['gender'] as String? ?? 'М',
      numbers: (map['numbers'] as List?)?.map((e) => e as int).toList() ?? [],
      createdAt: parsedDate,
      group: getString(['group', 'user_group']),
      notes: map['notes'] as String?,
      decryption: map['decryption'] as int? ?? 0,
    );
  }
  
  String get formattedScheme {
    final nums = numbers;
    
    if (gender == 'М') {
      return '''
Имя: $name
Дата: $birthDate

${nums[0]} - ${nums[1]} - ${nums[2]} | ${nums[3]}
${nums[4]} ← ${nums[5]}   ${nums[6]} → ${nums[7]}
         ${nums[8]}
          |> ${nums[10]}
         ${nums[9]}       ${nums[11]}
          |   ${nums[13]}
          ${nums[12]}
''';
    } else {
      return '''
Имя: $name
Дата: $birthDate

${nums[0]} - ${nums[1]} - ${nums[2]} | ${nums[3]}
 ${nums[4]} ← ${nums[5]}   ${nums[6]} → ${nums[7]}
         ${nums[8]}
          |> ${nums[10]}
${nums[11]}        ${nums[9]}
   ${nums[13]}     |
         ${nums[12]}
''';
    }
  }
}