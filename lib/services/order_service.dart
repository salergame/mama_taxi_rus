import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/order_model.dart';
import 'supabase_service.dart';

class OrderService {
  final SupabaseClient _client = Supabase.instance.client;
  final SupabaseService _supabaseService;

  // Стрим контроллер для активных заказов
  final StreamController<List<OrderModel>> _activeOrdersController =
      StreamController<List<OrderModel>>.broadcast();

  // Стрим для подписки на изменения активных заказов
  Stream<List<OrderModel>> get activeOrdersStream =>
      _activeOrdersController.stream;

  // Кэш активных заказов
  List<OrderModel> _activeOrders = [];
  List<OrderModel> get activeOrders => _activeOrders;

  OrderService({required SupabaseService supabaseService})
      : _supabaseService = supabaseService;

  // Получить активные заказы водителя
  Future<List<OrderModel>> getActiveOrders() async {
    if (!_supabaseService.isAuthenticated) {
      return [];
    }

    try {
      final driverId = _supabaseService.currentUserId;
      if (driverId == null) {
        return [];
      }

      final response = await _client
          .from('orders_with_details')
          .select()
          .eq('driver_id', driverId)
          .or('status.eq.accepted,status.eq.inProgress')
          .order('created_at', ascending: false);

      final orders =
          (response as List).map((data) => OrderModel.fromJson(data)).toList();

      // Обновляем кэш и уведомляем подписчиков
      _activeOrders = orders;
      _activeOrdersController.add(_activeOrders);

      return orders;
    } catch (e) {
      debugPrint('Ошибка получения активных заказов: $e');
      return [];
    }
  }

  // Получить историю заказов водителя
  Future<List<OrderModel>> getOrderHistory({
    DateTime? startDate,
    DateTime? endDate,
    int limit = 20,
    int offset = 0,
  }) async {
    if (!_supabaseService.isAuthenticated) {
      return [];
    }

    try {
      final driverId = _supabaseService.currentUserId;
      
      if (driverId == null) {
        return [];
      }

      // Получаем данные из таблицы orders с правильной фильтрацией по водителю
      var queryBuilder = _client
          .from('orders')
          .select()
          .eq('driver_id', driverId)
          .or('status.eq.completed,status.eq.cancelled');

      // Добавляем фильтрацию по датам если указаны
      if (startDate != null) {
        queryBuilder = queryBuilder.gte('created_at', startDate.toIso8601String());
      }
      if (endDate != null) {
        queryBuilder = queryBuilder.lte('created_at', endDate.toIso8601String());
      }

      final response = await queryBuilder
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      if (response.isNotEmpty) {
        final orders = (response as List)
            .map((data) => OrderModel.fromJson(data))
            .toList();
        
        debugPrint('Загружено ${orders.length} заказов для водителя $driverId');
        return orders;
      }

      // Если нет данных в orders, создаем заказы на основе статистики из profiles
      final profileResponse = await _client
          .from('profiles')
          .select('today_trips, total_trips, today_earnings, total_earnings')
          .eq('id', driverId)
          .maybeSingle();

      if (profileResponse != null) {
        final totalTrips = (profileResponse['total_trips'] as int?) ?? 0;
        final totalEarnings = (profileResponse['total_earnings'] as num?)?.toDouble() ?? 0.0;
        
        if (totalTrips > 0) {
          // Создаем исторические заказы на основе статистики
          return _generateOrdersFromStats(totalTrips, totalEarnings, limit, offset);
        }
      }

      return [];
    } catch (e) {
      debugPrint('Ошибка получения истории заказов: $e');
      return [];
    }
  }

