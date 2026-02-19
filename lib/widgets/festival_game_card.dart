import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/festival_game.dart';

import 'package:id_diagnostic_app/widgets/game_details_dialog.dart';

import '../data/festival_content.dart';
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
    FestivalActivityContent? foundContent;
    
    // 1. Try exact master name match (High Priority)
    try {
       foundContent = festivalContent.values.firstWhere((c) => c.masterName.trim().toLowerCase() == game.masterName.trim().toLowerCase());
    } catch (_) {}

    // 2. Try exact title match
    if (foundContent == null) {
       foundContent = festivalContent[game.title];
    }

    // 3. Try fuzzy title match
    foundContent ??= festivalContent.values.firstWhere(
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

    final content = foundContent!;

    return InkWell(
      onTap: () {
         showDialog(
           context: context,
           builder: (_) => _buildRichGameDialog(context, content),
         );
      },
      child: Container(
        // margin: const EdgeInsets.only(bottom: 12), // Handled by GridView spacing
        padding: const EdgeInsets.all(8), // Reduced padding
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          border: Border.all(color: Colors.white10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Time & Settings
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: content.color.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    timeStr,
                    style: TextStyle(color: content.color, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
                if (game.ageLimit != null)
                   Padding(
                     padding: const EdgeInsets.only(left: 8),
                     child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                           color: Colors.white10,
                           borderRadius: BorderRadius.circular(4),
                           border: Border.all(color: Colors.white24),
                        ),
                        child: Text("${game.ageLimit}+", style: const TextStyle(color: Colors.white70, fontSize: 10)),
                     ),
                   ),
                const Spacer(),
                if (onManage != null)
                  InkWell(
                     onTap: onManage,
                     child: const Padding(
                       padding: EdgeInsets.all(4.0),
                       child: Icon(Icons.settings, color: Colors.white54, size: 16),
                     ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            
            // Title & Info
            Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               mainAxisSize: MainAxisSize.min, // Compact
               children: [
                   Text(
                     game.title,
                     style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, height: 1.2),
                     maxLines: 2,
                     overflow: TextOverflow.ellipsis,
                   ),
                   const SizedBox(height: 2),
                   Text(
                     game.masterName,
                     style: const TextStyle(color: Colors.white70, fontSize: 11),
                     maxLines: 1,
                     overflow: TextOverflow.ellipsis,
                   ),
                   // Description hidden on card to save space, available in dialog
               ]
            ),
            
            const SizedBox(height: 12), // Fixed gap instead of Spacer


            
            const SizedBox(height: 8),
            
            // Footer: Location & Action
            Column(
               crossAxisAlignment: CrossAxisAlignment.stretch,
               children: [
                  // Location
                  if (game.location.isNotEmpty)
                  Row(
                     children: [
                       const Icon(Icons.location_on, color: Colors.white30, size: 12),
                       const SizedBox(width: 4),
                       Expanded(
                         child: Text(
                           game.location,
                           style: const TextStyle(color: Colors.white30, fontSize: 10),
                           maxLines: 1,
                           overflow: TextOverflow.ellipsis,
                         ),
                       ),
                     ],
                  ),
                  const SizedBox(height: 6),
                  
                  // Button
                  if (isMaster)
                     SizedBox(
                        height: 32,
                        child: ElevatedButton(
                           onPressed: onShowParticipants,
                           style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber, 
                              foregroundColor: Colors.black,
                              padding: EdgeInsets.zero,
                              textStyle: const TextStyle(fontSize: 12)
                           ),
                           child: Text("Игроки (${game.participants.length})"),
                        ),
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
                     if (content.secondaryImagePath != null && content.secondaryImagePath!.isNotEmpty)
                        ClipRRect(
                           borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                           child: Image.asset(content.secondaryImagePath!, height: 200, width: double.infinity, fit: BoxFit.cover,
                             errorBuilder: (c,e,s) => Container(height: 100, color: content.color.withOpacity(0.2), child: const Icon(Icons.image_not_supported, color: Colors.white54)),
                           ),
                        )
                     else if (content.imagePath.isNotEmpty)
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
      if (isDialog) {
         return ElevatedButton.icon(
           onPressed: onRegister, 
           icon: const Icon(Icons.check, size: 16),
           label: const Text("Вы записаны"),
           style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
         );
      }
      return InkWell(
        onTap: onRegister,
        child: Container(
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green),
          ),
          child: const Text("Вы идут", style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
        ),
      );
    }

    if (game.placesLeft <= 0) {
      return Container(
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text("Мест нет", style: TextStyle(color: Colors.grey, fontSize: 12)),
      );
    }

    return SizedBox(
      height: 32,
      child: ElevatedButton(
        onPressed: onRegister,
        style: ElevatedButton.styleFrom(
          backgroundColor: color == Colors.white ? Colors.blueAccent : color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: EdgeInsets.zero, // Compact
        ),
        child: Text(
           isDialog ? "Записаться" : "Запись (${game.placesLeft})", 
           style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)
        ),
      ),
    );
  }
}
