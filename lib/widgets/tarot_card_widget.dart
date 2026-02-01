import 'package:flutter/material.dart';

class TarotCardWidget extends StatelessWidget {
  final int number;
  final String label; // "Life Path", "Personality", "Soul"

  const TarotCardWidget({
    super.key,
    required this.number,
    required this.label,
  });

  String getArcanaName(int number) {
     const names = {
      1: "Маг", 2: "Жрица", 3: "Императрица", 4: "Император",
      5: "Жрец", 6: "Влюбленные", 7: "Колесница", 8: "Справедливость",
      9: "Отшельник", 10: "Колесо Фортуны", 11: "Сила", 12: "Повешенный",
      13: "Смерть", 14: "Умеренность", 15: "Дьявол", 16: "Башня",
      17: "Звезда", 18: "Луна", 19: "Солнце", 20: "Суд",
      21: "Мир", 22: "Шут", 0: "Шут"
    };
    return names[number] ?? "Аркан $number";
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 100,
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Container(
              width: 50,
              height: 70,
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).primaryColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '$number',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              getArcanaName(number),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}
