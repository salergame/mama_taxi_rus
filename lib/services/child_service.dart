import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/child_model.dart';

class ChildService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Получить всех детей пользователя
  Future<List<Child>> getUserChildren(String userId) async {
    try {
      final response = await _supabase
          .from('children')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: true);

      return (response as List).map((data) => Child.fromJson(data)).toList();
    } catch (e) {
      print('Ошибка загрузки детей: $e');
      return [];
    }
  }

  // Добавить ребенка
  Future<Child?> addChild({
    required String userId,
    required String fullName,
    required int age,
    String? school,
    String? photoUrl,
  }) async {
    try {
      final response = await _supabase
          .from('children')
          .insert({
            'user_id': userId,
            'full_name': fullName,
            'age': age,
            'school': school,
            'photo_url': photoUrl,
          })
          .select()
          .single();

      return Child.fromJson(response);
    } catch (e) {
      print('Ошибка добавления ребенка: $e');
      return null;
    }
  }

  // Обновить информацию о ребенке
  Future<Child?> updateChild({
    required String childId,
    String? fullName,
    int? age,
    String? school,
    String? photoUrl,
  }) async {
    try {
      final updateData = <String, dynamic>{};
      if (fullName != null) updateData['full_name'] = fullName;
      if (age != null) updateData['age'] = age;
      if (school != null) updateData['school'] = school;
      if (photoUrl != null) updateData['photo_url'] = photoUrl;

      final response = await _supabase
          .from('children')
          .update(updateData)
          .eq('id', childId)
          .select()
          .single();

      return Child.fromJson(response);
    } catch (e) {
      print('Ошибка обновления ребенка: $e');
      return null;
    }
  }

  // Удалить ребенка
  Future<bool> deleteChild(String childId) async {
    try {
      await _supabase
          .from('children')
          .delete()
          .eq('id', childId);
      return true;
    } catch (e) {
      print('Ошибка удаления ребенка: $e');
      return false;
    }
  }
}
