// lib/services/cart_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Модель одного пункта в корзине
class CartItem {
  final int itemId;
  final String name;
  final String size;
  final double basePrice;
  final Map<int, int> extras; // extraId -> quantity
  final String? article;
  final int? sizeId; // nullable sizeId

  CartItem({
    required this.itemId,
    required this.name,
    required this.size,
    required this.basePrice,
    required this.extras,
    this.article,
    this.sizeId,
  });

  /// Десериализация из JSON
  factory CartItem.fromJson(Map<String, dynamic> json) {
    final dynamic rawExtras = json['extras'];

    Map<int, int> parsedExtras;
    if (rawExtras is String) {
      if (rawExtras.isEmpty) {
        parsedExtras = <int, int>{};
      } else {
        final decoded = jsonDecode(rawExtras);
        if (decoded is Map) {
          parsedExtras = decoded.cast<int, int>();
        } else {
          parsedExtras = <int, int>{};
        }
      }
    } else if (rawExtras is Map) {
      parsedExtras = (rawExtras as Map<String, dynamic>)
          .map((key, value) => MapEntry(int.parse(key), value as int));
    } else {
      parsedExtras = <int, int>{};
    }

    return CartItem(
      itemId: json['itemId'] as int,
      name: json['name'] as String,
      size: json['size'] as String,
      basePrice: (json['basePrice'] as num).toDouble(),
      extras: parsedExtras,
      article: json['article'] as String?,
      sizeId: json['sizeId'] as int?,
    );
  }

  /// Сериализация в JSON
  Map<String, dynamic> toJson() => {
        'itemId': itemId,
        'name': name,
        'size': size,
        'basePrice': basePrice,
        'extras': jsonEncode(extras),
        'article': article,
        'sizeId': sizeId,
      };
}

/// Сервис «Корзина»
class CartService {
  static const _storageKey = 'cart_items';
  static SharedPreferences? _prefs;
  static final List<CartItem> _items = [];

  // ValueNotifier для подписки на изменения корзины
  static final ValueNotifier<int> cartCountNotifier = ValueNotifier<int>(_items.length);

