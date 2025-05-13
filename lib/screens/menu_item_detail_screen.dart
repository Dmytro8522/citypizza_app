// lib/screens/menu_item_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'home_screen.dart'; // для модели MenuItem и ExtraOption
import '../services/cart_service.dart'; // CartItem и CartService
import 'cart_screen.dart'; // для перехода в корзину

class ExtraOption {
  final int id;
  final String name;
  final double price;
  int quantity;
  ExtraOption({
    required this.id,
    required this.name,
    required this.price,
    this.quantity = 0,
  });
}

class MenuItemDetailScreen extends StatefulWidget {
  final MenuItem item;
  const MenuItemDetailScreen({Key? key, required this.item}) : super(key: key);

  @override
  State<MenuItemDetailScreen> createState() => _MenuItemDetailScreenState();
}

class _MenuItemDetailScreenState extends State<MenuItemDetailScreen> {
  final _supabase = Supabase.instance.client;
  late Map<String, double> _sizeOptions;
  String? _selectedSize;
  List<ExtraOption> _extras = [];
  bool _loadingExtras = false;

  @override
  void initState() {
    super.initState();
    _initSizes();
  }

  Future<void> _initSizes() async {
    _sizeOptions = {
      if (widget.item.klein != null) 'klein': widget.item.klein!,
      if (widget.item.normal != null) 'normal': widget.item.normal!,
      if (widget.item.gross != null) 'gross': widget.item.gross!,
      if (widget.item.familie != null) 'familie': widget.item.familie!,
      if (widget.item.party != null) 'party': widget.item.party!,
    };
    if (_sizeOptions.isNotEmpty) {
      _selectedSize = _sizeOptions.entries.reduce((a, b) => a.value < b.value ? a : b).key;
    }
    await _loadExtras();
    setState(() {});
  }

  Future<void> _loadExtras() async {
    if (_selectedSize == null) return;
    setState(() => _loadingExtras = true);

    final selectedSize = _selectedSize!;
    final szRow = await _supabase.from('sizes').select('id').eq('name', selectedSize).single();
    final sizeId = szRow['id'] as int;

    final meRows = await _supabase
        .from('menu_item_extras')
        .select('extra_id')
        .eq('menu_item_id', widget.item.id);
    final extraIds = (meRows as List).map((e) => e['extra_id'] as int).toList();
    if (extraIds.isEmpty) {
      _extras = [];
      setState(() => _loadingExtras = false);
      return;
    }

    final eRows = await _supabase
        .from('extras')
        .select('id,name')
        .filter('id', 'in', extraIds);
    final pRows = await _supabase
        .from('extra_price')
        .select('extra_id,price')
        .eq('size_id', sizeId)
        .filter('extra_id', 'in', extraIds);

    final priceMap = <int, double>{};
    for (var row in pRows as List) {
      priceMap[row['extra_id'] as int] = (row['price'] as num).toDouble();
    }

    _extras = (eRows as List)
        .where((r) => priceMap.containsKey(r['id'] as int))
        .map((r) {
      final id = r['id'] as int;
      return ExtraOption(id: id, name: r['name'] as String, price: priceMap[id]!);
    }).toList();

    setState(() => _loadingExtras = false);
  }

  void _onSizeChanged(String? newSize) async {
    if (newSize == null) return;
    setState(() => _selectedSize = newSize);
    await _loadExtras();
  }

  void _close() => Navigator.pop(context);

  Future<void> _addToCart() async {
    final extrasMap = <int, int>{
      for (var e in _extras)
        if (e.quantity > 0) e.id: e.quantity
    };
    final cartItem = CartItem(
      itemId: widget.item.id,
      name: widget.item.name,
      size: _selectedSize!,
      basePrice: _sizeOptions[_selectedSize!]!,
      extras: extrasMap,
    );
    await CartService.addItem(cartItem);

    final totalExtras = extrasMap.values.fold<int>(0, (sum, e) => sum + e);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.grey[900],
        duration: const Duration(seconds: 3),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.item.name} ($_selectedSize) hinzugefügt mit $totalExtras Extras',
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CartScreen()),
                    );
                  },
                  child: const Text('Zum Warenkorb'),
                  style: TextButton.styleFrom(foregroundColor: Colors.yellow),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  },
                  child: const Text('Weiter bestellen'),
                  style: TextButton.styleFrom(foregroundColor: Colors.yellow),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(item.name, style: GoogleFonts.fredokaOne(color: Colors.orange)),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.close), onPressed: _close),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (item.imageUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(item.imageUrl!, height: 240, fit: BoxFit.cover),
            ),
            const SizedBox(height: 16),
          ],
          Text(item.name,
              style: GoogleFonts.fredokaOne(fontSize: 28, color: Colors.white)),
          if (item.description != null) ...[
            const SizedBox(height: 8),
            Text(item.description!,
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 16)),
          ],
          const SizedBox(height: 24),
          Text('Größen und Preise:', style: GoogleFonts.poppins(color: Colors.white, fontSize: 18)),
          const SizedBox(height: 8),
          ..._sizeOptions.entries.map((e) => RadioListTile<String>(
                activeColor: Colors.orange,
                value: e.key,
                groupValue: _selectedSize,
                title: Text(
                  '${e.key[0].toUpperCase()}${e.key.substring(1)} — ${e.value.toStringAsFixed(2)} €',
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
                onChanged: _onSizeChanged,
              )),
          const SizedBox(height: 24),
          if (_loadingExtras)
            const Center(child: CircularProgressIndicator(color: Colors.orange)),
          if (!_loadingExtras && _extras.isNotEmpty) ...[
            Text('Extras:', style: GoogleFonts.poppins(color: Colors.white, fontSize: 18)),
            const SizedBox(height: 8),
            ..._extras.map((opt) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                          child: Text('${opt.name} (+${opt.price.toStringAsFixed(2)} €)',
                              style: const TextStyle(color: Colors.white))),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.white),
                        onPressed: () => setState(() {
                          if (opt.quantity > 0) opt.quantity--;
                        }),
                      ),
                      Text('${opt.quantity}', style: const TextStyle(color: Colors.white)),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                        onPressed: () => setState(() => opt.quantity++),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 24),
          ],
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            onPressed: _selectedSize == null ? null : _addToCart,
            child: Text('In den Warenkorb', style: GoogleFonts.poppins(color: Colors.black, fontSize: 18)),
          ),
        ],
      ),
    );
  }
}
