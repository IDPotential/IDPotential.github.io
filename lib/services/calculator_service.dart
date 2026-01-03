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
  
  static String formatScheme(List<int> numbers, String name, String date, String gender) {
    final nums = numbers;
    
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
    final frequency = <int, int>{};
    for (final num in numbers) {
      frequency[num] = (frequency[num] ?? 0) + 1;
    }
    
    final accents = frequency.entries.where((e) => e.value == 2).map((e) => e.key).toList();
    final dominants = frequency.entries.where((e) => e.value == 3).map((e) => e.key).toList();
    final neurosis = frequency.entries.where((e) => e.value >= 4).map((e) => e.key).toList();
    
    // Расчет X (поведение в стрессе)
    int x = numbers[3] + numbers[10];
    // Fix: Python logic uses data[6] (num7) for Female, data[5] (num6) for Male
    // numbers indices: num6 is index 5, num7 is index 6
    x += gender == 'Ж' ? numbers[6] : numbers[5];
    x = reduceNumber(x);
    
    // Расчет Y (баланс в стрессе)
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