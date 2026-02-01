class CalculatorService {
  static int reduceNumber(int num) {
    while (num > 22) {
      num -= 22;
    }
    return num == 22 ? 0 : num;
  }
  
  static List<int> calculateDiagnostic(String dateStr, String name, String gender) {
    // Разбираем дату
    final parts = dateStr.split('.');
    final day = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final year = int.parse(parts[2]);
    
    // Расчет чисел (аналогично Python коду)
    final num1 = reduceNumber(day);
    final num2 = month;
    final num3 = reduceNumber(year.toString().split('').map((d) => int.parse(d)).reduce((a, b) => a + b));
    final num4 = reduceNumber(num1 + num2 + num3);
    final num6 = reduceNumber(num1 + num2);
    final num5 = reduceNumber(22 - num6);
    final num7 = reduceNumber(num2 + num3);
    final num8 = reduceNumber(22 - num7);
    final num9 = reduceNumber(num6 + num7);
    final num10 = reduceNumber((num6 - num7).abs() + num9);
    final num11 = reduceNumber(num9 + num10);
    final num12 = reduceNumber(num4 + (gender == 'М' ? num8 : num5) + num11);
    final num13 = reduceNumber(num1 + num3 + num10);
    final num14 = reduceNumber(num12 + num13);
    
    return [num1, num2, num3, num4, num5, num6, num7, num8, num9, num10, num11, num12, num13, num14];
  }

  // --- Classic Diagnostics (Tarot + Pythagoras) ---

  static Map<String, dynamic> calculateClassic(String dateStr) {
    final parts = dateStr.split('.');
    final dayStr = parts[0];
    final monthStr = parts[1];
    final yearStr = parts[2];
    
    final day = int.parse(dayStr);
    final month = int.parse(monthStr);
    
    // 1. Tarot Calculation
    // Life Path
    final allDigits = '$dayStr$monthStr$yearStr';
    var lifePathSum = allDigits.split('').map((e) => int.parse(e)).fold(0, (a, b) => a + b);
    while (lifePathSum > 22) {
      lifePathSum = lifePathSum.toString().split('').map((e) => int.parse(e)).fold(0, (a, b) => a + b);
    }
    final lifePath = lifePathSum == 0 ? 22 : lifePathSum;

    // Personality (Day)
    var personality = day;
    while (personality > 22) {
      personality -= 22;
    }
    if (personality == 0) personality = 22; // Keep consistent with python logic if implied
    
    // Soul (Month)
    var soul = month;
    while (soul > 22) {
      soul -= 22; 
    }

    final tarot = {
      'lifePath': lifePath,
      'personality': personality,
      'soul': soul,
    };

    // 2. Pythagoras Calculation
    final firstNum = allDigits.split('').map((e) => int.parse(e)).fold(0, (a, b) => a + b);
    final secondNum = firstNum.toString().split('').map((e) => int.parse(e)).fold(0, (a, b) => a + b);
    
    int fDigit = int.parse(dayStr[0]);
    if (fDigit == 0 && dayStr.length > 1) fDigit = int.parse(dayStr[1]);
    
    final thirdNumFinal = firstNum - (2 * fDigit);
    final fourthNum = thirdNumFinal.abs().toString().split('').map((e) => int.parse(e)).fold(0, (a, b) => a + b);
    
    final workingNumbers = [firstNum, secondNum, thirdNumFinal, fourthNum];
    
    final matrixDigits = <int>[];
    matrixDigits.addAll(allDigits.split('').map((e) => int.parse(e)));
    for (var n in workingNumbers) {
      matrixDigits.addAll(n.abs().toString().split('').map((e) => int.parse(e)));
    }
    
    final matrix = List.generate(3, (_) => List.filled(3, 0));
    final analysis = <String, Map<String, dynamic>>{};
    
    for (var digit = 1; digit <= 9; digit++) {
      final count = matrixDigits.where((e) => e == digit).length;
      final row = (digit - 1) ~/ 3;
      final col = (digit - 1) % 3;
      matrix[row][col] = count;
      
      String strength;
      if (count == 0) strength = "отсутствует";
      else if (count == 1) strength = "слабое";
      else if (count == 2) strength = "нормальное";
      else if (count == 3) strength = "сильное";
      else strength = "избыточное";
      
      analysis[digit.toString()] = {
        'count': count,
        'strength': strength,
      };
    }

    return {
      'tarot': tarot,
      'pythagoras': {
        'workingNumbers': workingNumbers,
        'matrix': matrix,
        'analysis': analysis,
      }
    };
  }
  
  static String formatScheme(List<int> numbers, String name, String date, String gender) {
     // NOTE: This is for IDP. Classic format is handled elsewhere or via extraData
    final nums = numbers;
    if (nums.isEmpty) return '';

    if (gender == 'М') {
      return '''
Имя: $name
Дата: $date

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
Дата: $date

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
  
  static Map<String, dynamic> analyzeCalculation(List<int> numbers, String gender) {
    if (numbers.isEmpty) return {};

    final frequency = <int, int>{};
    for (final num in numbers) {
      frequency[num] = (frequency[num] ?? 0) + 1;
    }
    
    final accents = frequency.entries.where((e) => e.value == 2).map((e) => e.key).toList();
    final dominants = frequency.entries.where((e) => e.value == 3).map((e) => e.key).toList();
    final neurosis = frequency.entries.where((e) => e.value >= 4).map((e) => e.key).toList();
    
    int x = numbers[3] + numbers[10];
    x += gender == 'Ж' ? numbers[6] : numbers[5];
    x = reduceNumber(x);
    
    int y = x + numbers[12];
    y = reduceNumber(y);
    
    return {
      'accents': accents,
      'dominants': dominants,
      'neurosis': neurosis,
      'stress_behavior': x,
      'stress_balance': y,
    };
  }
}