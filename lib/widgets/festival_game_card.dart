import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/festival_game.dart';

import 'package:id_diagnostic_app/widgets/game_details_dialog.dart';

import '../data/festival_content.dart';
import '../widgets/festival_game_card.dart'; // Self-referential if needed, but we are inside it.
// We need to remove the loop import if FestivalGameCard is in widgets.
// Actually we stand alone.

class FestivalGameCard extends StatelessWidget {
  final FestivalGame game;
  final bool isRegistered;
  final bool isMaster; // New flag
  final VoidCallback onRegister;
  final VoidCallback? onManage; // For masters/admins
  final VoidCallback? onShowParticipants; // New callback

  const FestivalGameCard({
    super.key,
    required this.game,
    required this.isRegistered,
    required this.onRegister,
    this.isMaster = false,
    this.onManage,
    this.onShowParticipants,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('HH:mm');
    final timeStr = "${dateFormat.format(game.startTime)} - ${dateFormat.format(game.endTime)}";

    // Lookup content
    final content = festivalContent[game.title] ?? festivalContent.values.firstWhere(
        (c) => c.title.contains(game.title) || game.title.contains(c.title),
        orElse: () => FestivalActivityContent(
            masterName: game.masterName, 
            title: game.title, 
            description: game.description, 
            imagePath: "", 
            color: Colors.white, 
            role: ""
        )
    );


    return InkWell(
      onTap: () {
         showDialog(
           context: context,
           builder: (_) => _buildRichGameDialog(context, content),
         );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          border: Border.all(color: Colors.white10),
          borderRadius: BorderRadius.circular(16),
          // gradient: LinearGradient(colors: [content.color.withOpacity(0.1), Colors.transparent])
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
                    color: content.color.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    timeStr,
                    style: TextStyle(color: content.color, fontWeight: FontWeight.bold),
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
              content.description.isNotEmpty ? content.description : game.description,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                InkWell(
                   onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                           backgroundColor: const Color(0xFF1E293B),
                           title: Text(game.location, style: const TextStyle(color: Colors.white)),
                           content: const Text("Карта мероприятия будет доступна позже.", style: TextStyle(color: Colors.white70)),
                           actions: [
                              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Закрыть")),
                           ],
                        )
                      );
                   },
                   child: Row(
                     children: [
                       const Icon(Icons.location_on, color: Colors.white30, size: 16),
                       const SizedBox(width: 4),
                       Text(
                         game.location,
                         style: const TextStyle(color: Colors.white30, fontSize: 12, decoration: TextDecoration.underline),
                       ),
                     ],
                   ),
                ),
                const Spacer(),
                if (isMaster)
                   ElevatedButton.icon(
                      onPressed: onShowParticipants,
                      icon: const Icon(Icons.people, size: 16),
                      label: Text("Участники (${game.participants.length})"),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                   )
                else
                   _buildActionBtn(content.color),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildRichGameDialog(BuildContext context, FestivalActivityContent content) {
      return Dialog(
         backgroundColor: const Color(0xFF1E293B),
         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
         child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SingleChildScrollView(
               child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                     if (content.imagePath.isNotEmpty)
                        ClipRRect(
                           borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                           child: Image.asset(content.imagePath, height: 200, width: double.infinity, fit: BoxFit.cover,
                             errorBuilder: (c,e,s) => Container(height: 100, color: content.color.withOpacity(0.2), child: const Icon(Icons.image_not_supported, color: Colors.white54)),
                           ),
                        ),
                     Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                               Text(content.title, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                               const SizedBox(height: 8),
                               Row(children: [
                                  CircleAvatar(backgroundColor: content.color, radius: 4),
                                  const SizedBox(width: 8),
                                  Text(content.masterName, style: const TextStyle(color: Colors.white70, fontSize: 16)),
                               ]),
                               if (content.role.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 16),
                                    child: Text(content.role, style: TextStyle(color: content.color, fontSize: 12)),
                                  ),
                               const SizedBox(height: 16),
                               Text(content.description, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5)),
                               const SizedBox(height: 24),
                               
                               // Action Buttons
                               Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                     TextButton(onPressed: () => Navigator.pop(context), child: const Text("Закрыть")),
                                     const SizedBox(width: 8),
                                     _buildActionBtn(content.color, isDialog: true),
                                  ],
                               )
                           ],
                        ),
                     )
                  ],
               ),
            ),
         ),
      );
  }

  Widget _buildActionBtn(Color color, {bool isDialog = false}) {
    if (isRegistered) {
      return InkWell(
        onTap: onRegister, // Trigger action to allow Unsubscribe
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.green),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.check, size: 16, color: Colors.green),
              SizedBox(width: 4),
              Text("Вы записаны", style: TextStyle(color: Colors.green)),
            ],
          ),
        ),
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
        backgroundColor: color == Colors.white ? Colors.blueAccent : color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: isDialog ? const EdgeInsets.symmetric(horizontal: 32, vertical: 12) : null,
      ),
      child: Text("Записаться (${game.placesLeft})", style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}
