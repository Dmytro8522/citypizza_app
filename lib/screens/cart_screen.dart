import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/cart_service.dart';
import 'menu_item_detail_screen.dart';
import 'home_screen.dart';
import 'checkout_screen.dart';

/// Вспомогательный класс для хранения информации по добавкам
class _ExtraInfo {
  final String name;
  final double price;
  final int quantity;
  _ExtraInfo({required this.name, required this.price, required this.quantity});
}

class CartScreen extends StatefulWidget {
  const CartScreen({Key? key}) : super(key: key);

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool _loadingDetails = true;
  double _totalSum = 0;

  @override
  void initState() {
    super.initState();
    CartService.init().then((_) {
      // после загрузки корзины пересчитаем общую сумму с учётом добавок
      _recalculateTotal();
    });
  }

  /// Загружает для всех строк корзины информацию по добавкам и обновляет _totalSum
  Future<void> _recalculateTotal() async {
    final items = CartService.items;
    // группируем по уникальным позициям с учётом добавок
    final grouped = <String, List<CartItem>>{};
    for (final cartItem in items) {
      final key =
          '${cartItem.itemId}|${cartItem.size}|${cartItem.extras.entries.map((e) => '${e.key}:${e.value}').join(',')}';
      grouped.putIfAbsent(key, () => []).add(cartItem);
    }

    double sum = 0;
    for (final entry in grouped.entries) {
      final first = entry.value.first;
      final count = entry.value.length;
      // считаем стоимость добавок для этой позиции
      final extras = await _loadExtrasInfo(first.extras, first.size);
      final extrasCost = extras.fold<double>(
        0,
        (prev, e) => prev + e.price * e.quantity,
      );
      sum += first.basePrice * count + extrasCost * count;
    }

    setState(() {
      _totalSum = sum;
      _loadingDetails = false;
    });
  }

  /// Берёт из Supabase названия и цены добавок для заданной size
  Future<List<_ExtraInfo>> _loadExtrasInfo(
      Map<int, int> extrasMap, String sizeName) async {
    if (extrasMap.isEmpty) return [];

    // 1) Находим id размера
    final szRow = await Supabase.instance.client
        .from('sizes')
        .select('id')
        .eq('name', sizeName)
        .single();
    final sizeId = szRow['id'] as int;

    // 2) Загружаем названия добавок
    final extraIds = extrasMap.keys.toList();
    final namesData = await Supabase.instance.client
        .from('extras')
        .select('id,name')
        .filter('id', 'in', extraIds);
    final nameMap = <int, String>{
      for (var e in namesData as List) e['id'] as int: e['name'] as String
    };

    // 3) Загружаем цены добавок для этого размера
    final priceData = await Supabase.instance.client
        .from('extra_price')
        .select('extra_id,price')
        .eq('size_id', sizeId)
        .filter('extra_id', 'in', extraIds);
    final priceMap = <int, double>{
      for (var p in priceData as List)
        p['extra_id'] as int: (p['price'] as num).toDouble()
    };

    // 4) Собираем список _ExtraInfo
    return extrasMap.entries.map((e) {
      final id = e.key;
      final qty = e.value;
      return _ExtraInfo(
        name: nameMap[id]!,
        price: priceMap[id] ?? 0,
        quantity: qty,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = CartService.items;
    // группируем одинаковые позиции по ключу
    final grouped = <String, List<CartItem>>{};
    for (final cartItem in items) {
      final key =
          '${cartItem.itemId}|${cartItem.size}|${cartItem.extras.entries.map((e) => '${e.key}:${e.value}').join(',')}';
      grouped.putIfAbsent(key, () => []).add(cartItem);
    }

    // подготавливаем данные для отображения (без extras cost — он будет загружен асинхронно)
    final lines = grouped.entries.map((entry) {
      final groupItems = entry.value;
      final first = groupItems.first;
      final count = groupItems.length;
      // предварительный total без добавок
      final totalBase = first.basePrice * count;
      return {'item': first, 'count': count, 'totalBase': totalBase};
    }).toList();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Warenkorb',
            style: GoogleFonts.fredokaOne(color: Colors.orange)),
        centerTitle: true,
      ),
      body: lines.isEmpty
          ? Center(
              child: Text('Ihr Warenkorb ist leer',
                  style: GoogleFonts.poppins(color: Colors.white70)),
            )
          : ListView.builder(
              padding:
                  const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              itemCount: lines.length,
              itemBuilder: (context, index) {
                final line = lines[index];
                final CartItem cartItem = line['item'] as CartItem;
                final int count = line['count'] as int;
                final double baseTotal = line['totalBase'] as double;

                return FutureBuilder<List<_ExtraInfo>>(
                  future:
                      _loadExtrasInfo(cartItem.extras, cartItem.size),
                  builder: (context, snap) {
                    final extras = snap.data ?? [];
                    final extrasCost = extras.fold<double>(
                        0, (p, e) => p + e.price * e.quantity);
                    final lineTotal =
                        baseTotal + extrasCost;

                    return InkWell(
                      onTap: () async {
                        // Загружаем полные данные MenuItem из Supabase
                        final data = await Supabase.instance.client
                            .from('menu_item')
                            .select()
                            .eq('id', cartItem.itemId)
                            .single();
                        final menuItem =
                            MenuItem.fromMap(data as Map<String, dynamic>);
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                MenuItemDetailScreen(item: menuItem),
                          ),
                        );
                        setState(() {});
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(cartItem.name,
                                      style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight:
                                              FontWeight.w600)),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${cartItem.size}, Menge: $count',
                                    style: GoogleFonts.poppins(
                                        color: Colors.white54,
                                        fontSize: 12),
                                  ),
                                  // список добавок
                                  if (extras.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    ...extras.map((e) => Text(
                                          '+ ${e.name} ×${e.quantity} '
                                          '(€${(e.price * e.quantity).toStringAsFixed(2)})',
                                          style: GoogleFonts.poppins(
                                              color: Colors.white70,
                                              fontSize: 12),
                                        )),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment:
                                  CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '€${lineTotal.toStringAsFixed(2)}',
                                  style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 16),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                          Icons.remove_circle_outline,
                                          color: Colors.white),
                                      onPressed: () async {
                                        await CartService
                                            .removeItem(cartItem);
                                        await _recalculateTotal();
                                        setState(() {});
                                      },
                                    ),
                                    Text('$count',
                                        style: GoogleFonts.poppins(
                                            color: Colors.white,
                                            fontSize: 14)),
                                    IconButton(
                                      icon: const Icon(
                                          Icons.add_circle_outline,
                                          color: Colors.white),
                                      onPressed: () async {
                                        await CartService
                                            .addItem(cartItem);
                                        await _recalculateTotal();
                                        setState(() {});
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
      bottomNavigationBar: lines.isEmpty
          ? null
          : Padding(
              padding: const EdgeInsets.all(16),
              child: _loadingDetails
                  // пока пересчитывается общая сумма, показываем индикатор
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: Colors.orange),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Gesamt:',
                                style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 18)),
                            Text(
                                '€${_totalSum.toStringAsFixed(2)}',
                                style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 18)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            minimumSize:
                                const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(30)),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    CheckoutScreen(
                                        totalSum: _totalSum),
                              ),
                            );
                          },
                          child: Text('Zur Kasse',
                              style: GoogleFonts.poppins(
                                  color: Colors.black,
                                  fontSize: 18)),
                        ),
                      ],
                    ),
            ),
    );
  }
}
