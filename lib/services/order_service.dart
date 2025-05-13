// lib/services/order_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import 'cart_service.dart';

class OrderService {
  static final SupabaseClient _db = Supabase.instance.client;

  /// Создаёт новый заказ в трёх таблицах и очищает локальную корзину.
  static Future<void> createOrder({
    required String name,
    required String phone,
    required bool isDelivery,
    required String paymentMethod,
    required String city,
    required String street,
    required String houseNumber,
    required String postalCode,
    required bool isCustomTime,
    DateTime? scheduledTime,
  }) async {
    // 1) Вставляем запись в таблицу orders и сразу возвращаем её поля
    final PostgrestResponse orderRes = await _db
        .from('orders')
        .insert({
          'user_id': _db.auth.currentUser!.id,
          'name': name,
          'phone': phone,
          'is_delivery': isDelivery,
          'payment_method': paymentMethod,
          'city': city,
          'street': street,
          'house_number': houseNumber,
          'postal_code': postalCode,
          'scheduled_time': isCustomTime && scheduledTime != null
              ? scheduledTime.toIso8601String()
              : null,
        })
        .select()            // без аргумента — вернёт все поля
        .single()            // ожидаем ровно одну запись
        .execute();          // здесь и получаем PostgrestResponse

    if (orderRes.error != null) {
      throw orderRes.error!;  // бросаем ошибку Supabase
    }

    // приводим data к нужному типу
    final orderData = orderRes.data as Map<String, dynamic>;
    final int orderId = orderData['id'] as int;

    // 2) Вставляем все позиции из локальной корзины
    final items = List<CartItem>.from(CartService.items);
    for (final item in items) {
      final PostgrestResponse itemRes = await _db
          .from('order_items')
          .insert({
            'order_id': orderId,
            'menu_item_id': item.itemId,
            'size': item.size,
            'quantity': 1,
            'base_price': item.basePrice,
          })
          .select()
          .single()
          .execute();

      if (itemRes.error != null) {
        throw itemRes.error!;
      }

      final itemData = itemRes.data as Map<String, dynamic>;
      final int orderItemId = itemData['id'] as int;

      // 3) Вставляем добавки к этой позиции
      for (final extraEntry in item.extras.entries) {
        final PostgrestResponse extraRes = await _db
            .from('order_item_extras')
            .insert({
              'order_item_id': orderItemId,
              'extra_id': extraEntry.key,
              'quantity': extraEntry.value,
            })
            .execute();

        if (extraRes.error != null) {
          throw extraRes.error!;
        }
      }
    }

    // 4) Очищаем локальную корзину
    await CartService.clear();
  }

  /// Забирает историю заказов текущего пользователя вместе с позициями и их добавками
  static Future<List<Map<String, dynamic>>> getOrderHistory() async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) {
      return [];
    }

    final PostgrestResponse historyRes = await _db
        .from('orders')
        .select<List<Map<String, dynamic>>>(
          '''
          *,
          order_items (
            *,
            order_item_extras (*)
          )
          '''
        )
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .execute();

    if (historyRes.error != null) {
      throw historyRes.error!;
    }

    // data — это List<dynamic>, приводим к нужному формату
    final rawList = historyRes.data as List<dynamic>;
    return rawList.cast<Map<String, dynamic>>();
  }
}
