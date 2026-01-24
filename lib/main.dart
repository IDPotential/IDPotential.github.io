import 'dart:async'; // Imported for runZonedGuarded
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/festival_screen.dart'; // Import
import 'app.dart';
import 'screens/login_screen.dart';
import 'services/database_service.dart';
import 'services/auth_service.dart';
import 'services/config_service.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:app_links/app_links.dart';

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

// ... imports ...


// ... (in _MyAppState)

class _MyAppState extends State<MyApp> {
  // Initialization Future
  late Future<void> _initFuture;
  final ValueNotifier<String> _loadingStatus = ValueNotifier("Подключение к Firebase...");
  
  // Custom Navigation Key to handle deep links
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initFuture = _initApp();
    _initDeepLinks();
  }
  
  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initDeepLinks() async {
    // Handle initial link
    Uri? initialUri;
    try {
      initialUri = await _appLinks.getInitialLink();
      // Note: MaterialApp handles the initial route automatically via 'routes'.
      // We only need to listen to the stream for subsequent links,
      // but the stream often emits the initial link too.
    } catch (e) {
      debugPrint("Deep Link Init Error: $e");
    }

    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
       // Check if this is the generic initial link event to avoid double-push
       if (initialUri != null && uri.path == initialUri!.path) {
          debugPrint("Skipping initial link handled by framework: $uri");
          initialUri = null; // Consume it so future clicks work
          return;
       }
       _handleDeepLink(uri);
    }, onError: (err) {
       debugPrint("Deep Link Error: $err");
    });
  }

  void _handleDeepLink(Uri uri) {
    debugPrint("Deep link received: $uri");
    final path = uri.path;
    
    // 1. Festival -> Open directly (Guest allowed)
    if (path.contains('festival')) {
       _navigatorKey.currentState?.pushNamed('/festival');
       return;
    }
    
    // 2. Games List -> AppHome(3)
    // Supports both /game and /games
    if (path.contains('game')) {
       final user = FirebaseAuth.instance.currentUser;
       if (user != null) {
          // Logged in -> Go to Games Tab
          // We use pushNamedAndRemoveUntil to reset stack but keep bottom nav logic if possible
          // But since AppHome handles tabs, pushing '/games' works as a new route or replacement.
          // Better: pushRepalcement or pushNamedAndRemoveUntil
          _navigatorKey.currentState?.pushNamedAndRemoveUntil('/games', (route) => false);
       } else {
          // Not logged in -> Go to Login
          debugPrint("User not logged in, redirecting to login for game");
          _navigatorKey.currentState?.pushNamedAndRemoveUntil('/', (route) => false);
           // Ideally we should pass 'redirect: /games' to login screen to handle post-login nav
       }
    }
  }

  Future<void> _initApp() async {
    try {
      // 1. Firebase
      _loadingStatus.value = "Подключение к Firebase...";
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      // Set localization for Auth (Emails, SMS)
      FirebaseAuth.instance.setLanguageCode('ru');
      
      // 2. Config
      _loadingStatus.value = "Загрузка конфигурации...";
      await ConfigService().initialize();

      // 3. Database
      _loadingStatus.value = "Открытие базы данных...";
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
      navigatorKey: _navigatorKey, // CRITICAL: Assign key
      // ... (Theme config remains same)
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
        // ... (Theme content, truncated for replacement) ...
        fontFamily: 'DINPro',
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF3B82F6),
          secondary: Color(0xFF0EA5E9),
          background: Color(0xFF0F172A),
          surface: Color(0xFF1E293B),
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onBackground: Colors.white,
          onSurface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E293B),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF1E293B),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            side: BorderSide(color: Colors.white12),
          ),
        ),
        textTheme: const TextTheme(
           bodyLarge: TextStyle(color: Colors.white),
           // ... 
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3B82F6),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
         inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1E293B),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2)),
          labelStyle: const TextStyle(color: Colors.white70),
          prefixIconColor: Colors.white70,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF0F172A),
          selectedItemColor: Color(0xFF3B82F6),
          unselectedItemColor: Colors.white54,
          elevation: 0,
        ),
      ),
      routes: {
        '/festival': (context) => const FestivalScreen(),
        '/games': (context) => const AppHome(initialIndex: 3),
      },
      home: FutureBuilder(
        future: _initFuture,
        builder: (context, snapshot) {
          // 1. Error State
          if (snapshot.hasError) {
             return Scaffold(body: Center(child: Text("Ошибка: ${snapshot.error}", style: const TextStyle(color: Colors.red)))); 
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
                  Image.asset('assets/images/logo.png', width: 100, height: 100, errorBuilder: (_,__,___) => const SizedBox()),
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(color: Color(0xFF3B82F6)),
                  const SizedBox(height: 16),
                  
                  ValueListenableBuilder<String>(
                    valueListenable: _loadingStatus,
                    builder: (context, status, _) {
                      return Text(status, style: const TextStyle(color: Colors.white54));
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