  /// Инициализация: загрузка из SharedPreferences
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_storageKey);
    if (raw != null) {
      final list = jsonDecode(raw) as List<dynamic>;
      _items
        ..clear()
        ..addAll(
          list.map((e) => CartItem.fromJson(e as Map<String, dynamic>)).toList(),
        );
      cartCountNotifier.value = _items.length;
    }
  }

  /// Немодифицируемый доступ к списку
  static List<CartItem> get items => List.unmodifiable(_items);

  /// Добавить одну единицу CartItem
  static Future<void> addItem(CartItem item) async {
    _items.add(item);
    cartCountNotifier.value = _items.length;
    await _save();
  }

  /// Удалить ровно одну копию указанного CartItem
  static Future<void> removeItem(CartItem item) async {
    for (var i = 0; i < _items.length; i++) {
      final it = _items[i];
      if (it.itemId == item.itemId &&
          it.size == item.size &&
          mapEquals(it.extras, item.extras)) {
        _items.removeAt(i);
        break;
      }
    }
    cartCountNotifier.value = _items.length;
    await _save();
  }

  /// Полностью очистить корзину
  static Future<void> clear() async {
    _items.clear();
    cartCountNotifier.value = 0;
    await _save();
  }

  /// Сохранить текущее состояние в SharedPreferences
  static Future<void> _save() async {
    _prefs ??= await SharedPreferences.getInstance();
    final raw = jsonEncode(_items.map((e) => e.toJson()).toList());
    await _prefs!.setString(_storageKey, raw);
  }

  /// Повторить прошлый заказ: подтянуть из order_items и добавить в корзину
  static Future<void> repeatOrder(int orderId) async {
    final data = await Supabase.instance.client
        .from('order_items')
        .select() // получаем все поля
        .eq('order_id', orderId);
    final list = data as List<dynamic>;
    for (var e in list) {
      final m = e as Map<String, dynamic>;

      // Определяем размер: если есть size_id, получаем имя, иначе берём строку из m['size']
      String resolvedSize;
      int? resolvedSizeId;
      if (m['size_id'] != null) {
        final sizeRow = await Supabase.instance.client
            .from('menu_size')
            .select('name')
            .eq('id', m['size_id'])
            .maybeSingle();
        resolvedSize = sizeRow != null
            ? (sizeRow['name'] as String)
            : (m['size'] as String);
        resolvedSizeId = m['size_id'] as int;
      } else {
        resolvedSize = m['size'] as String;
        resolvedSizeId = null;
      }

      // Обрабатываем extras из m['extras']
      final dynamic rawExtras = m['extras'];
      Map<int, int> parsedExtras;
      if (rawExtras is String) {
        if (rawExtras.isEmpty) {
          parsedExtras = <int, int>{};
        } else {
          final decoded = jsonDecode(rawExtras);
          parsedExtras = (decoded as Map).cast<int, int>();
        }
      } else if (rawExtras is Map) {
        parsedExtras = (rawExtras as Map<String, dynamic>)
            .map((key, value) => MapEntry(int.parse(key), value as int));
      } else {
        parsedExtras = <int, int>{};
      }

      final item = CartItem(
        itemId: m['menu_item_id'] as int,
        name: m['item_name'] as String,
        size: resolvedSize,
        basePrice: (m['price'] as num).toDouble(),
        extras: parsedExtras,
        article: m['article'] as String?,
        sizeId: resolvedSizeId,
      );
      await addItem(item);
    }
  }

  /// Добавить в корзину товар по его menu_item.id,
  /// автоматически подбирая размер с самой низкой ценой.
  static Future<void> addItemById(int itemId, {String defaultSize = 'Medium'}) async {
    final supabase = Supabase.instance.client;

    // 1) Получаем информацию о самом товаре (id, name, article)
    //    Обратите внимание, что поля base_price нет в схеме, поэтому не запрашиваем его.
    final itemRow = await supabase
        .from('menu_item')
        .select('id, name, article')
        .eq('id', itemId)
        .maybeSingle();

    if (itemRow == null) {
      throw Exception('Товар с id=$itemId не найден в menu_item');
    }

    final String itemName = itemRow['name'] as String;
    final String? article = itemRow['article'] as String?;

    // 2) Получаем все доступные пары (price + menu_size.name) для данного menu_item_id.
    final List<Map<String, dynamic>> priceRows = await supabase
        .from('menu_item_price')
        .select('price, menu_size(name)')
        .eq('menu_item_id', itemId)
        .order('price', ascending: true);

    if (priceRows.isEmpty) {
      // Если у товара нет записей в menu_item_price, используем defaultSize и ставим цену = 0.0
      final CartItem newItem = CartItem(
        itemId: itemId,
        name: itemName,
        size: 'Standard', // fallback-строка при отсутствии данных о размерах
        basePrice: 0.0,
        extras: <int, int>{},
        article: article,
        sizeId: null,
      );
      await addItem(newItem);
      return;
    }

    // 3) Иначе выбираем первую запись (самая дешевая)
    final cheapest = priceRows.first;
    final double cheapestPrice = (cheapest['price'] as num).toDouble();
    final Map<String, dynamic> sizeObj = cheapest['menu_size'] as Map<String, dynamic>;
    final String cheapestSizeName = sizeObj['name'] as String;

    // 4) Собираем CartItem с самым маленьким размером и ценой
    final CartItem newItem = CartItem(
      itemId: itemId,
      name: itemName,
      size: cheapestSizeName,
      basePrice: cheapestPrice,
      extras: <int, int>{},
      article: article,
      sizeId: null,
    );

    await addItem(newItem);
  }
}
