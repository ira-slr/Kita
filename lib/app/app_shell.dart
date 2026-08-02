import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/inventory/inventory_list_screen.dart';
import '../features/inventory/product_catalog_screen.dart';
import '../features/pos/pos_screen.dart';
import '../features/reports/reports_screen.dart';
import '../features/scanner/scanner_screen.dart';
import '../features/settings/settings_provider.dart';

/// The main app shell with bottom navigation and FAB.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  bool _fabExpanded = false;
  late final AnimationController _fabAnimController;
  late final Animation<double> _fabRotation;

  final _screens = const [
    DashboardScreen(),
    InventoryListScreen(),
    PosScreen(),
    ReportsScreen(),
  ];

  final _titles = const [
    'Dashboard',
    'Inventory',
    'Point of Sale',
    'Reports',
  ];

  @override
  void initState() {
    super.initState();
    _fabAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fabRotation = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(parent: _fabAnimController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _fabAnimController.dispose();
    super.dispose();
  }

  void _toggleFab() {
    setState(() => _fabExpanded = !_fabExpanded);
    if (_fabExpanded) {
      _fabAnimController.forward();
    } else {
      _fabAnimController.reverse();
    }
  }

  void _collapseFab() {
    if (_fabExpanded) {
      setState(() => _fabExpanded = false);
      _fabAnimController.reverse();
    }
  }

  Widget _buildInventoryFab(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Mini FABs (only when expanded)
        if (_fabExpanded) ...[
          _MiniFabOption(
            icon: Icons.document_scanner_rounded,
            label: 'Scan Receipt',
            color: colorScheme.secondary,
            onTap: () {
              _collapseFab();
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const ScannerScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          _MiniFabOption(
            icon: Icons.menu_book_outlined,
            label: 'Browse Catalog',
            color: Colors.teal,
            onTap: () {
              _collapseFab();
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const ProductCatalogScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          _MiniFabOption(
            icon: Icons.edit_note_rounded,
            label: 'Add Manually',
            color: colorScheme.primary,
            onTap: () {
              _collapseFab();
              Navigator.of(context).pushNamed('/inventory/add');
            },
          ),
          const SizedBox(height: 16),
        ],

        // Main FAB
        FloatingActionButton(
          onPressed: _toggleFab,
          child: RotationTransition(
            turns: _fabRotation,
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    return GestureDetector(
      onTap: _collapseFab, // Tap anywhere to collapse mini FABs
      child: DefaultTabController(
        length: _screens.length,
        child: Builder(builder: (context) {
          final tabController = DefaultTabController.of(context);
          tabController.addListener(() {
            if (!tabController.indexIsChanging &&
                tabController.index != _currentIndex) {
              setState(() => _currentIndex = tabController.index);
              _collapseFab();
            }
          });

          return Scaffold(
            appBar: AppBar(
              title: Text(
                _currentIndex == 0
                    ? (settings.storeName.isEmpty
                        ? 'SariSmart'
                        : settings.storeName)
                    : _titles[_currentIndex],
              ),
              actions: [
                if (_currentIndex == 1)
                  IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: 'Add Product',
                    onPressed: () =>
                        Navigator.of(context).pushNamed('/inventory/add'),
                  ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () =>
                      Navigator.of(context).pushNamed('/settings'),
                ),
              ],
            ),
            body: IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) {
                setState(() => _currentIndex = index);
                tabController.animateTo(index);
                _collapseFab();
              },
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard_outlined),
                  activeIcon: Icon(Icons.dashboard),
                  label: 'Dashboard',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.inventory_2_outlined),
                  activeIcon: Icon(Icons.inventory_2),
                  label: 'Inventory',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.point_of_sale_outlined),
                  activeIcon: Icon(Icons.point_of_sale),
                  label: 'POS',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.bar_chart_outlined),
                  activeIcon: Icon(Icons.bar_chart),
                  label: 'Reports',
                ),
              ],
            ),
            floatingActionButton: _currentIndex == 1
                ? _buildInventoryFab(context)
                : null,
          );
        }),
      ),
    );
  }
}

/// A mini FAB option shown above the main FAB when it is expanded.
class _MiniFabOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MiniFabOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label chip
        Material(
          color: Colors.white,
          elevation: 2,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                label,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Mini FAB button
        FloatingActionButton.small(
          heroTag: label,
          onPressed: onTap,
          backgroundColor: color,
          child: Icon(icon, color: Colors.white),
        ),
      ],
    );
  }
}
