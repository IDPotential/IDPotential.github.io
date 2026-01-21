import 'package:flutter/material.dart';

class DayPhaseWidget extends StatelessWidget {
  final Map<String, dynamic> state;

  const DayPhaseWidget({
    super.key,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
       decoration: const BoxDecoration(
          image: DecorationImage(image: AssetImage('assets/images/fon.png'), fit: BoxFit.cover, opacity: 0.3)
       ),
       child: Center(
          child: Column(
             mainAxisAlignment: MainAxisAlignment.center,
             children: [
                const Icon(Icons.wb_sunny, color: Colors.orangeAccent, size: 80),
                const SizedBox(height: 16),
                const Text(
                   "День", 
                   style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)
                ),
                const SizedBox(height: 8),
                const Text(
                   "Время для обсуждения...", 
                   style: TextStyle(color: Colors.white70, fontSize: 16)
                ),
                const SizedBox(height: 32),
                // Timer placeholder
                Container(
                   padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                   decoration: BoxDecoration(
                      border: Border.all(color: Colors.orangeAccent),
                      borderRadius: BorderRadius.circular(20)
                   ),
                   child: const Text("02:00", style: TextStyle(color: Colors.white, fontSize: 24, fontFamily: 'monospace')),
                )
             ],
          ),
       ),
    );
  }
}