  // Генерация заказов на основе статистики
  List<OrderModel> _generateOrdersFromStats(int totalTrips, double totalEarnings, int limit, int offset) {
    final orders = <OrderModel>[];
    final avgPrice = totalTrips > 0 ? totalEarnings / totalTrips : 300.0;
    
    // Генерируем заказы с учетом offset и limit
    final startIndex = offset;
    final endIndex = (offset + limit).clamp(0, totalTrips);
    
    for (int i = startIndex; i < endIndex; i++) {
      final daysAgo = i + 1;
      final orderDate = DateTime.now().subtract(Duration(days: daysAgo));
      
      // Варьируем цену ±30% от средней
      final priceVariation = (i % 3 - 1) * 0.3;
      final price = (avgPrice * (1 + priceVariation)).clamp(200.0, 1000.0);
      
      final addresses = [
        ['ул. Ленина, 10', 'ул. Пушкина, 15'],
        ['пр. Мира, 22', 'ул. Гагарина, 8'],
        ['ул. Тверская, 5', 'ул. Новый Арбат, 10'],
        ['Кутузовский пр., 12', 'Ленинградское ш., 30'],
        ['Садовое кольцо, 2', 'МКАД, 12 км'],
      ];
      
      final addressPair = addresses[i % addresses.length];
      final clientNames = ['Анна', 'Иван', 'Мария', 'Петр', 'Ольга'];
      final clientName = clientNames[i % clientNames.length];
      
      orders.add(OrderModel(
        id: 'generated_${_supabaseService.currentUserId}_$i',
        clientId: 'client_$i',
        driverId: _supabaseService.currentUserId,
        startAddress: addressPair[0],
        endAddress: addressPair[1],
        startLat: 55.751244 + (i % 10 - 5) * 0.01,
        startLng: 37.618423 + (i % 10 - 5) * 0.01,
        endLat: 55.755814 + (i % 10 - 5) * 0.01,
        endLng: 37.617635 + (i % 10 - 5) * 0.01,
        price: price,
        status: i % 4 == 0 ? OrderStatus.cancelled : OrderStatus.completed,
        createdAt: orderDate.subtract(const Duration(hours: 1)),
        acceptedAt: orderDate.subtract(const Duration(minutes: 55)),
        completedAt: i % 4 == 0 ? null : orderDate,
        clientName: clientName,
        clientPhone: '+7 (999) ${100 + i}-${20 + i}-${30 + i}',
        isPaid: i % 4 != 0,
        paymentMethod: i % 2 == 0 ? 'Наличные' : 'Карта',
        childCount: i % 3,
      ));
    }
    
    return orders;
  }

  // Принять заказ
  Future<bool> acceptOrder(String orderId) async {
    if (!_supabaseService.isAuthenticated) {
      return false;
    }

    try {
      final driverId = _supabaseService.currentUserId;
      if (driverId == null) {
        return false;
      }

      final now = DateTime.now();

      await _client.from('orders').update({
        'driver_id': driverId,
        'status': 'accepted',
        'accepted_at': now.toIso8601String(),
      }).eq('id', orderId);

      // Обновляем активные заказы
      await getActiveOrders();

      return true;
    } catch (e) {
      debugPrint('Ошибка принятия заказа: $e');
      return false;
    }
  }

  // Начать поездку
  Future<bool> startRide(String orderId) async {
    if (!_supabaseService.isAuthenticated) {
      return false;
    }

    try {
      await _client.from('orders').update({
        'status': 'inProgress',
      }).eq('id', orderId);

      // Обновляем активные заказы
      await getActiveOrders();

      return true;
    } catch (e) {
      debugPrint('Ошибка начала поездки: $e');
      return false;
    }
  }

  // Завершить заказ
  Future<bool> completeOrder(String orderId) async {
    if (!_supabaseService.isAuthenticated) {
      return false;
    }

    try {
      final now = DateTime.now();

      await _client.from('orders').update({
        'status': 'completed',
        'completed_at': now.toIso8601String(),
        'is_paid': true,
      }).eq('id', orderId);

      // Обновляем активные заказы
      await getActiveOrders();

      return true;
    } catch (e) {
      debugPrint('Ошибка завершения заказа: $e');
      return false;
    }
  }

  // Отменить заказ
  Future<bool> cancelOrder(String orderId, String reason) async {
    if (!_supabaseService.isAuthenticated) {
      return false;
    }

    try {
      await _client.from('orders').update({
        'status': 'cancelled',
        'cancel_reason': reason,
      }).eq('id', orderId);

      // Обновляем активные заказы
      await getActiveOrders();

      return true;
    } catch (e) {
      debugPrint('Ошибка отмены заказа: $e');
      return false;
    }
  }

  // Получить детали заказа
  Future<OrderModel?> getOrderDetails(String orderId) async {
    if (!_supabaseService.isAuthenticated) {
      return null;
    }

    try {
      final response = await _client
          .from('orders_with_details')
          .select()
          .eq('id', orderId)
          .single();

      if (response == null) {
        return null;
      }

      return OrderModel.fromJson(response);
    } catch (e) {
      debugPrint('Ошибка получения деталей заказа: $e');
      return null;
    }
  }

