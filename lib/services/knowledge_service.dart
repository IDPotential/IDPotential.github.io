
import '../data/diagnostic_data.dart';
import '../models/calculation.dart';
import 'calculator_service.dart';

class KnowledgeService {
  static final Map<String, List<int>> categories = {
    "Антагонисты": [0, 1, 3, 4, 5, 7, 13, 15, 16],
    "Союзники": [2, 3, 6, 8, 10, 12, 14, 20, 21],
    "Нейтральные (усилители)": [9, 11, 17, 18, 19],
    "Мужские зоны": [4, 5, 6, 8, 10],
    "Женские зоны": [2, 3, 9, 12, 21],
    "Детские": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
    "Подростковые": [11, 12, 13, 14, 15, 16, 17],
    "Старшие": [18, 19, 20, 21, 0],
    "Пространственные": [1, 2, 3, 4, 6, 8, 10, 11, 12, 14, 18, 21, 0],
    "Временные": [5, 7, 9, 11, 13, 17, 16, 18, 19, 20, 0]
  };

  static String getZoneName(int number) {
    if (number == 0) number = 22;
    final n = (number == 0) ? 22 : number;
    final zone = zones[n];
    if (zone == null) return "$n";
    final roleName = zone['role_name'] ?? zone['name'];
    // Return markdown link with custom scheme 'role:'
    return "[$n ($roleName)](role:$n)";
  }

  static String getAspectLinkText(int num1, int num2) {
    // Determine the key (e.g. 8-14 or 14-8). Usually smaller first or fixed logic? 
    // The data map uses consistent keys (e.g. 1-21). 
    // Let's rely on the screen to resolve the key or pass both numbers.
    // Scheme: aspect:num1-num2
    return "[$num1 → $num2](aspect:$num1-$num2)";
  }

  static String generateDetailedDescription(Calculation calculation) {
    final analysis = CalculatorService.analyzeCalculation(
      calculation.numbers,
      calculation.gender
    );

    final numbers = calculation.numbers;
    final birthDate = calculation.birthDate;
    final name = calculation.name;
    final femaleInner = numbers[5];
    final femaleOuter = numbers[4];
    final maleInner = numbers[6];
    final maleOuter = numbers[7];

    final formattedValues = numbers.map((n) => getZoneName(n)).toList();

    final x = analysis['stress_behavior'] as int;
    final y = analysis['stress_balance'] as int;
    final formattedX = getZoneName(x);
    final formattedY = getZoneName(y);

    final femaleDualityText =
        "♀️ Женская дуальность (межличностные отношения): ${getAspectLinkText(femaleInner, femaleOuter)}  \n"
        "Внутренняя суть в отношениях:  ${getZoneName(femaleInner)}  \n"
        "Внешнее проявление в отношениях: ${getZoneName(femaleOuter)}";

    final maleDualityText =
        "♂️ Мужская дуальность (реализация в социуме): ${getAspectLinkText(maleInner, maleOuter)}  \n"
        "Внутренняя суть реализации:  ${getZoneName(maleInner)}  \n"
        "Внешнее проявление реализации: ${getZoneName(maleOuter)}";

    String baseDescription = """
*${name} (${birthDate})*  
*Детальная расшифровка:*

**I – Третичная фаза (непроявленное)**  
▫️ 0-30 лет:     ${formattedValues[0]}  
▫️ 30-60 лет:    ${formattedValues[1]}  
▫️ 60-90 лет:    ${formattedValues[2]}  
🔹 Точка входа:     ${formattedValues[3]}

**II – Инь/Ян баланс**  
$femaleDualityText

$maleDualityText

**III – Ядро мотивации**  
🎯 Основной мотив:  ${formattedValues[8]}

**IV – Реализация в социуме**  
🛠 Способ действия:  ${formattedValues[9]}  
🌐 Сфера реализации:     ${formattedValues[10]}

**V – Точка гармонии**  
🚪 Точка выхода:     ${formattedValues[12]}  
💭 Внутренний мир, страхи:  ${formattedValues[11]}  
⚖️ Баланс внешнего/внутреннего:  ${formattedValues[13]}

**🧠 Поведение в стрессе:** $formattedX  
**⚖️ Баланс в стрессе:** $formattedY
""";

    // Formatting fix: extra newline and numbers only
    String categoryDescription = "\n\n**🔍 Особые зоны в вашей диагностике:**\n\n";

    final accents = analysis['accents'] as List<int>;
    final dominants = analysis['dominants'] as List<int>;
    final neurosis = analysis['neurosis'] as List<int>;

    if (accents.isNotEmpty) {
      categoryDescription += "▫️ *Акценты (2 раза):* ${accents.join(', ')}  \n";
    }
    if (dominants.isNotEmpty) {
      categoryDescription += "▫️ *Доминанты (3 раза):* ${dominants.join(', ')}  \n";
    }
    if (neurosis.isNotEmpty) {
      categoryDescription += "▫️ *Невроз (4+ раз):* ${neurosis.join(', ')}  \n";
    }

    final allZones = numbers.toSet().toList();

    categories.forEach((category, zoneNumbers) {
      final found = allZones.where((z) => zoneNumbers.contains(z)).toList();
      if (found.isNotEmpty) {
        categoryDescription += "▫️ *$category:* ${found.join(', ')}  \n";
      }
    });

    return baseDescription + categoryDescription;
  }

