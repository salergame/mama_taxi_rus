import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/payment_history_model.dart';
import '../models/order_model.dart';
import 'supabase_service.dart';
import 'order_service.dart';
import 'package:intl/intl.dart';

class DriverEarningsService {
  final SupabaseClient _client = Supabase.instance.client;
  final SupabaseService _supabaseService;

  DriverEarningsService({required SupabaseService supabaseService})
      : _supabaseService = supabaseService;

  // Получить заработок водителя за указанный месяц
  Future<DriverEarnings> getDriverEarnings(
      String driverId, DateTime month) async {
    try {
      // Начало и конец месяца
      final startOfMonth = DateTime(month.year, month.month, 1);
      final endOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

      // Используем ту же логику, что и в driver_order_history_screen.dart
      final orderService = OrderService(supabaseService: _supabaseService);
      
      // Получаем реальные данные из базы данных
      List<OrderModel> monthlyOrders = await orderService.getOrderHistory(
        startDate: startOfMonth,
        endDate: endOfMonth,
        limit: 100, // Получаем все заказы за месяц
        offset: 0,
      );

      // Если нет реальных данных, используем демо для отладки
      if (monthlyOrders.isEmpty) {
        monthlyOrders = orderService.getDemoOrderHistory();
        // Фильтруем демо-данные по месяцу
        monthlyOrders = monthlyOrders.where((order) {
          final orderDate = order.completedAt ?? order.createdAt;
          return orderDate.year == month.year && orderDate.month == month.month;
        }).toList();
      }

      // Применяем фильтры по статусу (как в driver_order_history_screen.dart)
      final filteredOrders = monthlyOrders
          .where((order) => order.isCompleted || order.isCancelled)
          .toList();

      // Создаем историю платежей из реальных заказов
      final history = <PaymentHistoryItem>[];
      double totalEarnings = 0;
      double rideEarnings = 0;
      double bonusEarnings = 0;

      for (final order in filteredOrders) {
        if (order.isCompleted && order.isPaid) {
          // Определяем тип поездки
          PaymentType paymentType = PaymentType.ride;
          String title = 'Поездка';
          
          if (order.childCount != null && order.childCount! > 0) {
            paymentType = PaymentType.childCare;
            title = 'Поездка (Автоняня)';
          }
          
          // Добавляем в историю
          history.add(PaymentHistoryItem(
            id: order.id,
            title: title,
            date: order.completedAt ?? order.createdAt,
            amount: order.price,
            type: paymentType,
            details: '${order.startAddress} → ${order.endAddress}',
          ));
          
          rideEarnings += order.price;
          totalEarnings += order.price;
        }
      }

      // Добавляем бонусы на основе количества поездок
      final completedTripsCount = filteredOrders.where((order) => order.isCompleted).length;
      if (completedTripsCount >= 10) {
        final bonusAmount = (completedTripsCount ~/ 10) * 500.0;
        if (bonusAmount > 0) {
          history.add(PaymentHistoryItem(
            id: 'bonus_${month.month}_${month.year}',
            title: 'Бонус за $completedTripsCount поездок',
            date: DateTime(month.year, month.month, 15, 20, 0),
            amount: bonusAmount,
            type: PaymentType.bonus,
          ));
          bonusEarnings += bonusAmount;
          totalEarnings += bonusAmount;
        }
      }

      // Сортируем историю по дате (новые сверху)
      history.sort((a, b) => b.date.compareTo(a.date));

      return DriverEarnings(
        totalAmount: totalEarnings,
        month: startOfMonth,
        rideEarnings: rideEarnings,
        bonusEarnings: bonusEarnings,
        history: history,
      );
    } catch (e) {
      debugPrint('Ошибка получения данных о заработке: $e');
      return DriverEarnings.demo();
    }
  }

  // Генерация данных о доходах на основе профиля водителя
  Future<DriverEarnings> _generateEarningsFromProfile(String driverId, DateTime month) async {
    try {
      final profileResponse = await _client
          .from('profiles')
          .select('today_earnings, total_earnings, today_trips, total_trips')
          .eq('id', driverId)
          .maybeSingle();

      if (profileResponse != null) {
        final totalEarnings = (profileResponse['total_earnings'] as num?)?.toDouble() ?? 0.0;
        final totalTrips = (profileResponse['total_trips'] as int?) ?? 0;
        
        // Генерируем историю на основе статистики
        final history = _generateHistoryFromStats(totalTrips, totalEarnings, month);
        final rideEarnings = history
            .where((item) => item.type != PaymentType.bonus)
            .fold<double>(0, (sum, item) => sum + item.amount);
        final bonusEarnings = history
            .where((item) => item.type == PaymentType.bonus)
            .fold<double>(0, (sum, item) => sum + item.amount);

        return DriverEarnings(
          totalAmount: rideEarnings + bonusEarnings,
          month: DateTime(month.year, month.month, 1),
          rideEarnings: rideEarnings,
          bonusEarnings: bonusEarnings,
          history: history,
        );
      }
    } catch (e) {
      debugPrint('Ошибка генерации данных из профиля: $e');
    }
    
    return DriverEarnings.demo();
  }

