import 'package:flutter/material.dart';
import 'package:id_diagnostic_app/widgets/role_info_dialog.dart'; // Import Custom Dialog Correctly

class DiagnosticSchemeWidget extends StatelessWidget {
  final List<int> numbers;
  final String gender;
  final String name;
  final String birthDate;

  const DiagnosticSchemeWidget({
    super.key,
    required this.numbers,
    required this.gender,
    required this.name,
    required this.birthDate,
  });

  void _showRoleInfo(BuildContext context, int number) {
     showDialog(
       context: context,
       builder: (context) => RoleInfoDialog(roleNumber: number),
     );
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;

          // Base dimensions from the template
          const baseWidth = 1080.0;
          const baseHeight = 1080.0;

          // Helper to scale coordinates
          double scaleX(double x) => (x / baseWidth) * width;
          double scaleY(double y) => (y / baseHeight) * height;
          // Scale font size relative to width (50px on 1080px base)
          double fontSize = (50.0 / baseWidth) * width; 
          double captionSize = (40.0 / baseWidth) * width;

          // Normalize gender: 'Ж' or 'F' -> Female, else Male
          // This ensures the map layout matches the "Male default" logic if needed
          // But wait, positions logic below relies on exact keys 'М' and 'Ж'.
          // We should handle that safely.
          final isFemale = gender == 'Ж' || gender == 'F';
          final effectiveGenderKey = isFemale ? 'Ж' : 'М';

          // Coordinates map (from bot logic)
          final Map<String, Map<String, Offset>> positions = {
            'М': {
              'num1': const Offset(335, 220),
              'num2': const Offset(538, 220),
              'num3': const Offset(740, 220),
              'num4': const Offset(975, 220),
              'num5': const Offset(230, 375),
              'num6': const Offset(435, 375),
              'num7': const Offset(637, 375),
              'num8': const Offset(840, 375),
              'num9': const Offset(538, 505),
              'num10': const Offset(538, 680),
              'num11': const Offset(680, 590),
              'num12': const Offset(970, 540),
              'num13': const Offset(539, 855),
              'num14': const Offset(800, 732),
            },
            'Ж': {
              'num1': const Offset(335, 220),
              'num2': const Offset(538, 220),
              'num3': const Offset(740, 220),
              'num4': const Offset(975, 220),
              'num5': const Offset(230, 375),
              'num6': const Offset(435, 375),
              'num7': const Offset(637, 375),
              'num8': const Offset(840, 375),
              'num9': const Offset(538, 505),
              'num10': const Offset(538, 680),
              'num11': const Offset(680, 590),
              'num12': const Offset(100, 540),
              'num13': const Offset(539, 855),
              'num14': const Offset(275, 732),
            },
          };

          // Dashes logic
          final genderPositions = positions[effectiveGenderKey]!;
          final dashes = effectiveGenderKey == 'М' 
              ? [const Offset(100, 540), const Offset(275, 732)] 
              : [const Offset(970, 540), const Offset(800, 732)];

          return Stack(
            children: [
              // Background Image
              Image.asset(
                'assets/images/IDPGMD092025.png',
                width: width,
                height: height,
                fit: BoxFit.cover,
              ),

              // Name and Date (top left)
              Positioned(
                left: scaleX(50),
                top: scaleY(50),
                child: Text(
                  '$name ($birthDate)',
                  style: TextStyle(
                    fontFamily: 'DINPro',
                    fontSize: captionSize,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              // Numbers
              ...List.generate(numbers.length, (index) {
                final numKey = 'num${index + 1}';
                final pos = genderPositions[numKey]!;
                final roleNum = numbers[index];
                
                return Positioned(
                  left: scaleX(pos.dx),
                  top: scaleY(pos.dy),
                  child: Transform.translate(
                    offset: Offset(-fontSize, -fontSize / 1.5), 
                    child: GestureDetector(
                       onTap: () => _showRoleInfo(context, roleNum),
                       child: SizedBox(
                        width: fontSize * 2,
                        child: Text(
                          '$roleNum',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontFamily: 'DINPro',
                              fontSize: fontSize,
                              color: Colors.black, // Color kept black
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline, // Visual cue for clickable
                              decorationStyle: TextDecorationStyle.dotted,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),

              // Dashes
              ...dashes.map((pos) => Positioned(
                left: scaleX(pos.dx),
                top: scaleY(pos.dy),
                 child: Transform.translate(
                    offset: Offset(-fontSize, -fontSize / 1.5),
                    child: SizedBox(
                      width: fontSize * 2,
                      child: Text(
                        '--',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'DINPro',
                          fontSize: fontSize,
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              )),
            ],
          );
        },
      ),
    );
  }
}

