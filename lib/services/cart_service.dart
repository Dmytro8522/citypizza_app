import 'dart:convert';
import 'package:flutter/foundation.dart';           // для mapEquals
import 'package:shared_preferences/shared_preferences.dart';

/// Сами данные товара в корзине
class CartItem {
  final int itemId;
  final String name;
  final String size;
  final double basePrice;
  final Map<int, int> extras; // extraId -> quantity

  CartItem({
    required this.itemId,
    required this.name,
    required this.size,
    required this.basePrice,
    required this.extras,
  });

  Map<String, dynamic> toJson() => {
        'itemId': itemId,
        'name': name,
        'size': size,
        'basePrice': basePrice,
        'extras': extras.map((k, v) => MapEntry(k.toString(), v)),
      };

  factory CartItem.fromJson(Map<String, dynamic> m) => CartItem(
        itemId: m['itemId'] as int,
        name: m['name'] as String,
        size: m['size'] as String,
        basePrice: (m['basePrice'] as num).toDouble(),
        extras: (m['extras'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(int.parse(k), v as int)),
      );
}

class CartService {
  static const _key = 'cart_items';
  static SharedPreferences? _prefs;
  static List<CartItem> _items = [];

  /// Загружаем из SharedPreferences
  static Future init() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_key);
    if (raw != null) {
      final list = jsonDecode(raw) as List<dynamic>;
      _items = list.map((e) => CartItem.fromJson(e as Map<String, dynamic>)).toList();
    }
  }

  static List<CartItem> get items => List.unmodifiable(_items);

  /// Добавляем одну единицу товара
  static Future addItem(CartItem item) async {
    _items.add(item);
    await _save();
  }

  /// Удаляет ровно одну копию указанного CartItem (с теми же полями)
  static Future removeItem(CartItem item) async {
    for (var i = 0; i < _items.length; i++) {
      final it = _items[i];
      if (it.itemId == item.itemId &&
          it.size == item.size &&
          mapEquals(it.extras, item.extras)) {
        _items.removeAt(i);
        break;
      }
    }
    await _save();
  }

  /// Очищает всю корзину
  static Future clear() async {
    _items.clear();
    await _save();
  }

  /// Сохраняем текущее состояние
  static Future _save() async {
    final raw = jsonEncode(_items.map((e) => e.toJson()).toList());
    await _prefs!.setString(_key, raw);
  }
}
