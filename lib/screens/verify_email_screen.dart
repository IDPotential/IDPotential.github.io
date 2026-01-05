import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import '../app.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool isEmailVerified = false;
  bool canResendEmail = false;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    
    // Check status immediately
    isEmailVerified = FirebaseAuth.instance.currentUser?.emailVerified ?? false;

    if (!isEmailVerified) {
      // Send link automatically if not sent recently (Firebase handles throttling, but good to trigger once)
      _sendVerificationEmail();
      
      // Periodically check if verified
      timer = Timer.periodic(
        const Duration(seconds: 3),
        (_) => checkEmailVerified(),
      );
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> checkEmailVerified() async {
    // Reload user to get fresh data
    await FirebaseAuth.instance.currentUser?.reload();
    
    setState(() {
      isEmailVerified = FirebaseAuth.instance.currentUser?.emailVerified ?? false;
    });

    if (isEmailVerified) {
      timer?.cancel();
      // Navigate to Home
      if (mounted) {
         Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const AppHome()),
         );
      }
    }
  }

  Future<void> _sendVerificationEmail() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      await user?.sendEmailVerification();
      
      setState(() => canResendEmail = false);
      await Future.delayed(const Duration(seconds: 5));
      if (mounted) setState(() => canResendEmail = true);
      
    } catch (e) {
      debugPrint("Error sending verification: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isEmailVerified) {
       return const AppHome(); 
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Подтверждение почты")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.mark_email_unread, size: 80, color: Colors.blueAccent),
            const SizedBox(height: 24),
            const Text(
              "Письмо с подтверждением отправлено!",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              "Мы отправили письмо на ${FirebaseAuth.instance.currentUser?.email}.\nПожалуйста, перейдите по ссылке в письме, чтобы подтвердить аккаунт.",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: canResendEmail ? _sendVerificationEmail : null,
              icon: const Icon(Icons.email),
              label: const Text("Отправить повторно"),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () async {
                 await AuthService().signOut();
                 if (mounted) {
                    Navigator.of(context).pushReplacement(
                       MaterialPageRoute(builder: (context) => const LoginScreen())
                    );
                 }
              },
              child: const Text("Отмена (Выйти)"),
            )
          ],
        ),
      ),
    );
  }
}
