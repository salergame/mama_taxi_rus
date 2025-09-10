import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/constants.dart';
import '../services/supabase_service.dart';
import '../models/user_model.dart';
import '../models/driver_model.dart';
import '../models/order_model.dart';
import '../services/order_service.dart';
import 'edit_profile_screen.dart';
import 'driver_loyalty_screen.dart';
import 'support_screen.dart';
import 'driver_earnings_screen.dart';
import 'driver_verification_screen.dart';
import 'driver_order_history_screen.dart';
import 'order_details_screen.dart';

class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final OrderService _orderService = OrderService(supabaseService: SupabaseService());
  UserModel? _driverProfile;
  bool _isLoading = true;
  bool _isOnline = false;
  
  // Статистика водителя
  double _todayEarnings = 0.0;
  int _todayTrips = 0;
  double _totalEarnings = 0.0;
  int _totalTrips = 0;
  double _rating = 0.0;
  
  // Подписка на изменения статуса
  StreamSubscription<bool>? _statusSubscription;

  @override
  void initState() {
    super.initState();
    _loadDriverProfile();
    _loadDriverStatus();
    _initializeAndLoadStatistics();

    // Подписываемся на изменения статуса
    _statusSubscription =
        _supabaseService.driverStatusStream.listen((isOnline) {
      debugPrint('DriverProfileScreen: Получено обновление статуса: $isOnline');
      if (mounted) {
        setState(() {
          _isOnline = isOnline;
        });
      }
    });
  }

  @override
  void dispose() {
    // Отписываемся при уничтожении экрана
    _statusSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadDriverProfile() async {
    try {
      final driver = await _supabaseService.getCurrentUser();
      setState(() {
        _driverProfile = driver;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Ошибка загрузки профиля водителя: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Загрузка статуса водителя
  Future<void> _loadDriverStatus() async {
    try {
      final isOnline = await _supabaseService.getDriverOnlineStatus();
      if (mounted) {
        setState(() {
          _isOnline = isOnline;
        });
      }
    } catch (e) {
      debugPrint('Ошибка загрузки статуса водителя: $e');
    }
  }
  
  // Инициализация и загрузка статистики водителя
  Future<void> _initializeAndLoadStatistics() async {
    try {
      if (_supabaseService.currentUserId == null) {
        debugPrint('❌ Нет ID пользователя для загрузки статистики');
        return;
      }
      
      debugPrint('📈 Загружаем статистику для водителя ${_supabaseService.currentUserId}');
      
      // Загружаем статистику из таблицы profiles
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('today_earnings, today_trips, total_earnings, total_trips, last_trip_date')
          .eq('id', _supabaseService.currentUserId!)
          .maybeSingle();
      
      if (mounted && profile != null) {
        final today = DateTime.now();
        final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
        final lastTripDate = profile['last_trip_date'];
        
        // Если последняя поездка была не сегодня, обнуляем статистику за сегодня
        if (lastTripDate != todayStr) {
          await Supabase.instance.client
              .from('profiles')
              .update({
                'today_earnings': 0.0,
                'today_trips': 0,
              })
              .eq('id', _supabaseService.currentUserId!);
          
          setState(() {
            _todayEarnings = 0.0;
            _todayTrips = 0;
            _totalEarnings = profile['total_earnings']?.toDouble() ?? 0.0;
            _totalTrips = profile['total_trips'] ?? 0;
            _rating = 5.0;
          });
        } else {
          setState(() {
            _todayEarnings = profile['today_earnings']?.toDouble() ?? 0.0;
            _todayTrips = profile['today_trips'] ?? 0;
            _totalEarnings = profile['total_earnings']?.toDouble() ?? 0.0;
            _totalTrips = profile['total_trips'] ?? 0;
            _rating = 5.0;
          });
        }
        
        debugPrint('✅ Статистика загружена: ${_todayTrips} поездок, ${_todayEarnings}₽ за сегодня');
      } else {
        debugPrint('❌ Профиль водителя не найден, устанавливаем нулевые значения');
        setState(() {
          _todayEarnings = 0.0;
          _todayTrips = 0;
          _totalEarnings = 0.0;
          _totalTrips = 0;
          _rating = 5.0;
        });
      }
    } catch (e) {
      debugPrint('❌ Ошибка загрузки статистики: $e');
      setState(() {
        _todayEarnings = 0.0;
        _todayTrips = 0;
        _totalEarnings = 0.0;
        _totalTrips = 0;
        _rating = 5.0;
      });
    }
  }
  
  // Обновление фото профиля
  Future<void> _updateProfilePhoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      
      if (image != null) {
        setState(() {
          _isLoading = true;
        });
        
        final File imageFile = File(image.path);
        final String? avatarUrl = await _supabaseService.uploadProfilePhoto(imageFile);
        
        if (avatarUrl != null) {
          // Обновляем профиль с новым URL аватара
          if (_driverProfile != null) {
            final updatedProfile = UserModel(
              id: _driverProfile!.id,
              fullName: _driverProfile!.fullName,
              phone: _driverProfile!.phone,
              avatarUrl: avatarUrl,
              role: _driverProfile!.role,
              birthDate: _driverProfile!.birthDate,
              gender: _driverProfile!.gender,
              city: _driverProfile!.city,
            );
            
            try {
              await _supabaseService.updateUserProfile(updatedProfile);
              // Перезагружаем профиль
              await _loadDriverProfile();
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Фото профиля обновлено'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            } catch (updateError) {
              debugPrint('Ошибка обновления профиля: $updateError');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Ошибка обновления профиля: $updateError'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Ошибка обновления фото профиля: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Обновление статуса водителя
  Future<void> _updateDriverStatus(bool isOnline) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _supabaseService.updateDriverOnlineStatus(isOnline);
      if (success) {
        setState(() {
          _isOnline = isOnline;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isOnline ? 'Вы теперь онлайн' : 'Вы теперь офлайн',
            ),
            backgroundColor: isOnline ? const Color(0xFFA5C572) : Colors.grey,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось обновить статус'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Ошибка обновления статуса водителя: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Личный кабинет',
          style: TextStyle(
            color: Colors.black,
            fontFamily: 'Manrope',
            fontSize: 18,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Профиль водителя
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(top: 16),
                    color: Colors.white,
                    child: Row(
                      children: [
                        // Аватар водителя с возможностью изменения
                        GestureDetector(
                          onTap: _updateProfilePhoto,
                          child: Stack(
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.grey[200],
                                  image: _driverProfile?.avatarUrl != null
                                      ? DecorationImage(
                                          image: NetworkImage(
                                            _driverProfile!.avatarUrl!,
                                          ),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: _driverProfile?.avatarUrl == null
                                    ? const Icon(
                                        Icons.person,
                                        size: 40,
                                        color: Colors.grey,
                                      )
                                    : null,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFFF654AA),
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _driverProfile?.fullName ?? 'Имя не указано',
                              style: const TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 18,
                                fontWeight: FontWeight.w400,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.star,
                                  size: 16,
                                  color: Colors.amber,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _rating.toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontFamily: 'Manrope',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _driverProfile?.phone ?? 'Телефон не указан',
                              style: const TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () {
                            // Редактирование профиля
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditProfileScreen(
                                  userProfile: _driverProfile,
                                ),
                              ),
                            ).then((result) {
                              // Если профиль был обновлен, перезагружаем данные
                              if (result == true) {
                                _loadDriverProfile();
                              }
                            });
                          },
                          icon: const Icon(Icons.arrow_forward_ios, size: 16),
                        ),
                      ],
                    ),
                  ),

                  // Статус онлайн/офлайн
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 16),
                    padding: const EdgeInsets.all(16),
                    color: Colors.white,
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Статус',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                            Text(
                              _isOnline ? 'Онлайн' : 'Офлайн',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        // Переключатель онлайн/офлайн
                        Switch(
                          value: _isOnline,
                          onChanged: (value) {
                            _updateDriverStatus(value);
                          },
                          activeColor: Colors.white,
                          activeTrackColor: const Color(0xFFA5C572),
                          inactiveThumbColor: Colors.white,
                          inactiveTrackColor: Colors.grey,
                        ),
                      ],
                    ),
                  ),

                  // Статистика
                  Container(
                    margin: const EdgeInsets.only(top: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        // Заработок
                        Expanded(
                          child: Container(
                            height: 112,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Заработок',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w400,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                                const Text(
                                  'сегодня',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w400,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${_todayEarnings.toStringAsFixed(0)}₽',
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Поездки
                        Expanded(
                          child: Container(
                            height: 112,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Поездок сегодня',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w400,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  _todayTrips.toString(),
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Меню
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 16),
                    color: Colors.white,
                    child: Column(
                      children: [
                        _buildMenuItem(
                          'История заказов',
                          Icons.history,
                          onTap: () {
                            _showOrderHistory();
                          },
                        ),
                        _buildMenuItem(
                          'График работы',
                          Icons.calendar_today,
                          onTap: () {
                            _showWorkSchedule();
                          },
                        ),
                        _buildMenuItem(
                          'Доходы и выплаты',
                          Icons.monetization_on,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const DriverEarningsScreen(),
                              ),
                            );
                          },
                        ),
                        _buildMenuItem(
                          'Программа лояльности',
                          Icons.card_giftcard,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const DriverLoyaltyScreen(),
                              ),
                            );
                          },
                        ),
                        _buildMenuItem(
                          'Настройки',
                          Icons.settings,
                          onTap: () {
                            _showSettings();
                          },
                        ),
                        _buildMenuItem(
                          'Поддержка',
                          Icons.help,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SupportScreen(),
                              ),
                            );
                          },
                        ),
                        _buildMenuItem(
                          'Документы и верификация',
                          Icons.badge_outlined,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const DriverVerificationScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
  
  // Загрузка данных истории заказов
  Future<List<OrderModel>> _loadOrderHistoryData() async {
    try {
      // Сначала пытаемся получить реальные данные
      final realOrders = await _orderService.getOrderHistory(limit: 10);
      
      // Если есть реальные данные, возвращаем их
      if (realOrders.isNotEmpty) {
        return realOrders;
      }
      
      // Если нет реальных данных, возвращаем демо-данные для отладки
      return _orderService.getDemoOrderHistory();
    } catch (e) {
      debugPrint('Ошибка загрузки истории заказов: $e');
      // В случае ошибки возвращаем демо-данные
      return _orderService.getDemoOrderHistory();
    }
  }
  
  // Показать историю заказов
  void _showOrderHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text(
                    'История заказов',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context); // Закрыть модальное окно
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DriverOrderHistoryScreen(),
                        ),
                      );
                    },
                    child: const Text('Показать все', style: TextStyle(color: Color(0xFFA5C572))),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<OrderModel>>(
                future: _loadOrderHistoryData(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                      child: Text('Нет завершенных заказов'),
                    );
                  }
                  
                  final orders = snapshot.data!;
                  return ListView.builder(
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      return ListTile(
                        onTap: () {
                          Navigator.pop(context); // Закрыть bottom sheet
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => OrderDetailsScreen(order: order),
                            ),
                          );
                        },
                        leading: CircleAvatar(
                          backgroundColor: order.statusColor,
                          child: Icon(
                            order.statusIcon,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        title: Text('Заказ #${order.id.length >= 8 ? order.id.substring(0, 8) : order.id}'),
                        subtitle: Text(order.formattedCompletedAt ?? order.formattedCreatedAt),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${order.price.toStringAsFixed(0)}₽',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_ios, size: 16),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Показать график работы
  void _showWorkSchedule() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('График работы'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Текущий график:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildScheduleItem('Понедельник', '08:00 - 20:00'),
            _buildScheduleItem('Вторник', '08:00 - 20:00'),
            _buildScheduleItem('Среда', '08:00 - 20:00'),
            _buildScheduleItem('Четверг', '08:00 - 20:00'),
            _buildScheduleItem('Пятница', '08:00 - 22:00'),
            _buildScheduleItem('Суббота', '10:00 - 22:00'),
            _buildScheduleItem('Воскресенье', 'Выходной'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть', style: TextStyle(color: Color(0xFFA5C572))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Функция изменения графика будет доступна в следующем обновлении'),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFA5C572),
              foregroundColor: Colors.white,
            ),
            child: const Text('Изменить'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildScheduleItem(String day, String time) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(day),
          Text(time, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
  
  // Показать настройки
  void _showSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text(
                    'Настройки',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  _buildSettingItem(
                    'Уведомления',
                    'Получать push-уведомления о новых заказах',
                    Icons.notifications,
                    true,
                  ),
                  _buildSettingItem(
                    'Звук уведомлений',
                    'Звуковые сигналы при получении заказов',
                    Icons.volume_up,
                    true,
                  ),
                  _buildSettingItem(
                    'Автоприем заказов',
                    'Автоматически принимать подходящие заказы',
                    Icons.auto_awesome,
                    false,
                  ),
                  _buildSettingItem(
                    'Режим экономии батареи',
                    'Снизить частоту обновления GPS',
                    Icons.battery_saver,
                    false,
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text(
                      'Выйти из аккаунта',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () {
                      _showLogoutDialog();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSettingItem(String title, String subtitle, IconData icon, bool value) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Switch(
        value: value,
        onChanged: (newValue) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$title ${newValue ? "включен" : "выключен"}'),
            ),
          );
        },
        activeColor: Colors.white,
        activeTrackColor: const Color(0xFFA5C572),
        inactiveThumbColor: Colors.white,
        inactiveTrackColor: Colors.grey,
      ),
    );
  }
  
  // Диалог выхода из аккаунта
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выход из аккаунта'),
        content: const Text('Вы уверены, что хотите выйти из аккаунта?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Закрыть диалог
              Navigator.pop(context); // Закрыть настройки
              
              // Выполнить выход
              await _supabaseService.signOut();
              
              if (mounted) {
                // Вернуться на экран входа
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/login',
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(String title, IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: const BoxDecoration(
          border:
              Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: Colors.black),
            const SizedBox(width: 16),
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: Colors.black,
              ),
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios, size: 10, color: Colors.black),
          ],
        ),
      ),
    );
  }
}

// Упрощенные методы для работы со статистикой в таблице profiles
extension DriverStatistics on SupabaseService {
  Future<String?> uploadProfilePhoto(File imageFile) async {
    try {
      if (!isAuthenticated || currentUserId == null) return null;
      
      final fileName = 'profile_${currentUserId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      await Supabase.instance.client.storage
          .from('avatars')
          .upload(fileName, imageFile);
      
      final publicUrl = Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(fileName);
      
      return publicUrl;
    } catch (e) {
      debugPrint('Ошибка загрузки фото профиля: $e');
      return null;
    }
  }
}