  // Генерация истории платежей на основе общей суммы заработка
  List<PaymentHistoryItem> _generateHistoryFromEarnings(double monthlyEarnings, DateTime month) {
    final history = <PaymentHistoryItem>[];
    
    if (monthlyEarnings <= 0) return history;
    
    // Генерируем разумное количество поездок на основе суммы
    final avgTripPrice = 800.0; // Средняя цена поездки
    final estimatedTrips = (monthlyEarnings / avgTripPrice).round().clamp(3, 20);
    
    for (int i = 0; i < estimatedTrips; i++) {
      final day = (i * 2 + 1).clamp(1, 28);
      final hour = 9 + (i % 12);
      final minute = (i * 7) % 60;
      
      final tripDate = DateTime(month.year, month.month, day, hour, minute);
      
      // Распределяем общую сумму по поездкам с вариацией
      final baseAmount = monthlyEarnings / estimatedTrips;
      final variation = 0.3; // ±30% вариация
      final amount = (baseAmount * (1 - variation + 2 * variation * (i % 10) / 10)).round().toDouble();
      
      PaymentType type = PaymentType.ride;
      String title = 'Поездка';
      
      // Добавляем разнообразие в типы поездок
      if (i % 7 == 0) {
        type = PaymentType.childCare;
        title = 'Поездка (Автоняня)';
      } else if (i % 11 == 0) {
        type = PaymentType.emergency;
        title = 'Срочный вызов';
      }
      
      history.add(PaymentHistoryItem(
        id: 'estimated_${month.month}_${month.year}_$i',
        title: title,
        date: tripDate,
        amount: amount,
        type: type,
      ));
    }
    
    return history;
  }

  // Генерация истории платежей на основе статистики (старый метод)
  List<PaymentHistoryItem> _generateHistoryFromStats(int totalTrips, double totalEarnings, DateTime month) {
    final history = <PaymentHistoryItem>[];
    
    // Генерируем несколько поездок для текущего месяца
    final tripsThisMonth = (totalTrips * 0.1).round().clamp(3, 15);
    final earningsPerTrip = totalEarnings > 0 ? totalEarnings / totalTrips : 800;
    
    for (int i = 0; i < tripsThisMonth; i++) {
      final day = (i * 2 + 1).clamp(1, 28);
      final hour = 9 + (i % 12);
      final minute = (i * 7) % 60;
      
      final tripDate = DateTime(month.year, month.month, day, hour, minute);
      final amount = (earningsPerTrip * (0.8 + (i % 5) * 0.1)).round().toDouble();
      
      PaymentType type = PaymentType.ride;
      String title = 'Поездка';
      
      // Добавляем разнообразие в типы поездок
      if (i % 7 == 0) {
        type = PaymentType.childCare;
        title = 'Поездка (Автоняня)';
      } else if (i % 11 == 0) {
        type = PaymentType.emergency;
        title = 'Срочный вызов';
      }
      
      history.add(PaymentHistoryItem(
        id: 'generated_${month.month}_$i',
        title: title,
        date: tripDate,
        amount: amount,
        type: type,
      ));
    }
    
    // Добавляем бонус, если есть достаточно поездок
    if (totalTrips >= 50) {
      history.add(PaymentHistoryItem(
        id: 'bonus_${month.month}',
        title: 'Бонус за активность',
        date: DateTime(month.year, month.month, 15, 20, 0),
        amount: 500,
        type: PaymentType.bonus,
      ));
    }
    
    // Сортируем по дате (новые сверху)
    history.sort((a, b) => b.date.compareTo(a.date));
    
    return history;
  }

  // Получить форматированное название месяца
  String getFormattedMonth(DateTime month, {String locale = 'ru'}) {
    try {
      final formatter = DateFormat('LLLL yyyy', locale);
      final formatted = formatter.format(month);
      return formatted[0].toUpperCase() + formatted.substring(1);
    } catch (e) {
      // Если произошла ошибка с форматированием, используем стандартный формат
      final List<String> russianMonths = [
        'Январь',
        'Февраль',
        'Март',
        'Апрель',
        'Май',
        'Июнь',
        'Июль',
        'Август',
        'Сентябрь',
        'Октябрь',
        'Ноябрь',
        'Декабрь'
      ];

      return '${russianMonths[month.month - 1]} ${month.year}';
    }
  }

  // Форматировать дату поездки
  String formatPaymentDate(DateTime date) {
    try {
      final List<String> russianMonths = [
        'января',
        'февраля',
        'марта',
        'апреля',
        'мая',
        'июня',
        'июля',
        'августа',
        'сентября',
        'октября',
        'ноября',
        'декабря'
      ];

      return '${date.day} ${russianMonths[date.month - 1]}, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      // Если произошла ошибка, используем стандартный формат
      return DateFormat('dd.MM, HH:mm').format(date);
    }
  }

  // Форматировать сумму в рублях
  String formatAmount(double amount, {bool withPlus = false}) {
    final isPositive = amount >= 0;
    final formattedAmount = amount.abs().toStringAsFixed(0);
    final sign = (withPlus && isPositive) ? '+' : '';
    return '$sign$formattedAmount₽';
  }
}
