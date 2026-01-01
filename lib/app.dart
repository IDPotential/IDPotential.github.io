import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/calculation_screen.dart';
import 'screens/history_screen.dart';
import 'screens/library_screen.dart';

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
  ];
  
  final List<String> _titles = [
    'Диагностика',
    'История',
    'Библиотека',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _selectedIndex == 0 
      ? AppBar(
        title: Text(_titles[_selectedIndex]),
        actions: _selectedIndex == 0 
            ? [
                IconButton(
                  icon: const Icon(Icons.calculate),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CalculationScreen(),
                      ),
                    );
                  },
                )
              ]
            : null,
      ) : null, // Hide AppBar for other tabs
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
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
        ],
      ),
    );
  }
}