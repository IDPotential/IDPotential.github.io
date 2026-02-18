import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/festival_game.dart';
import '../services/firestore_service.dart';
import 'package:intl/intl.dart';

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
  int? _selectedSlotId; // 1, 2, or 3

  DateTime _selectedDate = DateTime(2026, 2, 21, 12, 0); // Festival default date
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.game != null) {
      _titleController.text = widget.game!.title;
      _descController.text = widget.game!.description;
      _masterNameController.text = widget.game!.masterName;
      _locationController.text = widget.game!.location;
      _maxPlayersController.text = widget.game!.maxParticipants.toString();
      _durationController.text = widget.game!.durationMinutes.toString();
      _selectedDate = widget.game!.startTime;
      _selectedSlotId = widget.game!.slotId;
    } else {
       _prefillMasterName();
    }
  }

  void _prefillMasterName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
       final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
       final name = doc.data()?['first_name'];
       final role = doc.data()?['role'];
       if (name != null && role == 'master') {
          setState(() {
             _masterNameController.text = name;
          });
       }
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
              _buildTextField(_titleController, "Название игры"),
              _buildTextField(_descController, "Описание", maxLines: 3),
              _buildTextField(_masterNameController, "Имя мастера"),
              _buildTextField(_locationController, "Локация (стол/зал)"),
              Row(
                children: [
                  Expanded(child: _buildTextField(_maxPlayersController, "Мест", isNumber: true)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTextField(_durationController, "Мин.", isNumber: true)),
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
                onChanged: (val) => setState(() => _selectedSlotId = val),
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
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("No user");

      final game = FestivalGame(
        id: widget.game?.id ?? '',
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        masterId: widget.game?.masterId ?? user.uid, // TODO: Admin selection logic of masterId? For now assume creator is master or keeps existing
        masterName: _masterNameController.text.trim(),
        startTime: _selectedDate,
        durationMinutes: int.parse(_durationController.text),
        location: _locationController.text.trim(),
        maxParticipants: int.parse(_maxPlayersController.text),
        participants: widget.game?.participants ?? [],
        slotId: _selectedSlotId,
      );

      if (widget.game == null) {
          await FirestoreService().createFestivalGame(game);
      } else {
          await FirestoreService().updateFestivalGame(game);
      }
      
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ошибка: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