  static String generateVeryDetailedDescription(Calculation calculation) {
    final numbers = calculation.numbers;
    final birthDate = calculation.birthDate;
    final name = calculation.name;
    final gender = calculation.gender;

    final analysis = CalculatorService.analyzeCalculation(numbers, gender);
    final x = analysis['stress_behavior'] as int;
    final y = analysis['stress_balance'] as int;

    Map<String, String> getZone(int n) {
      return zones[n == 0 ? 22 : n] ?? {};
    }

    String description = "*Подробная версия диагностики для \n$name ($birthDate)*\n\n";

    // Phases
    final phases = [
      {"name": "первой трети жизни (0-30 лет)", "num": numbers[0]},
      {"name": "второй трети жизни (30-60 лет)", "num": numbers[1]},
      {"name": "третьей трети жизни (60-90 лет)", "num": numbers[2]}
    ];

    for (var phase in phases) {
      final zoneNum = phase["num"] as int;
      final zone = getZone(zoneNum);
      description += "▫️ В ${phase["name"]} проявляется $zoneNum Роль подсознания (${zone['role_name'] ?? 'Название'}): \n${zone['third'] ?? 'Описание отсутствует'}\n\n";
    }

    // Point of Entry
    final zone4 = getZone(numbers[3]);
    description += "🔹 Точка \"входа\" - то с чем человек уже пришел сюда, заложенный устойчивый опыт - выражается через ${numbers[3]} роль: \n(${zone4['role_name'] ?? 'Название'}): ${zone4['enter'] ?? 'Описание отсутствует'}\n\n";

    // Dualities
    final femaleInner = numbers[5];
    final femaleOuter = numbers[4];
    final maleInner = numbers[6];
    final maleOuter = numbers[7];

    String femaleAspectKey = "$femaleInner-$femaleOuter";
    if (!aspectsRole.containsKey(femaleAspectKey)) femaleAspectKey = "$femaleOuter-$femaleInner";
    
    String maleAspectKey = "$maleInner-$maleOuter";
    if (!aspectsRole.containsKey(maleAspectKey)) maleAspectKey = "$maleOuter-$maleInner";

    final femaleData = aspectsRole[femaleAspectKey] ?? {};
    final maleData = aspectsRole[maleAspectKey] ?? {};

    description += "♀️ Женская дуальность личности (межличностные отношения) проявляется через аспект ${getAspectLinkText(femaleInner, femaleOuter)}:\n";
    if (femaleData.isNotEmpty) {
      description += "*${femaleData['aspect_name'] ?? 'Название'} (${femaleData['aspect_key'] ?? 'Роли'})*\n\n"
          "**🧠 Ключевое качество:**  \n${femaleData['aspect_strength'] ?? 'Описание отсутствует'}\n\n"
          "**⚡ Вызов (опасность):**  \n${femaleData['aspect_challenge'] ?? 'Описание отсутствует'}\n\n"
          "**🌍 Проявление в жизни:**  \n${femaleData['aspect_inlife'] ?? 'Описание отсутствует'}\n\n"
          "**❓ Вопрос для рефлексии:**  \n${femaleData['aspect_question'] ?? 'Вопрос отсутствует'}\n\n";
    } else {
      description += "Описание аспекта отсутствует\n\n";
    }

    description += "♂️ Мужская дуальность личности (реализация в социуме) проявляется через аспект ${getAspectLinkText(maleInner, maleOuter)}:\n";
    if (maleData.isNotEmpty) {
      description += "*${maleData['aspect_name'] ?? 'Название'} (${maleData['aspect_key'] ?? 'Роли'})*\n\n"
          "**🧠 Ключевое качество:**  \n${maleData['aspect_strength'] ?? 'Описание отсутствует'}\n\n"
          "**⚡ Вызов (опасность):**  \n${maleData['aspect_challenge'] ?? 'Описание отсутствует'}\n\n"
          "**🌍 Проявление в жизни:**  \n${maleData['aspect_inlife'] ?? 'Описание отсутствует'}\n\n"
          "**❓ Вопрос для рефлексии:**  \n${maleData['aspect_question'] ?? 'Вопрос отсутствует'}\n\n";
    } else {
      description += "Описание аспекта отсутствует\n\n";
    }

    // Others
    final zone9 = getZone(numbers[8]);
    description += "🎯 Основной мотив личности проявляется через ${numbers[8]} Роль подсознания (${zone9['role_name'] ?? 'Название'}):\n${zone9['motive'] ?? 'Описание отсутствует'}\n\n";

    final zone10 = getZone(numbers[9]);
    description += "🛠 Основной способ действия обусловлен ${numbers[9]} Ролью подсознания (${zone10['role_name'] ?? 'Название'}):\n${zone10['action'] ?? 'Описание отсутствует'}\n\n";

    final zone11 = getZone(numbers[10]);
    description += "🌐 Подходящая сфера реализации обусловлена ${numbers[10]} Ролью подсознания (${zone11['role_name'] ?? 'Название'}):\n${zone11['field'] ?? 'Описание отсутствует'}\n\n";

    final zone13 = getZone(numbers[12]);
    description += "🚪 Точка выхода обусловлена ${numbers[12]} Ролью подсознания (${zone13['role_name'] ?? 'Название'}):\n${zone13['out'] ?? 'Описание отсутствует'}\n\n";

    final zone12 = getZone(numbers[11]);
    description += "💭 \"Внутренний мир\" личности проявляется через ${numbers[11]} Роль подсознания (${zone12['role_name'] ?? 'Название'}):\n${zone12['fear'] ?? 'Описание отсутствует'}\n\n";

    final zone14 = getZone(numbers[13]);
    description += "⚖️ Баланс внешнего/внутреннего проявляется через ${numbers[13]} Роль подсознания (${zone14['role_name'] ?? 'Название'}):\n${zone14['out'] ?? 'Описание отсутствует'}\n\n";

    // Stress
    final zoneX = getZone(x);
    final zoneY = getZone(y);
    description += "🧠 В стрессе личность проявляется через $x Роль подсознания (${zoneX['role_name'] ?? 'Название'}):\n${zoneX['fear'] ?? 'Описание отсутствует'}\n\n";
    description += "⚖️ Сбалансировать состояние в стрессе можно через проявление $y Роли подсознания (${zoneY['role_name'] ?? 'Название'}):\n${zoneY['description'] ?? 'Описание отсутствует'}\n\n";
    
    // description += "*(Подробнее 20 кр)*";

    return description;
  }
}
