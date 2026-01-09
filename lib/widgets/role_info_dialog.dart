import 'package:flutter/material.dart';
import '../services/knowledge_service.dart';

class RoleInfoDialog extends StatelessWidget {
  final int roleNumber;
  final bool canSelect;
  final VoidCallback? onSelect;

  const RoleInfoDialog({
    super.key,
    required this.roleNumber,
    this.canSelect = false,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final info = KnowledgeService.getRoleInfo(roleNumber);
    final name = info['role_name'] ?? 'Роль $roleNumber';
    final description = info['description'] ?? 'Описание отсутствует';
    
    final keyQuality = info['role_key'] ?? '';
    final strength = info['role_strength'] ?? '';
    final challenge = info['role_challenge'] ?? '';
    final roleInLife = info['role_inlife'] ?? '';
    final question = info['role_question'] ?? '';

    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: Text('$roleNumber. $name', style: const TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
             if (keyQuality.isNotEmpty) ...[
               const Text("Ключевое качество:", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
               Text(keyQuality, style: const TextStyle(color: Colors.white60)),
               const SizedBox(height: 12),
             ],

             Text(description, style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4)),
             const SizedBox(height: 16),
             
             if (strength.isNotEmpty) ...[
               const Text("Сила роли:", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
               Text(strength, style: const TextStyle(color: Colors.white60)),
               const SizedBox(height: 8),
             ],
             
             if (challenge.isNotEmpty) ...[
               const Text("Вызов (ловушка):", style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
               Text(challenge, style: const TextStyle(color: Colors.white60)),
               const SizedBox(height: 8),
             ],
             
             if (roleInLife.isNotEmpty) ...[
               const Text("В жизни:", style: TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold)),
               Text(roleInLife, style: const TextStyle(color: Colors.white60)),
               const SizedBox(height: 8),
             ],

             if (question.isNotEmpty) ...[
                const Text("Вопрос для рефлексии:", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                Text(question, style: const TextStyle(color: Colors.white60, fontStyle: FontStyle.italic)),
             ]
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context), 
          child: const Text("Закрыть", style: TextStyle(color: Colors.grey))
        ),
        if (canSelect && onSelect != null)
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            onPressed: () {
               onSelect!();
               Navigator.pop(context);
            }, 
            child: const Text("Выбрать эту роль")
          ),
      ],
    );
  }
}
