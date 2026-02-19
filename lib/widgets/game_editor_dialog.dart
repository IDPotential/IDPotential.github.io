import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/festival_game.dart';
import '../services/firestore_service.dart';
import 'package:intl/intl.dart';
import '../data/festival_master_data.dart';

class GameEditorDialog extends StatefulWidget {
  final FestivalGame? game; // If null, create new

  const GameEditorDialog({super.key, this.game});

  @override
  State<GameEditorDialog> createState() => _GameEditorDialogState();
}

class _GameEditorDialogState extends State<GameEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _masterNameController = TextEditingController();
  final _locationController = TextEditingController();
  final _maxPlayersController = TextEditingController(text: "10");
  final _durationController = TextEditingController(text: "60");
  int? _selectedSlotId; 
  
  // ... inside _GameEditorDialogState
  String? _selectedSecondMasterUid; // New field

  // ... (initState and loadData unchanged)

  // ... inside _onExcelMasterSelected
  Future<void> _onExcelMasterSelected(Map<String, String>? selection) async {
    if (selection == null) return;
    
    setState(() {
      _selectedExcelMaster = selection;
      _titleController.text = selection['gameTitle']!;
      _isLoading = true; 
    });

    try {
      final String currentTitle = selection['gameTitle']!;
      final String currentTicket = selection['ticketLogin']!;
      
      // 1. Find ALL masters for this game title (e.g. Nadezhda & Toma)
      final allBriefs = festivalMasterData.where((e) => e['gameTitle'] == currentTitle).toList();
      
      List<String> tickets = [];
      List<String> uids = [];
      List<String> names = []; // For info

      String? mainUid;
      String? secondUid;
      String? mainName = selection['masterName'];

      final usersRef = FirebaseFirestore.instance.collection('users');

      // 2. Resolve UIDs for all found tickets
      for (var entry in allBriefs) {
         final t = entry['ticketLogin']!;
         tickets.add(t);
         
         // Lookup User
         String? uid;
         final ticketQuery = await usersRef.where('ticket', isEqualTo: t).limit(1).get();
         if (ticketQuery.docs.isNotEmpty) {
            uid = ticketQuery.docs.first.id;
            final d = ticketQuery.docs.first.data();
            String n = "${d['first_name'] ?? ''} ${d['last_name'] ?? ''}".trim();
            if (n.isEmpty) n = d['username'] ?? 'User';
            names.add(n);
         } else {
             // Try Technical
             final techEmail = "$t@idpotential.festival";
             final emailQuery = await usersRef.where('email', isEqualTo: techEmail).limit(1).get();
             if (emailQuery.docs.isNotEmpty) {
                uid = emailQuery.docs.first.id;
             }
         }
         
         if (uid != null) {
            uids.add(uid);
            if (t == currentTicket) {
               mainUid = uid;
               if (names.isNotEmpty && names.last.isNotEmpty) mainName = names.last;
            } else {
               secondUid = uid; // Take the first "other" as second
            }
         }
      }

      if (mounted) {
        setState(() {
           _activityMasterTickets = tickets;
           _selectedMasterUid = mainUid;
           _selectedSecondMasterUid = secondUid;
           
           if (mainUid != null && mainName != null) {
              _masterNameController.text = mainName;
           } else {
              _masterNameController.text = selection['masterName']!;
           }
           
           // If we found a second user but the text controller only shows one name, 
           // maybe we should append the second name?
           // But the UI has a separate dropdown now. 
           // If we didn't find a UID for the second, we might want to manually append their name to the text field?
           // For "Nadezhda / Toma", if Toma is not registered, her UID is null.
           // Checks if "Toma" is in masterName?
           if (allBriefs.length > 1 && secondUid == null) {
              // If second master not found as user, ensure their name is in the text field?
              // Or just let the user handle it. The 'masterName' from excel is usually single.
              // We can hint.
              final otherNames = allBriefs.where((e) => e['ticketLogin'] != currentTicket).map((e) => e['masterName']).join(" / ");
               if (otherNames.isNotEmpty && !_masterNameController.text.contains(otherNames)) {
                  _masterNameController.text = "${_masterNameController.text} / $otherNames";
               }
           }
        });
      }

    } catch (e) {
      debugPrint("Error finding user for ticket: $e");
      if (mounted) {
         setState(() {
            _masterNameController.text = selection['masterName']!;
         });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ... build method ...
  // Insert Second Master Dropdown after First Master Dropdown

              // 2. Master Selection (Admin/User list)
              if (_loadingMasters)
                 const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator())
              else if (_masters.isNotEmpty) ...[
                 Padding(
                   padding: const EdgeInsets.only(bottom: 12),
                   child: DropdownButtonFormField<String>(
                      value: _masters.any((m) => m['uid'] == _selectedMasterUid) ? _selectedMasterUid : null,
                      // ... existing props ...
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                         labelText: "Мастер (основной)",
                         labelStyle: TextStyle(color: Colors.white54),
                         enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                      ),
                      items: [
                         const DropdownMenuItem<String>(value: null, child: Text("Не выбран / Внешний мастер")),
                         ..._masters.map((m) {
                           return DropdownMenuItem<String>(
                              value: m['uid'],
                              child: Text(m['name']),
                           );
                        }),
                      ],
                      onChanged: (val) {
                         setState(() {
                            _selectedMasterUid = val;
                            if (val != null) {
                               final selected = _masters.firstWhere((m) => m['uid'] == val);
                               if (_masterNameController.text.isEmpty) {
                                  _masterNameController.text = selected['name'];
                               }
                            }
                         });
                      },
                   ),
                 ),
                 
                 // SECOND MASTER
                 Padding(
                   padding: const EdgeInsets.only(bottom: 12),
                   child: DropdownButtonFormField<String>(
                      value: _masters.any((m) => m['uid'] == _selectedSecondMasterUid) ? _selectedSecondMasterUid : null,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                         labelText: "Второй мастер (опционально)",
                         labelStyle: TextStyle(color: Colors.white54),
                         enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                         helperText: "Сможет также видеть участников",
                         helperStyle: TextStyle(color: Colors.white30),
                      ),
                      items: [
                         const DropdownMenuItem<String>(value: null, child: Text("Нет")),
                         ..._masters.map((m) {
                           return DropdownMenuItem<String>(
                              value: m['uid'],
                              child: Text(m['name']),
                           );
                        }),
                      ],
                      onChanged: (val) {
                         setState(() {
                            _selectedSecondMasterUid = val;
                         });
                      },
                   ),
                 ),
              ],


  // ... _saveGame update ...
      final game = FestivalGame(
        id: widget.game?.id ?? '',
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        masterId: _selectedMasterUid ?? widget.game?.masterId ?? user.uid,
        masterName: _masterNameController.text.trim(),
        startTime: _selectedDate,
        durationMinutes: int.parse(_durationController.text),
        location: _locationController.text.trim(),
        maxParticipants: int.parse(_maxPlayersController.text),
        participants: widget.game?.participants ?? [],
        slotId: _selectedSlotId,
        activityId: _selectedActivityId,
        masterTickets: _activityMasterTickets,
        masterIds: [
           if (_selectedMasterUid != null) _selectedMasterUid!,
           if (_selectedSecondMasterUid != null) _selectedSecondMasterUid!
        ].toSet().toList(), // Ensure uniqueness
      );

}
