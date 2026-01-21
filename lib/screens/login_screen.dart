import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
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
  bool _isRegistering = false; 
  bool _isTokenLogin = false; 
  String? _errorMessage;
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
       setState(() {
          _appVersion = "${info.version} (${info.buildNumber})";
       });
    }
  }

  Future<void> _loginToken() async {
     final token = _passwordController.text.trim(); // We reuse password field for token input
     if (token.isEmpty) {
        setState(() => _errorMessage = "Введите токен");
        return;
     }
     
     setState(() { _isLoading = true; _errorMessage = null; });
     
     try {
        await _authService.signInWithCustomToken(token);
        _showSuccess("Вход выполнен!");
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

  Future<void> _loginGoogle() async {
     setState(() {
        _isLoading = true;
        _errorMessage = null;
     });
     
     try {
        await _authService.signInWithGoogle();
        _showSuccess("Вход через Google выполнен!");
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
     String email = _emailController.text.trim();
     
     // Show dialog to confirm or enter email
     final result = await showDialog<String>(
        context: context,
        builder: (ctx) {
           final ctrl = TextEditingController(text: email);
           return AlertDialog(
              title: const Text("Сброс пароля"),
              content: Column(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                    const Text("Введите ваш email, и мы отправим вам ссылку для сброса пароля."),
                    const SizedBox(height: 16),
                    TextField(
                       controller: ctrl,
                       keyboardType: TextInputType.emailAddress,
                       decoration: const InputDecoration(labelText: "Email", border: OutlineInputBorder()),
                    )
                 ],
              ),
              actions: [
                 TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Отмена")),
                 ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                    child: const Text("Отправить")
                 )
              ],
           );
        }
     );

     if (result != null && result.isNotEmpty) {
        try {
           await _authService.sendPasswordResetEmail(result);
           _showSuccess("Письмо для сброса отправлено на $result");
        } catch (e) {
           _handleError(e);
        }
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
                         _isTokenLogin ? "Вход по токену" : (_isRegistering ? "Регистрация" : "Вход"),
                         style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                       ),
                       const SizedBox(height: 24),
                       
                       // Toggle Auth Mode (Email vs Token)
                       if (!_isRegistering && !_isTokenLogin)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 20.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ElevatedButton(
                                  onPressed: () {},
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                                  child: const Text("Email"),
                                ),
                                const SizedBox(width: 10),
                                OutlinedButton(
                                  onPressed: () => setState(() => _isTokenLogin = true),
                                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white54)),
                                  child: const Text("Telegram токен", style: TextStyle(color: Colors.white70)),
                                ),
                              ],
                            ),
                          ),
                          
                       if (_isTokenLogin)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 20.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                OutlinedButton(
                                  onPressed: () => setState(() => _isTokenLogin = false),
                                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white54)),
                                  child: const Text("Email", style: TextStyle(color: Colors.white70)),
                                ),
                                const SizedBox(width: 10),
                                ElevatedButton(
                                  onPressed: () {},
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                                  child: const Text("Telegram токен"),
                                ),
                              ],
                            ),
                          ),

                       if (_isTokenLogin) ...[
                          const Text(
                            "Введите токен из Telegram бота:\n/login_app",
                             textAlign: TextAlign.center,
                             style: TextStyle(color: Colors.white54, fontSize: 13)
                          ),
                          const SizedBox(height: 10),
                          TextField(
                             controller: _passwordController, // Reuse controller for token
                             style: const TextStyle(color: Colors.white),
                             decoration: InputDecoration(
                               labelText: "Токен (Token)",
                               labelStyle: const TextStyle(color: Colors.white70),
                               enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.3))),
                               focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
                               prefixIcon: const Icon(Icons.vpn_key, color: Colors.white70),
                             ),
                             maxLines: 3,
                          ),
                       ] else ...[
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
                       ],
                       
                       if (_errorMessage != null) ...[
                         const SizedBox(height: 16),
                         Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 13), textAlign: TextAlign.center),
                       ],
                       
                       const SizedBox(height: 24),
                       SizedBox(
                         width: double.infinity,
                         height: 48,
                         child: ElevatedButton(
                           onPressed: _isLoading ? null : (_isTokenLogin ? _loginToken : _submit),
                           style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                           child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : Text(
                              _isTokenLogin ? "Войти по токену" : (_isRegistering ? "Зарегистрироваться" : "Войти"), 
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)
                           ),
                         ),
                       ),

                       if (!_isRegistering && !_isTokenLogin) ...[
                          const SizedBox(height: 20),
                          // Google Button placeholder (Hidden)
                       ],
                       
                       const SizedBox(height: 16),
                       if (!_isTokenLogin)
                          TextButton(
                             onPressed: () => setState(() {
                                _isRegistering = !_isRegistering;
                                _errorMessage = null;
                             }),
                             child: Text(_isRegistering ? "Уже есть аккаунт? Войти" : "Нет аккаунта? Регистрация", style: const TextStyle(color: Colors.white70)),
                          ),
                       
                       if (!_isRegistering && !_isTokenLogin)
                          TextButton(
                             onPressed: _resetPassword,
                             child: const Text("Забыли пароль?", style: TextStyle(color: Colors.white70, fontSize: 14)),
                          ),
                       const SizedBox(height: 20),
                       Text("v$_appVersion", style: const TextStyle(color: Colors.white24, fontSize: 10)),
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
