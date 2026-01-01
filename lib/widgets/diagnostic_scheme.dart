import 'package:flutter/material.dart';

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
              // Dashes
              // 'dash1': Offset(100, 540), // Logic check: Python dash1 is 100,540 for Male
              // 'dash2': Offset(275, 732),
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

          // Dashes are hardcoded in the list builder below or added as special cases
          final genderPositions = positions[gender] ?? positions['М']!;
          final dashes = gender == 'М' 
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
                return Positioned(
                  left: scaleX(pos.dx),
                  top: scaleY(pos.dy),
                  child: Transform.translate(
                    offset: Offset(-fontSize, -fontSize / 1.5), // Adjusted vertical alignment
                    child: SizedBox(
                       // Ensure enough width to center text
                      width: fontSize * 2,
                      child: Text(
                        '${numbers[index]}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontFamily: 'DINPro',
                            fontSize: fontSize,
                            color: Colors.black, // Changed to black
                            fontWeight: FontWeight.bold,
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
                    offset: Offset(-fontSize, -fontSize / 1.5), // Adjusted vertical alignment
                    child: SizedBox(
                      width: fontSize * 2,
                      child: Text(
                        '--',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'DINPro',
                          fontSize: fontSize,
                          color: Colors.black, // Changed to black
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
