import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/festival_game.dart';
import '../services/firestore_service.dart';
import 'package:intl/intl.dart';
import '../data/festival_master_data.dart';
import '../data/festival_content.dart';

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
  final _ageLimitController = TextEditingController(); // New Age Limit
  int? _selectedSlotId; 
  
  List<Map<String, dynamic>> _masters = [];
  String? _selectedMasterUid;
  String? _selectedSecondMasterUid; // New field
  bool _loadingMasters = true;

  // Activity Catalog (Old)
  List<Map<String, dynamic>> _activities = [];
  String? _selectedActivityId;
  List<String> _activityMasterTickets = [];

  // Excel Data Selection
  Map<String, dynamic>? _selectedExcelMaster; // Changed to dynamic

  DateTime _selectedDate = DateTime(2026, 2, 21, 12, 0); 
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    if (widget.game != null) {
      _titleController.text = widget.game!.title;
      _descController.text = widget.game!.description;
      _masterNameController.text = widget.game!.masterName;
      _locationController.text = widget.game!.location;
      _maxPlayersController.text = widget.game!.maxParticipants.toString();
      _durationController.text = widget.game!.durationMinutes.toString();
      _ageLimitController.text = widget.game!.ageLimit?.toString() ?? ""; // Init Age
      _selectedDate = widget.game!.startTime;
      _selectedSlotId = widget.game!.slotId;
      _selectedMasterUid = widget.game!.masterId;
      _selectedActivityId = widget.game!.activityId;
      _activityMasterTickets = widget.game!.masterTickets;
      
      // Load second master if exists
      if (widget.game!.masterIds.isNotEmpty) {
         // Assuming the first one might be the main one, we look for others
         for (var uid in widget.game!.masterIds) {
            if (uid != widget.game!.masterId) {
               _selectedSecondMasterUid = uid;
               break; 
            }
         }
      }
    }
  }

  Future<void> _loadData() async {
     try {
        final mastersFuture = FirestoreService().getFestivalMasters();
        final activitiesFuture = FirestoreService().getFestivalActivities();
        
        final results = await Future.wait([mastersFuture, activitiesFuture]);
        
        if (mounted) {
           setState(() {
              _masters = results[0];
              _activities = results[1];
              _loadingMasters = false;
           });

           if (widget.game == null) {
              _prefillMaster();
           }
        }
     } catch (e) {
        debugPrint("Error loading data: $e");
        if (mounted) setState(() => _loadingMasters = false);
     }
  }

  void _prefillMaster() {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
         final me = _masters.firstWhere((m) => m['uid'] == user.uid, orElse: () => {});
         if (me.isNotEmpty) {
            _selectedMasterUid = me['uid'];
            _masterNameController.text = me['name'];
         }
      }
  }

  void _onActivitySelected(String? activityId) {
     if (activityId == null) return;
     final activity = _activities.firstWhere((a) => a['id'] == activityId, orElse: () => {});
     if (activity.isNotEmpty) {
        setState(() {
           _selectedActivityId = activityId;
           _titleController.text = activity['title'] ?? '';
           // Only overwrite description if empty or user wants to (here we just overwrite for simplicity in creation)
           if (_descController.text.isEmpty) {
               _descController.text = activity['description'] ?? '';
           }
           
           // If activity has masters, try to set the name
           final masters = List<String>.from(activity['masters'] ?? []);
           if (masters.isNotEmpty) {
              _masterNameController.text = masters.join(", ");
           }
           
           _activityMasterTickets = List<String>.from(activity['tickets'] ?? []);
        });
     }
  }

  Future<void> _onExcelMasterSelected(Map<String, dynamic>? selection) async {
    if (selection == null) return;
    
    setState(() {
      _selectedExcelMaster = selection;
      _titleController.text = selection['gameTitle'] as String;
      
      // Auto-fill max players if present
      if (selection['maxPlayers'] != null) {
          _maxPlayersController.text = selection['maxPlayers'].toString();
      }
      
      // Auto-fill age limit if present
      if (selection['ageLimit'] != null) {
          _ageLimitController.text = selection['ageLimit'].toString();
      }
      
      _isLoading = true; 
    });

    try {
      final String currentTitle = selection['gameTitle'] as String;
      final String currentTicket = selection['ticketLogin'] as String;
      
      // 1. Find ALL masters for this game title (e.g. Nadezhda & Toma)
      final allBriefs = festivalMasterData.where((e) => e['gameTitle'] == currentTitle).toList();
      
      List<String> tickets = [];
      List<String> names = []; // For info

      String? mainUid;
      String? secondUid;
      String? mainName = selection['masterName'] as String;

      final usersRef = FirebaseFirestore.instance.collection('users');

      // 2. Resolve UIDs for all found tickets
      for (var entry in allBriefs) {
         final t = entry['ticketLogin'] as String;
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
              _masterNameController.text = mainName!;
           } else {
              _masterNameController.text = selection['masterName'] as String;
           }
           
           if (allBriefs.length > 1 && secondUid == null) {
              final otherNames = allBriefs.where((e) => e['ticketLogin'] != currentTicket).map((e) => e['masterName']).join(" / ");
               if (otherNames.isNotEmpty && !_masterNameController.text.contains(otherNames)) {
                  _masterNameController.text = "${_masterNameController.text} / $otherNames";
               }
           }

           // Auto-fill Description & Master Name from FestivalContent
           final content = festivalContent[currentTitle] ?? festivalContent.values.firstWhere(
               (c) => c.title == currentTitle,
               orElse: () => FestivalActivityContent(
                   masterName: "", title: "", description: "", imagePath: "", color: Colors.white, role: ""
               )
           );
           
           if (content.description.isNotEmpty) {
               _descController.text = content.description;
           }
           if (content.masterName.isNotEmpty) {
               _masterNameController.text = content.masterName;
           }
        });
      }

    } catch (e) {
      debugPrint("Error finding user for ticket: $e");
      if (mounted) {
         setState(() {
            _masterNameController.text = selection['masterName'] as String;
         });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: Text(widget.game == null ? "Создать игру" : "Редактировать игру", style: const TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 0. Excel Selector (New)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: DropdownButtonFormField<Map<String, dynamic>>( // Changed to dynamic
                  decoration: const InputDecoration(
                    labelText: "Выбрать из списка (Excel)",
                    labelStyle: TextStyle(color: Colors.amberAccent),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amberAccent)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber, width: 2)),
                  ),
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white),
                  items: [
                    const DropdownMenuItem(value: null, child: Text("Вручную", style: TextStyle(color: Colors.white54))),
                    ...festivalMasterData.map((e) => DropdownMenuItem(
                      value: e,
                      child: SizedBox(
                        width: 200,
                        child: Text("${e['masterName']} - ${e['gameTitle']}", overflow: TextOverflow.ellipsis),
                      ),
                    ))
                  ],
                  onChanged: _onExcelMasterSelected,
                ),
              ),

              // 1. Activity Selector
              if (_activities.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: DropdownButtonFormField<String>(
                      value: _activities.any((a) => a['id'] == _selectedActivityId) ? _selectedActivityId : null,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: "Выбрать из каталога (Старый)",
                        labelStyle: TextStyle(color: Colors.white54),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber, width: 2)),
                      ),
                      items: [
                         const DropdownMenuItem<String>(value: null, child: Text("Вручную / Без шаблона", style: TextStyle(color: Colors.white54))),
                         ..._activities.map((a) {
                            // Truncate title if too long
                            String title = a['title'] ?? 'No Title';
                            if (title.length > 30) title = "${title.substring(0, 30)}...";
                            return DropdownMenuItem<String>(
                              value: a['id'],
                              child: Text(title),
                            );
                         }),
                      ],
                      onChanged: _onActivitySelected,
                    ),
                  ),

              _buildTextField(_titleController, "Название игры"),
              _buildTextField(_descController, "Описание", maxLines: 3),
              
              // 2. Master Selection (Admin/User list)
              if (_loadingMasters)
                 const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator())
              else if (_masters.isNotEmpty) ...[
                 Padding(
                   padding: const EdgeInsets.only(bottom: 12),
                   child: DropdownButtonFormField<String>(
                      value: _masters.any((m) => m['uid'] == _selectedMasterUid) ? _selectedMasterUid : null,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                         labelText: "Мастер (основной)",
                         labelStyle: TextStyle(color: Colors.white54),
                         enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                         helperText: "Выберите зарегистрированного мастера (для доступа)",
                         helperStyle: TextStyle(color: Colors.white30),
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
                               // Only overwrite name if not set by activity or user
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

              _buildTextField(_masterNameController, "Имя мастера (отображаемое)"),
              
              if (_activityMasterTickets.isNotEmpty)
                  Padding(
                     padding: const EdgeInsets.only(bottom: 12),
                     child: Text("Привязанные билеты: ${_activityMasterTickets.join(", ")}", style: const TextStyle(color: Colors.greenAccent, fontSize: 12)),
                  ),

              _buildTextField(_locationController, "Локация (стол/зал)"),
                  Expanded(child: _buildTextField(_maxPlayersController, "Мест", isNumber: true)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTextField(_durationController, "Мин.", isNumber: true)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTextField(_ageLimitController, "Возраст", isNumber: true)),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _selectedSlotId,
                dropdownColor: const Color(0xFF1E293B),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Слот времени",
                  labelStyle: TextStyle(color: Colors.white54),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                ),
                items: const [
                  DropdownMenuItem(value: 1, child: Text("Слот 1 (12:45 - 14:15)")),
                  DropdownMenuItem(value: 2, child: Text("Слот 2 (14:45 - 16:15)")),
                  DropdownMenuItem(value: 3, child: Text("Слот 3 (16:30 - 18:00)")),
                ],
                onChanged: (val) {
                   setState(() {
                      _selectedSlotId = val;
                      // Auto-set time
                      if (val == 1) _selectedDate = DateTime(2026, 2, 21, 12, 45);
                      if (val == 2) _selectedDate = DateTime(2026, 2, 21, 14, 45);
                      if (val == 3) _selectedDate = DateTime(2026, 2, 21, 16, 30);
                   });
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("Время начала:", style: TextStyle(color: Colors.white70)),
                trailing: TextButton(
                  onPressed: _pickDateTime,
                  child: Text(DateFormat('dd.MM HH:mm').format(_selectedDate), style: const TextStyle(color: Colors.amberAccent, fontSize: 16)),
                ),
              )
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Отмена")),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveGame, 
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
          child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("Сохранить"),
        )
      ],
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {bool isNumber = false, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        maxLines: maxLines,
        validator: (value) => value == null || value.isEmpty ? "Обязательно" : null,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54),
          enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
        ),
      ),
    );
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2025),
      lastDate: DateTime(2027),
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDate),
    );
    if (time == null) return;

    setState(() {
      _selectedDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _saveGame() async {
    if (!_formKey.currentState!.validate()) {
       debugPrint("Form validation failed");
       return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("No user");

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
        ageLimit: int.tryParse(_ageLimitController.text),
      );

      // Add timeout to prevent hanging on Web Iframe
      await Future.any([
        widget.game == null 
            ? FirestoreService().createFestivalGame(game) 
            : FirestoreService().updateFestivalGame(game),
        Future.delayed(const Duration(seconds: 10), () => throw Exception("Timeout saving game. Check connection.")),
      ]);
      
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("Save Game Error: $e");
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Ошибка: $e"),
            backgroundColor: Colors.red,
         ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
