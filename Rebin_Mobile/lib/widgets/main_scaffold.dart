import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';

class MainScaffold extends StatelessWidget {
  final Widget child;

  const MainScaffold({required this.child, super.key});

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    if (location == '/map') {
      return 1;
    }
    if (location == '/activity') { // DEĞİŞTİ
      return 2;
    }
    if (location == '/my-bins') { // DEĞİŞTİ
        return 3;
    }
    return 0; // Varsayılan olarak ana sayfa
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/');
        break;
      case 1:
        context.go('/map');
        break;
      case 2:
        context.go('/activity'); // DEĞİŞTİ
        break;
      case 3:
        context.go('/my-bins'); // DEĞİŞTİ
        break;
    }
  }
  
  void _onFabTapped(BuildContext context) {
    context.push('/camera');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: false, 
      body: SafeArea(
        bottom: false,
        child: child,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _onFabTapped(context),
        backgroundColor: const Color(0xFF4CAF50), 
        elevation: 4.0,
        shape: const CircleBorder(),
        child: SvgPicture.asset(
          'assets/icons/camera_icon.svg', 
          width: 28,
          height: 28,
          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomNavBar(context),
    );
  }

  Widget _buildBottomNavBar(BuildContext context) {
    return SafeArea(
      child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: BottomAppBar(
        color: Colors.transparent,
        elevation: 0,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            _buildNavItem(
              context: context,
              iconPath: 'assets/icons/home_icon.svg',
              label: 'Ana Sayfa',
              index: 0,
            ),
            _buildNavItem(
              context: context,
              iconPath: 'assets/icons/map_icon.svg',
              label: 'Harita',
              index: 1,
            ),
            const SizedBox(width: 40), // FAB için boşluk
            _buildNavItem(
              context: context,
              iconPath: 'assets/icons/apps_icon.svg',
              label: 'Aktivite',
              index: 2,
            ),
            _buildNavItem(
              context: context,
              iconData: Icons.recycling,
              label: 'Kutularım',
              index: 3,
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    String? iconPath,
    IconData? iconData,
    required String label,
    required int index,
  }) {
    final bool isSelected = _calculateSelectedIndex(context) == index;
    final Color color = isSelected ? const Color(0xFF4CAF50) : Colors.grey[700]!;

    return Expanded(
      child: InkWell(
        onTap: () => _onItemTapped(index, context),
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (iconPath != null)
                SvgPicture.asset(
                  iconPath,
                  width: 28,
                  height: 28,
                  colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                )
              else if (iconData != null)
                Icon(
                  iconData,
                  size: 28,
                  color: color,
                ),
              const SizedBox(height: 2), 
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12, 
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
