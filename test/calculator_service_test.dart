import 'package:flutter_test/flutter_test.dart';
import 'package:id_diagnostic_app/services/calculator_service.dart';

void main() {
  group('CalculatorService', () {
    test('calculateDiagnostic 01.01.2000 Male', () {
      final result = CalculatorService.calculateDiagnostic('01.01.2000', 'Ivan', 'М');
      
      // Expected values derived from manual trace matching Python logic
      expect(result[0], 1); // num1
      expect(result[1], 1); // num2
      expect(result[2], 2); // num3
      expect(result[3], 4); // num4
      expect(result[5], 2); // num6 (calculated before num5)
      expect(result[4], 20); // num5 (22 - num6)
      expect(result[6], 3); // num7 (num2+num3)
      expect(result[7], 19); // num8 (22 - num7)
      expect(result[8], 5); // num9
      expect(result[9], 6); // num10
      expect(result[10], 11); // num11
      
      // Male specific num12: 4 + 19 + 11 = 34 -> 12
      expect(result[11], 12); // num12
      
      expect(result[12], 9); // num13
      
      // Male num14: 12 + 9 = 21
      expect(result[13], 21); // num14
    });

    test('analyzeCalculation Stress (X) Logic', () {
      // 01.01.2000
      // num4=4, num11=11
      // num6=2, num7=3
      
      // Male: X = 4 + 11 + num6(2) = 17
      final numsMale = CalculatorService.calculateDiagnostic('01.01.2000', 'Ivan', 'М');
      final analysisMale = CalculatorService.analyzeCalculation(numsMale, 'М');
      expect(analysisMale['stress_behavior'], 17);

      // Female: X = 4 + 11 + num7(3) = 18
      final numsFemale = CalculatorService.calculateDiagnostic('01.01.2000', 'Maria', 'Ж');
      final analysisFemale = CalculatorService.analyzeCalculation(numsFemale, 'Ж');
      expect(analysisFemale['stress_behavior'], 18);
    });
  });
}
