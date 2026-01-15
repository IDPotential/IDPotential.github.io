import 'dart:async'; // Imported for runZonedGuarded
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'app.dart';
import 'screens/login_screen.dart';
import 'services/database_service.dart';
import 'services/auth_service.dart';
import 'services/config_service.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    runApp(const MyApp());
  }, (error, stack) {
    debugPrint("Uncaught Error: $error");
    debugPrint("Stack Trace: $stack");
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Initialization Future
  late Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = _initApp();
  }

  Future<void> _initApp() async {
    try {
      // 1. Firebase
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      
      // 2. Config & DB
      // We run them in parallel or sequence. Sequence is safer for dependencies.
      await ConfigService().initialize();
      await DatabaseService().init();
      
    } catch (e, stack) {
      debugPrint("Initialization Failed: $e");
      debugPrint(stack.toString());
      // Re-throw to show error screen if crucial
      rethrow; 
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Индивидуальная Диагностика Потенциала',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ru', 'RU'), // Russian
      ],
      theme: ThemeData(
        fontFamily: 'DINPro',
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A), // Slate 900
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF3B82F6), // Blue 500
          secondary: Color(0xFF0EA5E9), // Sky 500
          background: Color(0xFF0F172A),
          surface: Color(0xFF1E293B), // Slate 800
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onBackground: Colors.white,
          onSurface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E293B), // Slate 800
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF1E293B), // Slate 800
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            side: BorderSide(color: Colors.white12),
          ),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white70),
          titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          titleMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3B82F6),
            foregroundColor: Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFF334155), // Slate 700
          labelStyle: const TextStyle(color: Colors.white),
          side: BorderSide.none,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1E293B), // Slate 800
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
          ),
          labelStyle: const TextStyle(color: Colors.white70),
          prefixIconColor: Colors.white70,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF0F172A), // Slate 900
          selectedItemColor: Color(0xFF3B82F6), // Blue 500
          unselectedItemColor: Colors.white54,
          elevation: 0,
        ),
      ),
      home: FutureBuilder(
        future: _initFuture,
        builder: (context, snapshot) {
          // 1. Error State
          if (snapshot.hasError) {
             return Scaffold(
               body: Center(
                 child: Padding(
                   padding: const EdgeInsets.all(24.0),
                   child: Column(
                     mainAxisSize: MainAxisSize.min,
                     children: [
                       const Icon(Icons.error_outline, color: Colors.red, size: 48),
                       const SizedBox(height: 16),
                       const Text(
                         "Ошибка инициализации", 
                         style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)
                       ),
                       const SizedBox(height: 8),
                       Text(
                         snapshot.error.toString(), 
                         textAlign: TextAlign.center,
                         style: const TextStyle(color: Colors.white54)
                       ),
                       const SizedBox(height: 24),
                       ElevatedButton(
                         onPressed: () {
                           setState(() {
                             _initFuture = _initApp(); // Retry
                           });
                         },
                         child: const Text("Повторить"),
                       )
                     ],
                   ),
                 ),
               )
             );
          }

          // 2. Done State -> App Content
          if (snapshot.connectionState == ConnectionState.done) {
             return StreamBuilder<User?>(
                stream: FirebaseAuth.instance.authStateChanges(),
                builder: (context, authSnap) {
                  if (authSnap.connectionState == ConnectionState.waiting) {
                     return const Scaffold(body: Center(child: CircularProgressIndicator()));
                  }
                  if (authSnap.hasData) {
                    return const AppHome();
                  }
                  return const LoginScreen();
                },
             );
          }

          // 3. Loading State (Splash)
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo if available, else just text
                  Image.asset('assets/images/logo.png', width: 100, height: 100, errorBuilder: (_,__,___) => const SizedBox()),
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(color: Color(0xFF3B82F6)),
                  const SizedBox(height: 16),
                  const Text("Загрузка...", style: TextStyle(color: Colors.white54))
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
