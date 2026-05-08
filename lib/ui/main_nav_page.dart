import 'package:flutter/material.dart';
import 'package:quick_pdf/ui/home_screen.dart';
import 'package:quick_pdf/ui/tools_screen.dart';
import 'package:quick_pdf/ui/settings_screen.dart';

class QuickPDFHomePage extends StatefulWidget {
  const QuickPDFHomePage({super.key});

  @override
  State<QuickPDFHomePage> createState() => _QuickPDFHomePageState();
}

class _QuickPDFHomePageState extends State<QuickPDFHomePage> {
  int _index = 0;

  static const _pages = <Widget>[
    HomeScreen(),
    ToolsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.build_outlined),
            selectedIcon: Icon(Icons.build),
            label: 'Tools',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
