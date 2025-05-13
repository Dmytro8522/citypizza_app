import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/cart_service.dart';
import 'cart_screen.dart';
import 'menu_item_detail_screen.dart';
import 'home_screen.dart';


class Category {
  final int id;
  final String name;
  Category({required this.id, required this.name});
}

class MenuScreen extends StatefulWidget {
  const MenuScreen({Key? key}) : super(key: key);

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  String? _error;
  List<Category> _categories = [];
  Map<int, List<MenuItem>> _itemsByCat = {};

  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  Future<void> _loadMenu() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final catData = await _supabase
          .from('categories')
          .select('id,name')
          .order('name', ascending: true);
      _categories = (catData as List)
          .map((m) => Category(id: m['id'] as int, name: m['name'] as String))
          .toList();

      for (final cat in _categories) {
        final itemsData = await _supabase
            .from('menu_item')
            .select()
            .eq('category_id', cat.id)
            .order('id', ascending: true);
        final list = (itemsData as List)
            .map((e) => MenuItem.fromMap(e as Map<String, dynamic>))
            .toList();
        _itemsByCat[cat.id] = list;
      }
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        // Показываем стрелку «назад», только если можем вернуться
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.orange),
      );
    }
    if (_error != null) {
      return Center(
        child: Text(
          'Fehler: $_error',
          style: const TextStyle(color: Colors.white),
        ),
      );
    }
    return ListView.builder(
      itemCount: _categories.length,
      itemBuilder: (_, idx) {
        final cat = _categories[idx];
        final items = _itemsByCat[cat.id] ?? [];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  cat.name,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 260,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, i) {
                    final item = items[i];
                    return GestureDetector(
                      onTap: () async {
                        final data = await Supabase.instance.client
                            .from('menu_item')
                            .select()
                            .eq('id', item.id)
                            .single();
                        final menuItem = MenuItem.fromMap(
                            data as Map<String, dynamic>);
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                MenuItemDetailScreen(item: menuItem),
                          ),
                        );
                        setState(() {});
                      },
                      child: SizedBox(
                        width: 140,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: item.imageUrl != null
                                    ? Image.network(
                                        item.imageUrl!,
                                        fit: BoxFit.cover,
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item.name,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'ab ${item.minPrice.toStringAsFixed(2)} €',
                              style: GoogleFonts.poppins(
                                color: Colors.orange,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
