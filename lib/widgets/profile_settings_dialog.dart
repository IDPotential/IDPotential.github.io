import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';

class ProfileSettingsDialog extends StatefulWidget {
  const ProfileSettingsDialog({super.key});

  @override
  State<ProfileSettingsDialog> createState() => _ProfileSettingsDialogState();
}

class _ProfileSettingsDialogState extends State<ProfileSettingsDialog> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _telegramTokenController = TextEditingController(); // Or maybe just "Paste Token Here"

  bool _isLoading = false;
  User? _user;
  Map<String, dynamic>? _userData;
  
  // Linking State
  bool _isLinkingEmail = false;
  bool _isLinkingTelegram = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
       final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
       if (mounted) {
          setState(() {
             _user = user;
             _userData = doc.data();
          });
       }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) return const Center(child: CircularProgressIndicator());

    final email = _userData?['email'];
    final telegramId = _userData?['telegram_id'];
    final ticketLogin = _userData?['ticketLogin'];

    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text("Настройки профиля", style: TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: Container(
           width: double.maxFinite,
           constraints: const BoxConstraints(maxWidth: 400),
           child: Column(
             mainAxisSize: MainAxisSize.min,
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
                // User Info
                _buildInfoRow(Icons.person, "Имя", _userData?['first_name'] ?? 'Guest'),
                if (ticketLogin != null)
                   _buildInfoRow(Icons.confirmation_number, "Билет", ticketLogin),
                
                const Divider(color: Colors.white24, height: 30),
                
                // Email Linking
                if (email != null)
                   _buildLinkedRow(Icons.email, "Email", email)
                else
                   _buildLinkEmailSection(),

                const SizedBox(height: 20),

                // Telegram Linking
                if (telegramId != null)
                   _buildLinkedRow(Icons.telegram, "Telegram", "ID: $telegramId")
                else
                   _buildLinkTelegramSection(),
             ],
           ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Закрыть")),
        TextButton(
           onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) Navigator.pop(context); // Close dialog, allow app to redirect to login
           }, 
           child: const Text("Выйти", style: TextStyle(color: Colors.redAccent))
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: Colors.white54, size: 20),
          const SizedBox(width: 12),
          Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
                Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 16)),
             ],
          )
        ],
      ),
    );
  }

  Widget _buildLinkedRow(IconData icon, String label, String value) {
     return Row(
        children: [
           Icon(icon, color: Colors.greenAccent, size: 20),
           const SizedBox(width: 12),
           Expanded(
              child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                    Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                    Text(value, style: const TextStyle(color: Colors.greenAccent, fontSize: 14)),
                 ],
              ),
           ),
           const Icon(Icons.check_circle, color: Colors.greenAccent, size: 16),
        ],
     );
  }

  Widget _buildLinkEmailSection() {
     if (_isLinkingEmail) {
        return Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
              const Text("Привязка Email", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                 controller: _emailController,
                 style: const TextStyle(color: Colors.white),
                 decoration: const InputDecoration(labelText: "Email", labelStyle: TextStyle(color: Colors.white54)),
              ),
              TextField(
                 controller: _passwordController,
                 style: const TextStyle(color: Colors.white),
                 obscureText: true,
                 decoration: const InputDecoration(labelText: "Пароль", labelStyle: TextStyle(color: Colors.white54)),
              ),
              const SizedBox(height: 12),
              Row(
                 mainAxisAlignment: MainAxisAlignment.end,
                 children: [
                    TextButton(onPressed: () => setState(() => _isLinkingEmail = false), child: const Text("Отмена")),
                    ElevatedButton(
                       onPressed: _isLoading ? null : _linkEmail,
                       style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                       child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text("Привязать"),
                    )
                 ],
              )
           ],
        );
     }

     return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
           icon: const Icon(Icons.email),
           label: const Text("Привязать Email"),
           onPressed: () => setState(() => _isLinkingEmail = true),
           style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white24)),
        ),
     );
  }

  Widget _buildLinkTelegramSection() {
     if (_isLinkingTelegram) {
        return Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
              const Text("Привязка Telegram", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text("Введите токен, полученный от бота /start_link", style: TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 8),
              TextField(
                 controller: _telegramTokenController,
                 style: const TextStyle(color: Colors.white),
                 decoration: const InputDecoration(labelText: "Токен", labelStyle: TextStyle(color: Colors.white54)),
              ),
              const SizedBox(height: 12),
              Row(
                 mainAxisAlignment: MainAxisAlignment.end,
                 children: [
                    TextButton(onPressed: () => setState(() => _isLinkingTelegram = false), child: const Text("Отмена")),
                    ElevatedButton(
                       onPressed: _isLoading ? null : _linkTelegram,
                       style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                       child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text("Привязать"),
                    )
                 ],
              )
           ],
        );
     }

     return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
           icon: const Icon(Icons.telegram),
           label: const Text("Привязать Telegram"),
           onPressed: () => setState(() => _isLinkingTelegram = true),
           style: OutlinedButton.styleFrom(foregroundColor: Colors.blueAccent, side: const BorderSide(color: Colors.blueAccent)),
        ),
     );
  }

  Future<void> _linkEmail() async {
     setState(() => _isLoading = true);
     try {
        await AuthService().linkEmailAndPassword(_emailController.text.trim(), _passwordController.text.trim());
        if (!mounted) return;
        
        await _loadUser();
        setState(() {
           _isLinkingEmail = false;
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Email успешно привязан!")));
     } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ошибка: $e")));
     } finally {
        if (mounted) setState(() => _isLoading = false);
     }
  }

  Future<void> _linkTelegram() async {
     setState(() => _isLoading = true);
     try {
        await AuthService().linkTelegramAccount(_telegramTokenController.text.trim());
        if (!mounted) return;

        await _loadUser();
        setState(() {
           _isLinkingTelegram = false;
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Telegram успешно привязан!")));
     } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ошибка: $e")));
     } finally {
        if (mounted) setState(() => _isLoading = false);
     }
  }
}
