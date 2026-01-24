import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/calculation_screen.dart';
import 'screens/history_screen.dart';
import 'screens/library_screen.dart';
import 'screens/game_screen.dart';

class AppHome extends StatefulWidget {
  final int initialIndex;
  const AppHome({super.key, this.initialIndex = 0});

  @override
  State<AppHome> createState() => _AppHomeState();
}

class _AppHomeState extends State<AppHome> {
  int _selectedIndex = 0;
  late PageController _pageController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  // Screens will be initialized in initState or getter to access _scaffoldKey
  late List<Widget> _screens;
  
  final List<String> _titles = [
    'Диагностика',
    'История',
    'Библиотека',
    'Территория себя',
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _selectedIndex);
  }
  
  // Using getter to lazily initialize screens with callbacks
  List<Widget> get screens {
      return [
        HomeScreen(onMenuTap: _openDrawer),
        HistoryScreen(onMenuTap: _openDrawer),
        LibraryScreen(onMenuTap: _openDrawer),
        GameScreen(onMenuTap: _openDrawer),
      ];
  }

  void _openDrawer() {
     _scaffoldKey.currentState?.openDrawer();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _onItemTapped(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _navigateTo(int index) {
     Navigator.pop(context); // Close drawer
     _onItemTapped(index);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isLandscape = constraints.maxWidth > constraints.maxHeight;

        if (isLandscape) {
          return Scaffold(
             key: _scaffoldKey,
             appBar: null,
             drawer: _buildDrawer(),
             body: SafeArea(
               child: Row(
                 children: [
                   // Main Content
                   Expanded(
                     child: PageView(
                       controller: _pageController,
                       onPageChanged: _onPageChanged,
                       children: screens, // Use getter
                     ),
                   ),
                   // Vertical Divider
                   const VerticalDivider(width: 1, thickness: 1, color: Colors.white12),
                   // Navigation Rail (Right Side)
                   NavigationRail(
                     selectedIndex: _selectedIndex,
                     onDestinationSelected: _onItemTapped,
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
            key: _scaffoldKey,
            appBar: null,
            drawer: _buildDrawer(),
            body: PageView(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              children: screens, // Use getter
            ),
            bottomNavigationBar: SafeArea(
              child: BottomNavigationBar(
                currentIndex: _selectedIndex,
                onTap: _onItemTapped,
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

  Widget _buildDrawer() {
     return Drawer(
        backgroundColor: const Color(0xFF0F172A),
        child: Column(
           children: [
              DrawerHeader(
                 decoration: const BoxDecoration(
                    gradient: LinearGradient(
                       colors: [Color(0xFF2E0249), Color(0xFF1E293B)],
                       begin: Alignment.topLeft,
                       end: Alignment.bottomRight
                    )
                 ),
                 child: Center(
                    child: Column(
                       mainAxisAlignment: MainAxisAlignment.center,
                       children: [
                          Container(
                             padding: const EdgeInsets.all(2),
                             decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                             ),
                             child: ClipOval(
                                child: Image.asset(
                                   'assets/images/logo.jpg', 
                                   height: 60, 
                                   width: 60, 
                                   fit: BoxFit.cover,
                                   errorBuilder: (_,__,___)=>const Icon(Icons.account_circle, size: 60, color: Colors.grey)
                                ),
                             ),
                          ),
                          const SizedBox(height: 12),
                          const Text("Территория Себя", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                       ],
                    ),
                 ),
              ),
              ListTile(
                 leading: const Icon(Icons.home, color: Colors.white70),
                 title: const Text('Главная', style: TextStyle(color: Colors.white)),
                 selected: _selectedIndex == 0,
                 selectedTileColor: Colors.blue.withOpacity(0.1),
                 onTap: () => _navigateTo(0),
              ),
              ListTile(
                 leading: const Icon(Icons.history, color: Colors.white70),
                 title: const Text('История', style: TextStyle(color: Colors.white)),
                 selected: _selectedIndex == 1,
                 selectedTileColor: Colors.blue.withOpacity(0.1),
                 onTap: () => _navigateTo(1),
              ),
              ListTile(
                 leading: const Icon(Icons.menu_book, color: Colors.white70),
                 title: const Text('Библиотека', style: TextStyle(color: Colors.white)),
                 selected: _selectedIndex == 2,
                 selectedTileColor: Colors.blue.withOpacity(0.1),
                 onTap: () => _navigateTo(2),
              ),
              ListTile(
                 leading: const Icon(Icons.casino, color: Colors.white70),
                 title: const Text('Игра', style: TextStyle(color: Colors.white)),
                 selected: _selectedIndex == 3,
                 selectedTileColor: Colors.blue.withOpacity(0.1),
                 onTap: () => _navigateTo(3),
              ),
              const Divider(color: Colors.white24),
              ListTile(
                 leading: const Icon(Icons.star, color: Colors.amber),
                 title: const Text('Фестиваль', style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                 onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/festival');
                 },
              ),
           ],
        ),
     );
  }
}