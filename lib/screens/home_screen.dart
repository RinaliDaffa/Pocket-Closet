import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import 'wardrobe_screen.dart';
import 'outfit_screen.dart';
import 'stats_screen.dart';

class HomeScreen extends StatefulWidget {
  final User user;
  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  // Key untuk memaksa StatsScreen rebuild setiap kali tab-nya dipilih
  int _statsRefreshKey = 0;

  void _onTabTapped(int index) {
    // Setiap kali pindah ke Stats (index 2), increment key agar rebuild
    if (index == 2) {
      setState(() {
        _statsRefreshKey++;
        _currentIndex = index;
      });
    } else {
      setState(() => _currentIndex = index);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Keluar Akun',
          style: GoogleFonts.cormorantGaramond(
            color: AppTheme.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Yakin ingin keluar dari Pocket Closet?',
          style: GoogleFonts.dmSans(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Batal',
              style: GoogleFonts.dmSans(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await AuthService.instance.logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = ['Wardrobe', 'Outfits', 'Stats'];
    return Scaffold(
      appBar: AppBar(
        title: Text(
          tabs[_currentIndex].toUpperCase(),
          style: GoogleFonts.cormorantGaramond(
            color: AppTheme.goldPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w600,
            letterSpacing: 3,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppTheme.textSecondary),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      // IndexedStack untuk Wardrobe & Outfits agar scroll position preserved,
      // StatsScreen pakai ValueKey agar rebuild otomatis tiap dibuka
      body: Stack(
        children: [
          // Tab 0: Wardrobe — tetap hidup (IndexedStack style)
          Offstage(
            offstage: _currentIndex != 0,
            child: WardrobeScreen(userId: widget.user.uid),
          ),
          // Tab 1: Outfits — tetap hidup
          Offstage(
            offstage: _currentIndex != 1,
            child: OutfitScreen(userId: widget.user.uid),
          ),
          // Tab 2: Stats — rebuild setiap kali dikunjungi (refresh data)
          if (_currentIndex == 2)
            StatsScreen(
              key: ValueKey(_statsRefreshKey),
              userId: widget.user.uid,
            ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          border: Border(
            top: BorderSide(color: AppTheme.goldPrimary.withOpacity(0.15)),
          ),
        ),
        child: NavigationBar(
          backgroundColor: AppTheme.surfaceColor,
          indicatorColor: AppTheme.goldPrimary.withOpacity(0.2),
          selectedIndex: _currentIndex,
          onDestinationSelected: _onTabTapped,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.checkroom_outlined,
                  color: _currentIndex == 0
                      ? AppTheme.goldPrimary
                      : AppTheme.textSecondary),
              selectedIcon: const Icon(Icons.checkroom,
                  color: AppTheme.goldPrimary),
              label: 'Wardrobe',
            ),
            NavigationDestination(
              icon: Icon(Icons.style_outlined,
                  color: _currentIndex == 1
                      ? AppTheme.goldPrimary
                      : AppTheme.textSecondary),
              selectedIcon:
                  const Icon(Icons.style, color: AppTheme.goldPrimary),
              label: 'Outfits',
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined,
                  color: _currentIndex == 2
                      ? AppTheme.goldPrimary
                      : AppTheme.textSecondary),
              selectedIcon: const Icon(Icons.bar_chart,
                  color: AppTheme.goldPrimary),
              label: 'Stats',
            ),
          ],
        ),
      ),
    );
  }
}
