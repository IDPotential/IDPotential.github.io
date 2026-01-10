import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/calculation_screen.dart';
import 'screens/history_screen.dart';
import 'screens/library_screen.dart';
import 'screens/game_screen.dart';

class AppHome extends StatefulWidget {
  const AppHome({super.key});

  @override
  State<AppHome> createState() => _AppHomeState();
}

class _AppHomeState extends State<AppHome> {
  int _selectedIndex = 0;
  
  final List<Widget> _screens = [
    const HomeScreen(),
    const HistoryScreen(),
    const LibraryScreen(),
    const GameScreen(),
  ];
  
  final List<String> _titles = [
    'Диагностика',
    'История',
    'Библиотека',
    'Территория себя',
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isLandscape = constraints.maxWidth > constraints.maxHeight;

        if (isLandscape) {
          return Scaffold(
             appBar: null,
             body: SafeArea(
               child: Row(
                 children: [
                   // Main Content
                   Expanded(
                     child: _screens[_selectedIndex],
                   ),
                   // Vertical Divider
                   const VerticalDivider(width: 1, thickness: 1, color: Colors.white12),
                   // Navigation Rail (Right Side)
                   NavigationRail(
                     selectedIndex: _selectedIndex,
                     onDestinationSelected: (index) {
                       setState(() {
                         _selectedIndex = index;
                       });
                     },
                     labelType: NavigationRailLabelType.all,
                     backgroundColor: const Color(0xFF0F172A),
                     selectedIconTheme: const IconThemeData(color: Color(0xFF3B82F6)),
                     unselectedIconTheme: const IconThemeData(color: Colors.white54),
                     selectedLabelTextStyle: const TextStyle(color: Color(0xFF3B82F6)),
                     unselectedLabelTextStyle: const TextStyle(color: Colors.white54),
                     destinations: const [
                       NavigationRailDestination(
                         icon: Icon(Icons.home),
                         label: Text('Главная'),
                       ),
                       NavigationRailDestination(
                         icon: Icon(Icons.history),
                         label: Text('История'),
                       ),
                       NavigationRailDestination(
                         icon: Icon(Icons.menu_book),
                         label: Text('Библиотека'),
                       ),
                       NavigationRailDestination(
                         icon: Icon(Icons.casino),
                         label: Text('Игра'),
                       ),
                     ],
                   ),
                 ],
               ),
             ),
          );
        } else {
          return Scaffold(
            appBar: null,
            body: _screens[_selectedIndex],
            bottomNavigationBar: SafeArea(
              child: BottomNavigationBar(
                currentIndex: _selectedIndex,
                onTap: (index) {
                  setState(() {
                    _selectedIndex = index;
                  });
                },
                type: BottomNavigationBarType.fixed,
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.home),
                    label: 'Главная',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.history),
                    label: 'История',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.menu_book),
                    label: 'Библиотека',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.casino),
                    label: 'Игра',
                  ),
                ],
              ),
            ),
          );
        }
      },
    );
  }
}