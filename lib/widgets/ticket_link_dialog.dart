import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';

class TicketLinkDialog extends StatefulWidget {
  const TicketLinkDialog({super.key});

  @override
  State<TicketLinkDialog> createState() => _TicketLinkDialogState();
}

class _TicketLinkDialogState extends State<TicketLinkDialog> {
  final _emailController = TextEditingController();
  final _loginController = TextEditingController();
  bool _isLoading = false;
  String? _statusMessage;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: const Text("Привязка билета", style: TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Введите Email пользователя и Логин с билета (например, m00001), чтобы связать их.",
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "Email пользователя",
                labelStyle: TextStyle(color: Colors.white54),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _loginController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "Логин билета (mXXXXX)",
                labelStyle: TextStyle(color: Colors.white54),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              ),
            ),
            if (_statusMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_statusMessage!, style: TextStyle(color: _statusMessage!.startsWith("Ошибка") ? Colors.redAccent : Colors.greenAccent)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Закрыть")),
        ElevatedButton(
          onPressed: _isLoading ? null : _linkTicket,
          child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("Привязать"),
        ),
      ],
    );
  }

  Future<void> _linkTicket() async {
    final email = _emailController.text.trim();
    final ticketLogin = _loginController.text.trim();

    if (email.isEmpty || ticketLogin.isEmpty) {
      setState(() => _statusMessage = "Ошибка: Заполните все поля");
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    try {
      final db = FirebaseFirestore.instance;
      
      // 1. Find User by Email
      final userQuery = await db.collection('users').where('email', '==', email).limit(1).get();
      if (userQuery.docs.isEmpty) {
        throw Exception("Пользователь с email $email не найден");
      }
      final userDoc = userQuery.docs.first;
      
      // 2. Check if Ticket exists
      final ticketDoc = await db.collection('festival_tickets').doc(ticketLogin).get();
      if (!ticketDoc.exists) {
         throw Exception("Билет $ticketLogin не найден");
      }

      // 3. Link
      final batch = db.batch();
      
      // Update User
      batch.update(userDoc.reference, {
        'ticketLogin': ticketLogin,
        'isTicketUser': true, // Mark as having a ticket
      });
      
      // Update Ticket
      batch.update(ticketDoc.reference, {
        'assignedToUserId': userDoc.id,
        'assignedToEmail': email,
        'isAssigned': true,
        'assignedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      setState(() {
        _statusMessage = "Успешно! Билет $ticketLogin привязан к $email";
        _emailController.clear();
        _loginController.clear();
      });

    } catch (e) {
      setState(() => _statusMessage = "Ошибка: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
