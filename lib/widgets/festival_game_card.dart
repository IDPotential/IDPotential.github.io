import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/festival_game.dart';

import 'package:id_diagnostic_app/widgets/game_details_dialog.dart';

class FestivalGameCard extends StatelessWidget {
  final FestivalGame game;
  final bool isRegistered;
  final VoidCallback onRegister;
  final VoidCallback? onManage; // For masters/admins

  const FestivalGameCard({
    super.key,
    required this.game,
    required this.isRegistered,
    required this.onRegister,
    this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('HH:mm');
    final timeStr = "${dateFormat.format(game.startTime)} - ${dateFormat.format(game.endTime)}";


    return InkWell(
      onTap: () {
         showDialog(
           context: context,
           builder: (_) => GameDetailsDialog(
             game: game,
             isRegistered: isRegistered,
             onRegister: onRegister,
           ),
         );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          border: Border.all(color: Colors.white10),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    timeStr,
                    style: const TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold),
                  ),
                ),
                if (onManage != null)
                  IconButton(
                    icon: const Icon(Icons.settings, color: Colors.white54),
                    onPressed: onManage,
                    tooltip: "Управление",
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              game.title,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              "Мастер: ${game.masterName}",
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              game.description,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.white30, size: 16),
                const SizedBox(width: 4),
                Text(
                  game.location,
                  style: const TextStyle(color: Colors.white30, fontSize: 12),
                ),
                const Spacer(),
                _buildActionBtn(),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildActionBtn() {
    if (isRegistered) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.green),
        ),
        child: const Text("Вы записаны", style: TextStyle(color: Colors.green)),
      );
    }

    if (game.placesLeft <= 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text("Мест нет", style: TextStyle(color: Colors.grey)),
      );
    }

    return ElevatedButton(
      onPressed: onRegister,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blueAccent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: Text("Записаться (${game.placesLeft})"),
    );
  }
}
