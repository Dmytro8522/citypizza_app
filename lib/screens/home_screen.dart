import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'menu_item_detail_screen.dart';
import 'menu_screen.dart';
import 'cart_screen.dart';
import 'profile_screen.dart';
import 'profile_screen_auth.dart';
import '../services/cart_service.dart';

/// Модель пункта меню
class MenuItem {
  final int id;
  final String name;
  final String? description;
  final String? imageUrl;
  final double? klein;
  final double? normal;
  final double? gross;
  final double? familie;
  final double? party;

  MenuItem({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    this.klein,
    this.normal,
    this.gross,
    this.familie,
    this.party,
  });

  factory MenuItem.fromMap(Map<String, dynamic> m) => MenuItem(
        id: m['id'] as int,
        name: m['name'] as String,
        description: m['description'] as String?,
        imageUrl: m['image'] as String?,
        klein: (m['klein'] as num?)?.toDouble(),
        normal: (m['normal'] as num?)?.toDouble(),
        gross: (m['gross'] as num?)?.toDouble(),
        familie: (m['familie'] as num?)?.toDouble(),
        party: (m['party'] as num?)?.toDouble(),
      );

  double get minPrice {
    final prices = <double>[];
    if (klein != null) prices.add(klein!);
    if (normal != null) prices.add(normal!);
    if (gross != null) prices.add(gross!);
    if (familie != null) prices.add(familie!);
    if (party != null) prices.add(party!);
    if (prices.isEmpty) return 0.0;
    prices.sort();
    return prices.first;
  }
}

class HomeScreen extends StatefulWidget {
  /// Индекс вкладки, на которую нужно сразу перейти
  final int initialIndex;

  const HomeScreen({Key? key, this.initialIndex = 0}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();

  List<MenuItem> _allItems = [];
  List<MenuItem> _filteredItems = [];
  bool _loading = true;
  String? _error;
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _loadMenu();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filteredItems = q.isEmpty
          ? List.from(_allItems)
          : _allItems.where((item) => item.name.toLowerCase().contains(q)).toList();
    });
  }

  Future<void> _loadMenu() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _supabase.from('menu_item').select().order('id', ascending: true);
      final list = data as List<dynamic>;
      _allItems = list.map((e) => MenuItem.fromMap(e as Map<String, dynamic>)).toList();
      _filteredItems = List.from(_allItems);
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator(color: Colors.orange));
    } else if (_error != null) {
      body = Center(
        child: Text('Fehler: $_error', style: GoogleFonts.poppins(color: Colors.white)),
      );
    } else if (_selectedIndex == 0) {
      body = _buildHomeTab();
    } else if (_selectedIndex == 1) {
      body = const MenuScreen();
    } else {
      // вкладка "Profil": показываем разный экран в зависимости от авторизации
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        body = const ProfileScreenAuth();
      } else {
        body = const ProfileScreen();
      }
    }

    String title;
    if (_selectedIndex == 0) {
      title = 'City Pizza';
    } else if (_selectedIndex == 1) {
      title = 'Menü';
    } else {
      title = 'Profil';
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: Text(title, style: GoogleFonts.fredokaOne(color: Colors.orange)),
        centerTitle: true,
        elevation: 0,
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart, color: Colors.white),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen()))
                      .then((_) => setState(() {}));
                },
              ),
              if (CartService.items.isNotEmpty)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '${CartService.items.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: body,
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black,
        selectedItemColor: Colors.orange,
        unselectedItemColor: Colors.white54,
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.local_pizza), label: 'Menü'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }

  Widget _buildHomeTab() {
    return Column(
      children: [
        TextField(
          controller: _searchController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Suche Pizza…',
            hintStyle: const TextStyle(color: Colors.white54),
            prefixIcon: const Icon(Icons.search, color: Colors.white54),
            filled: true,
            fillColor: Colors.white10,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Unsere Spezialitäten',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: GridView.builder(
            itemCount: _filteredItems.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.75,
            ),
            itemBuilder: (context, i) {
              final item = _filteredItems[i];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => MenuItemDetailScreen(item: item)),
                  ).then((_) => setState(() {}));
                },
                child: _MenuCard(item: item),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MenuCard extends StatelessWidget {
  final MenuItem item;
  const _MenuCard({Key? key, required this.item}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: item.imageUrl != null
                  ? Image.network(item.imageUrl!, fit: BoxFit.cover)
                  : const SizedBox.shrink(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (item.description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.description!,
                    style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  'ab ${item.minPrice.toStringAsFixed(2)} €',
                  style: GoogleFonts.poppins(
                    color: Colors.orange,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
