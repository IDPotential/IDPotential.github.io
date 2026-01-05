import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../app.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  
  bool _isLoading = false;
  bool _isRegistering = false; // Toggle between Login and Register
  String? _errorMessage;

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    
    if (email.isEmpty || password.isEmpty) {
        setState(() => _errorMessage = "Введите email и пароль");
        return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isRegistering) {
         await _authService.createUserWithEmailAndPassword(email, password);
         _showSuccess("Регистрация успешна!");
      } else {
         await _authService.signInWithEmailAndPassword(email, password);
         _showSuccess("Вход выполнен!");
      }
      
      // Navigate
      if (mounted) {
         Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const AppHome()),
         );
      }

    } catch (e) {
      _handleError(e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccess(String msg) {
     if (!mounted) return;
     ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.green),
     );
  }

  void _handleError(Object e) {
      String msg = "Ошибка авторизации";
      if (e is FirebaseAuthException) {
         switch (e.code) {
            case 'user-not-found': msg = "Пользователь не найден"; break;
            case 'wrong-password': msg = "Неверный пароль"; break;
            case 'email-already-in-use': msg = "Email уже используется"; break;
            case 'invalid-email': msg = "Некорректный email"; break;
            case 'weak-password': msg = "Пароль слишком простой (мин. 6 символов)"; break;
            default: msg = "Ошибка: ${e.message}";
         }
      } else {
         msg = "$e";
      }
      setState(() => _errorMessage = msg);
  }

  Future<void> _resetPassword() async {
     final email = _emailController.text.trim();
     if (email.isEmpty) {
        setState(() => _errorMessage = "Введите email для сброса пароля");
        return;
     }
     try {
        await _authService.sendPasswordResetEmail(email);
        _showSuccess("Письмо для сброса отправлено на $email");
     } catch (e) {
        _handleError(e);
     }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
         decoration: const BoxDecoration(
            gradient: LinearGradient(
               begin: Alignment.topCenter, end: Alignment.bottomCenter,
               colors: [Color(0xFF0F172A), Color(0xFF1E293B)]
            )
         ),
         child: Center(
           child: SingleChildScrollView(
             padding: const EdgeInsets.all(24.0),
             child: ConstrainedBox(
               constraints: const BoxConstraints(maxWidth: 400),
               child: Card(
                 color: const Color(0xFF1E293B).withOpacity(0.9),
                 elevation: 8,
                 shape: RoundedRectangleBorder(
                   borderRadius: BorderRadius.circular(16),
                   side: BorderSide(color: Colors.white.withOpacity(0.1)),
                 ),
                 child: Padding(
                   padding: const EdgeInsets.all(32.0),
                   child: Column(
                     mainAxisSize: MainAxisSize.min,
                     children: [
                       const Icon(Icons.security, size: 64, color: Colors.blueAccent),
                       const SizedBox(height: 24),
                       Text(
                         _isRegistering ? "Регистрация" : "Вход",
                         style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                       ),
                       const SizedBox(height: 24),
                       
                       TextField(
                         controller: _emailController,
                         style: const TextStyle(color: Colors.white),
                         decoration: InputDecoration(
                           labelText: "Email",
                           labelStyle: const TextStyle(color: Colors.white70),
                           enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.3))),
                           focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
                           prefixIcon: const Icon(Icons.email, color: Colors.white70),
                         ),
                       ),
                       const SizedBox(height: 16),
                       TextField(
                         controller: _passwordController,
                         style: const TextStyle(color: Colors.white),
                         obscureText: true,
                         decoration: InputDecoration(
                           labelText: "Пароль",
                           labelStyle: const TextStyle(color: Colors.white70),
                           enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.3))),
                           focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
                           prefixIcon: const Icon(Icons.lock, color: Colors.white70),
                         ),
                       ),
                       
                       if (_errorMessage != null) ...[
                         const SizedBox(height: 16),
                         Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 13), textAlign: TextAlign.center),
                       ],
                       
                       const SizedBox(height: 24),
                       SizedBox(
                         width: double.infinity,
                         height: 48,
                         child: ElevatedButton(
                           onPressed: _isLoading ? null : _submit,
                           style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                           child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : Text(_isRegistering ? "Зарегистрироваться" : "Войти", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                         ),
                       ),
                       
                       const SizedBox(height: 16),
                       TextButton(
                          onPressed: () => setState(() {
                             _isRegistering = !_isRegistering;
                             _errorMessage = null;
                          }),
                          child: Text(_isRegistering ? "Уже есть аккаунт? Войти" : "Нет аккаунта? Регистрация", style: const TextStyle(color: Colors.white70)),
                       ),
                       
                       if (!_isRegistering)
                          TextButton(
                             onPressed: _resetPassword,
                             child: const Text("Забыли пароль?", style: TextStyle(color: Colors.white38, fontSize: 12)),
                          )
                     ],
                   ),
                 ),
               ),
             ),
           ),
         ),
      ),
    );
  }
}