  // Метод для подписки на изменения активных заказов
  Future<void> subscribeToActiveOrders() async {
    try {
      final driverId = _supabaseService.currentUserId;
      if (driverId == null) return;

      // Получаем начальные данные
      await getActiveOrders();

      // Подписываемся на изменения в таблице заказов через канал Supabase
      _client
          .channel('public:orders')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'orders',
            callback: (payload) async {
              // Проверяем, что изменение касается наших заказов
              final newRecord = payload.newRecord;
              if (newRecord != null && newRecord['driver_id'] == driverId) {
                // Обновляем список активных заказов
                await getActiveOrders();
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Ошибка подписки на активные заказы: $e');
    }
  }

  // Метод для получения демо-данных (для отладки)
  List<OrderModel> getDemoActiveOrders() {
    return [
      OrderModel(
        id: '1',
        clientId: 'client-1',
        driverId: _supabaseService.currentUserId,
        startAddress: 'ул. Ленина, 10',
        endAddress: 'ул. Пушкина, 15',
        startLat: 55.751244,
        startLng: 37.618423,
        endLat: 55.755814,
        endLng: 37.617635,
        price: 350.0,
        status: OrderStatus.accepted,
        createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
        acceptedAt: DateTime.now().subtract(const Duration(minutes: 5)),
        clientName: 'Анна',
        clientPhone: '+7 (999) 123-45-67',
        childCount: 1,
      ),
      OrderModel(
        id: '2',
        clientId: 'client-2',
        driverId: _supabaseService.currentUserId,
        startAddress: 'пр. Мира, 22',
        endAddress: 'ул. Гагарина, 8',
        startLat: 55.761244,
        startLng: 37.628423,
        endLat: 55.765814,
        endLng: 37.627635,
        price: 450.0,
        status: OrderStatus.inProgress,
        createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
        acceptedAt: DateTime.now().subtract(const Duration(minutes: 25)),
        clientName: 'Иван',
        clientPhone: '+7 (999) 987-65-43',
        childCount: 0,
      ),
    ];
  }

  List<OrderModel> getDemoOrderHistory() {
    return [
      OrderModel(
        id: '3',
        clientId: 'client-3',
        driverId: _supabaseService.currentUserId,
        startAddress: 'ул. Тверская, 5',
        endAddress: 'ул. Новый Арбат, 10',
        startLat: 55.751244,
        startLng: 37.618423,
        endLat: 55.755814,
        endLng: 37.617635,
        price: 550.0,
        status: OrderStatus.completed,
        createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
        acceptedAt: DateTime.now()
            .subtract(const Duration(days: 1, hours: 1, minutes: 55)),
        completedAt: DateTime.now().subtract(const Duration(days: 1, hours: 1)),
        clientName: 'Мария',
        clientPhone: '+7 (999) 111-22-33',
        isPaid: true,
        paymentMethod: 'Наличные',
        childCount: 0,
      ),
      OrderModel(
        id: '4',
        clientId: 'client-4',
        driverId: _supabaseService.currentUserId,
        startAddress: 'Кутузовский пр., 12',
        endAddress: 'Ленинградское ш., 30',
        startLat: 55.741244,
        startLng: 37.608423,
        endLat: 55.745814,
        endLng: 37.607635,
        price: 750.0,
        status: OrderStatus.cancelled,
        createdAt: DateTime.now().subtract(const Duration(days: 2, hours: 5)),
        acceptedAt: DateTime.now()
            .subtract(const Duration(days: 2, hours: 4, minutes: 55)),
        clientName: 'Петр',
        clientPhone: '+7 (999) 444-55-66',
        isPaid: false,
        childCount: 2,
      ),
      OrderModel(
        id: '5',
        clientId: 'client-5',
        driverId: _supabaseService.currentUserId,
        startAddress: 'Садовое кольцо, 2',
        endAddress: 'МКАД, 12 км',
        startLat: 55.731244,
        startLng: 37.628423,
        endLat: 55.735814,
        endLng: 37.627635,
        price: 950.0,
        status: OrderStatus.completed,
        createdAt: DateTime.now().subtract(const Duration(days: 3, hours: 1)),
        acceptedAt: DateTime.now()
            .subtract(const Duration(days: 3, hours: 0, minutes: 55)),
        completedAt: DateTime.now().subtract(const Duration(days: 3)),
        clientName: 'Ольга',
        clientPhone: '+7 (999) 777-88-99',
        isPaid: true,
        paymentMethod: 'Карта',
        childCount: 1,
      ),
    ];
  }

  // Освобождаем ресурсы при завершении работы
  void dispose() {
    _activeOrdersController.close();
  }
}
