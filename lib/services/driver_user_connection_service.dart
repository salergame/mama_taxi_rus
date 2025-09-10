import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/driver_user_connection.dart';
import 'supabase_service.dart';

class DriverUserConnectionService {
  final SupabaseService _supabaseService;
  final SupabaseClient _client;

  DriverUserConnectionService({SupabaseService? supabaseService})
      : _supabaseService = supabaseService ?? SupabaseService(),
        _client = Supabase.instance.client;

  // Создать предложение водителю стать постоянным
  Future<DriverUserConnection?> createConnectionRequest({
    required String userId,
    required String driverId,
    required String userFullName,
    required String driverFullName,
    String? userAvatarUrl,
    String? driverAvatarUrl,
    String? userPhone,
    String? driverPhone,
  }) async {
    try {
      // Проверяем, нет ли уже активного запроса между этими пользователями
      final existingConnection = await getConnectionBetweenUsers(userId, driverId);
      if (existingConnection != null && existingConnection.status == ConnectionStatus.pending) {
        return existingConnection;
      }

      final response = await _client.from('driver_user_connections').insert({
        'user_id': userId,
        'driver_id': driverId,
        'user_full_name': userFullName,
        'driver_full_name': driverFullName,
        'user_avatar_url': userAvatarUrl,
        'driver_avatar_url': driverAvatarUrl,
        'user_phone': userPhone,
        'driver_phone': driverPhone,
        'status': ConnectionStatus.pending.name,
        'created_at': DateTime.now().toIso8601String(),
      }).select().single();

      return DriverUserConnection.fromJson(response);
    } catch (e) {
      print('Ошибка создания запроса на подключение: $e');
      return null;
    }
  }

  // Принять предложение водителем
  Future<bool> acceptConnection(String connectionId) async {
    try {
      await _client.from('driver_user_connections').update({
        'status': ConnectionStatus.accepted.name,
        'accepted_at': DateTime.now().toIso8601String(),
      }).eq('id', connectionId);
      
      return true;
    } catch (e) {
      print('Ошибка принятия запроса: $e');
      return false;
    }
  }

  // Отклонить предложение водителем
  Future<bool> rejectConnection(String connectionId, String? reason) async {
    try {
      await _client.from('driver_user_connections').update({
        'status': ConnectionStatus.rejected.name,
        'rejected_at': DateTime.now().toIso8601String(),
        'rejection_reason': reason,
      }).eq('id', connectionId);
      
      return true;
    } catch (e) {
      print('Ошибка отклонения запроса: $e');
      return false;
    }
  }

  // Получить все предложения для водителя
  Future<List<DriverUserConnection>> getConnectionRequestsForDriver(String driverId) async {
    try {
      final response = await _client
          .from('driver_user_connections')
          .select()
          .eq('driver_id', driverId)
          .eq('status', ConnectionStatus.pending.name)
          .order('created_at', ascending: false);

      return response.map<DriverUserConnection>((json) => DriverUserConnection.fromJson(json)).toList();
    } catch (e) {
      print('Ошибка получения запросов для водителя: $e');
      return [];
    }
  }

  // Получить всех закрепленных водителей пользователя
  Future<List<DriverUserConnection>> getUserConnectedDrivers(String userId) async {
    try {
      final response = await _client
          .from('driver_user_connections')
          .select()
          .eq('user_id', userId)
          .eq('status', ConnectionStatus.accepted.name)
          .order('accepted_at', ascending: false);

      return response.map<DriverUserConnection>((json) => DriverUserConnection.fromJson(json)).toList();
    } catch (e) {
      print('Ошибка получения закрепленных водителей: $e');
      return [];
    }
  }

  // Получить всех закрепленных пользователей водителя
  Future<List<DriverUserConnection>> getDriverConnectedUsers(String driverId) async {
    try {
      final response = await _client
          .from('driver_user_connections')
          .select()
          .eq('driver_id', driverId)
          .eq('status', ConnectionStatus.accepted.name)
          .order('accepted_at', ascending: false);

      return response.map<DriverUserConnection>((json) => DriverUserConnection.fromJson(json)).toList();
    } catch (e) {
      print('Ошибка получения закрепленных пользователей: $e');
      return [];
    }
  }

  // Получить связь между конкретными пользователем и водителем
  Future<DriverUserConnection?> getConnectionBetweenUsers(String userId, String driverId) async {
    try {
      final response = await _client
          .from('driver_user_connections')
          .select()
          .eq('user_id', userId)
          .eq('driver_id', driverId)
          .order('created_at', ascending: false)
          .limit(1);

      if (response.isEmpty) return null;
      return DriverUserConnection.fromJson(response.first);
    } catch (e) {
      print('Ошибка получения связи между пользователями: $e');
      return null;
    }
  }

  // Удалить связь (отвязать водителя от пользователя)
  Future<bool> removeConnection(String connectionId) async {
    try {
      await _client.from('driver_user_connections').delete().eq('id', connectionId);
      return true;
    } catch (e) {
      print('Ошибка удаления связи: $e');
      return false;
    }
  }

  // Получить историю всех запросов пользователя
  Future<List<DriverUserConnection>> getUserConnectionHistory(String userId) async {
    try {
      final response = await _client
          .from('driver_user_connections')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return response.map<DriverUserConnection>((json) => DriverUserConnection.fromJson(json)).toList();
    } catch (e) {
      print('Ошибка получения истории запросов: $e');
      return [];
    }
  }

  // Получить историю всех запросов водителя
  Future<List<DriverUserConnection>> getDriverConnectionHistory(String driverId) async {
    try {
      final response = await _client
          .from('driver_user_connections')
          .select()
          .eq('driver_id', driverId)
          .order('created_at', ascending: false);

      return response.map<DriverUserConnection>((json) => DriverUserConnection.fromJson(json)).toList();
    } catch (e) {
      print('Ошибка получения истории запросов водителя: $e');
      return [];
    }
  }
}
