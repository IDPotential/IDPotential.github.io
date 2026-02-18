
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/festival_game.dart';

class GameDetailsDialog extends StatefulWidget {
  final FestivalGame game;
  final bool isRegistered;
  final VoidCallback onRegister;

  const GameDetailsDialog({
    super.key,
    required this.game,
    required this.isRegistered,
    required this.onRegister,
  });

  @override
  State<GameDetailsDialog> createState() => _GameDetailsDialogState();
}

class _GameDetailsDialogState extends State<GameDetailsDialog> {
  List<Map<String, dynamic>> _masters = [];
  bool _loadingMasters = true;

  @override
  void initState() {
    super.initState();
    _loadMasters();
  }

  Future<void> _loadMasters() async {
    if (widget.game.masterIds.isEmpty) {
      if (mounted) setState(() => _loadingMasters = false);
      return;
    }

    try {
      // Fetch users who are masters for this game
      // Firestore 'in' query supports up to 10 items
      final ids = widget.game.masterIds.take(10).toList(); 
      if (ids.isEmpty) {
          setState(() => _loadingMasters = false);
          return;
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: ids)
          .get();

      final masters = snapshot.docs.map((doc) => doc.data()).toList();
      
      if (mounted) {
        setState(() {
          _masters = masters;
          _loadingMasters = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading masters: $e");
      if (mounted) setState(() => _loadingMasters = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 800),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Stack(
              children: [
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.2),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Center(
                    child: Icon(Icons.casino, size: 60, color: Colors.purpleAccent.withOpacity(0.5)),
                  ),
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
            
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.game.title,
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                     Row(
                      children: [
                          const Icon(Icons.access_time, color: Colors.amberAccent, size: 16),
                          const SizedBox(width: 8),
                          Text("${widget.game.durationMinutes} мин", style: const TextStyle(color: Colors.white70)),
                          const SizedBox(width: 16),
                          const Icon(Icons.location_on, color: Colors.amberAccent, size: 16),
                          const SizedBox(width: 8),
                          Text(widget.game.location, style: const TextStyle(color: Colors.white70)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    const Text("О ИГРЕ", style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 1)),
                    const SizedBox(height: 8),
                    Text(
                      widget.game.description.isEmpty ? "Описание отсутствует" : widget.game.description,
                      style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.5),
                    ),
                    
                    const SizedBox(height: 32),
                    const Text("ВЕДУЩИЕ", style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 1)),
                    const SizedBox(height: 12),
                    if (_loadingMasters)
                       const Center(child: CircularProgressIndicator())
                    else if (_masters.isNotEmpty)
                       ..._masters.map((m) => _buildMasterTile(m))
                    else
                       // Fallback to text name if no IDs linked
                       ListTile(
                         leading: const CircleAvatar(backgroundColor: Colors.white10, child: Icon(Icons.person, color: Colors.white70)),
                         title: Text(widget.game.masterName, style: const TextStyle(color: Colors.white)),
                         contentPadding: EdgeInsets.zero,
                       ),
                  ],
                ),
              ),
            ),
            
            // Footer Action
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: widget.isRegistered
                ? OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.check, color: Colors.green),
                    label: const Text("Вы записаны", style: TextStyle(color: Colors.green, fontSize: 16)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.green)),
                  )
                : ElevatedButton(
                    onPressed: widget.game.placesLeft > 0 ? () {
                       widget.onRegister();
                       Navigator.pop(context);
                    } : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      disabledBackgroundColor: Colors.grey.withOpacity(0.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      widget.game.placesLeft > 0 ? "Записаться на игру" : "Мест нет",
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildMasterTile(Map<String, dynamic> data) {
    final photo = data['photo_url'];
    final name = "${data['first_name'] ?? ''} ${data['last_name'] ?? ''}".trim();
    final bio = data['bio'] ?? ''; // Assuming bio might exist or we just show role

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
             width: 50, height: 50,
             decoration: BoxDecoration(
               shape: BoxShape.circle,
               color: Colors.white10,
               image: photo != null ? DecorationImage(image: NetworkImage(photo), fit: BoxFit.cover) : null,
             ),
             child: photo == null ? const Icon(Icons.person, color: Colors.white54) : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                if (bio.isNotEmpty)
                   Text(bio, style: const TextStyle(color: Colors.white54, fontSize: 12), maxLines: 1),
              ],
            ),
          )
        ],
      ),
    );
  }
}
