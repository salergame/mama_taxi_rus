import 'package:flutter/foundation.dart';
import 'supabase_service.dart';

class LoyaltyService {
  static final LoyaltyService _instance = LoyaltyService._internal();
  factory LoyaltyService() => _instance;
  LoyaltyService._internal();

  final SupabaseService _supabaseService = SupabaseService();

  // Начислить баллы за завершенную поездку
  Future<bool> awardTripPoints() async {
    try {
      final success = await _supabaseService.addLoyaltyPoints(
        points: 15,
        description: 'Завершенная поездка',
      );
      
      if (success) {
        debugPrint('Начислено 15 баллов за поездку');
      }
      
      return success;
    } catch (e) {
      debugPrint('Ошибка начисления баллов за поездку: $e');
      return false;
    }
  }

  // Начислить баллы за высокий рейтинг (вызывается еженедельно)
  Future<bool> awardRatingPoints(double rating) async {
    if (rating < 4.8) return false;
    
    try {
      final success = await _supabaseService.addLoyaltyPoints(
        points: 50,
        description: 'Высокий рейтинг ($rating)',
      );
      
      if (success) {
        debugPrint('Начислено 50 баллов за высокий рейтинг');
      }
      
      return success;
    } catch (e) {
      debugPrint('Ошибка начисления баллов за рейтинг: $e');
      return false;
    }
  }

  // Начислить баллы за работу в пиковые часы
  Future<bool> awardPeakHourPoints() async {
    try {
      final success = await _supabaseService.addLoyaltyPoints(
        points: 20,
        description: 'Работа в пиковые часы',
      );
      
      if (success) {
        debugPrint('Начислено 20 баллов за пиковые часы');
      }
      
      return success;
    } catch (e) {
      debugPrint('Ошибка начисления баллов за пиковые часы: $e');
      return false;
    }
  }

  // Проверить, является ли текущее время пиковым
  bool isPeakHour() {
    final now = DateTime.now();
    final hour = now.hour;
    
    // Утренний пик: 7:00-10:00
    // Вечерний пик: 17:00-20:00
    return (hour >= 7 && hour <= 10) || (hour >= 17 && hour <= 20);
  }

  // Получить множитель комиссии на основе уровня лояльности
  double getCommissionMultiplier(int loyaltyLevel) {
    switch (loyaltyLevel) {
      case 0:
        return 1.0; // Базовая комиссия
      case 1:
        return 0.95; // -5%
      case 2:
        return 0.90; // -10%
      case 3:
        return 0.85; // -15% (максимальная скидка)
      default:
        return 1.0;
    }
  }

  // Проверить, имеет ли водитель приоритет в заказах
  bool hasPriorityAccess(int loyaltyLevel) {
    return loyaltyLevel >= 3; // Приоритет с 3 уровня
  }
}
