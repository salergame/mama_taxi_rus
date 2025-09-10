import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../services/user_schedule_service.dart';
import '../services/child_service.dart';
import 'package:mama_taxi/services/driver_user_connection_service.dart';
import 'package:mama_taxi/models/driver_user_connection.dart';
import 'package:mama_taxi/services/price_calculator_service.dart';
import 'package:mama_taxi/services/map_service.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';
import 'dart:core';
import '../models/child_model.dart';
import '../models/driver_user_connection.dart';
import '../models/user_schedule_model.dart';
import '../utils/constants.dart';

class UserScheduleScreen extends StatefulWidget {
  const UserScheduleScreen({Key? key}) : super(key: key);

  @override
  State<UserScheduleScreen> createState() => _UserScheduleScreenState();
}

class _UserScheduleScreenState extends State<UserScheduleScreen> {
  // Текущая дата
  late DateTime _selectedDate;
  // Контроллер для списка с датами
  final PageController _pageController = PageController(initialPage: 0);
  // Режим отображения (день, неделя, месяц)
  String _viewMode = 'day';
  // Индикатор загрузки
  bool _isLoading = false;
  // Запланированные поездки
  List<UserScheduledRide> _scheduledRides = [];
  // Данные пользователя
  String? _userAvatarUrl;
  // Закрепленные водители
  List<DriverUserConnection> _connectedDrivers = [];

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _initializeData();
    _subscribeToScheduleUpdates();
  }

  // Инициализация данных
  Future<void> _initializeData() async {
    setState(() => _isLoading = true);

    try {
      // Инициализируем локализацию для правильного отображения дат
      await initializeDateFormatting('ru_RU', null);
      debugPrint('Локализация инициализирована');

      // Загружаем данные пользователя
      await _loadUserProfile();

      // Загружаем закрепленных водителей
      await _loadConnectedDrivers();

      // Получаем данные из сервиса
      await _loadScheduledRides();
      debugPrint('Инициализация завершена');
    } catch (e) {
      debugPrint('Ошибка инициализации: $e');
    }
  }

  // Загрузка данных профиля пользователя
  Future<void> _loadUserProfile() async {
    try {
      final supabaseService = Provider.of<SupabaseService>(context, listen: false);
      final userProfile = await supabaseService.getCurrentUser();
      if (userProfile != null && mounted) {
        setState(() {
          _userAvatarUrl = userProfile.avatarUrl;
        });
      }
    } catch (e) {
      debugPrint('Ошибка загрузки профиля пользователя: $e');
    }
  }

  // Загрузка закрепленных водителей
  Future<void> _loadConnectedDrivers() async {
    try {
      final supabaseService = Provider.of<SupabaseService>(context, listen: false);
      if (!supabaseService.isAuthenticated || supabaseService.currentUserId == null) {
        return;
      }

      final connectionService = DriverUserConnectionService();
      final drivers = await connectionService.getUserConnectedDrivers(supabaseService.currentUserId!);
      
      if (mounted) {
        setState(() {
          _connectedDrivers = drivers;
        });
      }
      debugPrint('Загружено ${drivers.length} закрепленных водителей');
    } catch (e) {
      debugPrint('Ошибка загрузки закрепленных водителей: $e');
    }
  }

  // Загрузка данных из сервиса
  Future<void> _loadScheduledRides() async {
    setState(() => _isLoading = true);
    
    try {
      final userScheduleService =
          Provider.of<UserScheduleService>(context, listen: false);
      final supabaseService = Provider.of<SupabaseService>(context, listen: false);

      // Проверяем аутентификацию
      debugPrint('=== ОТЛАДКА ЗАГРУЗКИ РАСПИСАНИЯ ===');
      debugPrint('Пользователь аутентифицирован: ${supabaseService.isAuthenticated}');
      debugPrint('ID пользователя: ${supabaseService.currentUserId}');
      debugPrint('Режим просмотра: $_viewMode');
      debugPrint('Выбранная дата: $_selectedDate');

      if (!supabaseService.isAuthenticated) {
        debugPrint('ОШИБКА: Пользователь не аутентифицирован');
        setState(() {
          _scheduledRides = [];
        });
        return;
      }

      List<UserScheduledRide> rides;
      
      // Загружаем записи в зависимости от режима просмотра
      switch (_viewMode) {
        case 'day':
          rides = await _getScheduledRidesForDay(_selectedDate);
          break;
        case 'week':
          rides = await _getScheduledRidesForWeek(_selectedDate);
          break;
        case 'month':
          rides = await _getScheduledRidesForMonth(_selectedDate);
          break;
        default:
          rides = await _getScheduledRidesForDay(_selectedDate);
      }

      debugPrint('Получено поездок: ${rides.length}');
      if (rides.isNotEmpty) {
        debugPrint('Первая поездка: ${rides.first.toJson()}');
      }

      setState(() {
        _scheduledRides = rides;
      });
      
      debugPrint('Поездки установлены в состояние: ${_scheduledRides.length}');
    } catch (e, stackTrace) {
      debugPrint('ОШИБКА загрузки расписания: $e');
      debugPrint('Stack trace: $stackTrace');
      // Показываем снэкбар с ошибкой
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки расписания: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Получение расписаний на неделю
  Future<List<UserScheduledRide>> _getScheduledRidesForWeek(DateTime date) async {
    // Находим начало недели (понедельник)
    final startOfWeek = date.subtract(Duration(days: date.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
    
    return await _getScheduledRidesForDateRange(startOfWeek, endOfWeek);
  }

  // Получение расписаний на месяц
  Future<List<UserScheduledRide>> _getScheduledRidesForMonth(DateTime date) async {
    // Находим начало и конец месяца
    final startOfMonth = DateTime(date.year, date.month, 1);
    final endOfMonth = DateTime(date.year, date.month + 1, 0, 23, 59, 59);
    
    return await _getScheduledRidesForDateRange(startOfMonth, endOfMonth);
  }

  // Получение расписаний за день
  Future<List<UserScheduledRide>> _getScheduledRidesForDay(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
    
    return await _getScheduledRidesForDateRange(startOfDay, endOfDay);
  }

  // Получение расписаний за период
  Future<List<UserScheduledRide>> _getScheduledRidesForDateRange(DateTime startDate, DateTime endDate) async {
    final supabaseService = Provider.of<SupabaseService>(context, listen: false);
    
    if (!supabaseService.isAuthenticated) {
      return [];
    }

    try {
      final userId = supabaseService.currentUserId;
      if (userId == null) {
        return [];
      }

      final client = Supabase.instance.client;
      final response = await client
          .from('scheduled_rides')
          .select('*, children!child_id(*)')
          .eq('user_id', userId)
          .gte('scheduled_date', startDate.toIso8601String())
          .lte('scheduled_date', endDate.toIso8601String())
          .order('scheduled_date', ascending: true);

      return (response as List).map((data) {
        // Получаем данные ребенка из связанной таблицы
        final childData = data['children'] as Map<String, dynamic>?;
        String childName = 'Ребенок';
        int childAge = 8;
        String? childPhotoUrl;
        
        if (childData != null) {
          childName = childData['full_name'] ?? 'Ребенок';
          childAge = childData['age'] ?? 8;
          childPhotoUrl = childData['profile_image_url'];
        } else if (data['child_name'] != null && data['child_name'].toString().isNotEmpty) {
          childName = data['child_name'];
          childAge = data['child_age'] ?? 8;
          childPhotoUrl = data['child_photo_url'];
        }
        
        return UserScheduledRide(
          id: data['id'],
          userId: data['user_id'] ?? '',
          driverId: data['driver_id'],
          startAddress: data['start_address'] ?? '',
          endAddress: data['end_address'] ?? '',
          startLat: (data['start_lat'] ?? 0.0).toDouble(),
          startLng: (data['start_lng'] ?? 0.0).toDouble(),
          endLat: (data['end_lat'] ?? 0.0).toDouble(),
          endLng: (data['end_lng'] ?? 0.0).toDouble(),
          price: (data['price'] ?? 0.0).toDouble(),
          scheduledDate: DateTime.parse(data['scheduled_date']),
          status: data['status'] ?? 'scheduled',
          childName: childName,
          childAge: childAge,
          childPhotoUrl: childPhotoUrl,
          driverName: data['driver_name'],
          driverPhotoUrl: data['driver_photo_url'],
          driverRating: data['driver_rating']?.toString(),
        );
      }).toList();
    } catch (e) {
      debugPrint('Ошибка получения расписаний за период: $e');
      return [];
    }
  }

  // Получение ВСЕХ записей из таблицы scheduled_rides
  Future<List<UserScheduledRide>> _getAllScheduledRides() async {
    try {
      final client = Supabase.instance.client;
      debugPrint('Выполняем запрос к таблице scheduled_rides...');
      
      final response = await client
          .from('scheduled_rides')
          .select('*, children!child_id(*)')
          .order('scheduled_date', ascending: true);

      debugPrint('Ответ от базы данных: $response');
      debugPrint('Количество записей: ${(response as List).length}');

      return (response as List).map((data) {
        debugPrint('Данные записи: child_name = ${data['child_name']}, child_age = ${data['child_age']}');
        debugPrint('Связанные данные ребенка: ${data['children']}');
        
        // Получаем данные ребенка из связанной таблицы
        final childData = data['children'] as Map<String, dynamic>?;
        String childName = 'Ребенок';
        int childAge = 8;
        String? childPhotoUrl;
        
        if (childData != null) {
          childName = childData['full_name'] ?? 'Ребенок';
          childAge = childData['age'] ?? 8;
          childPhotoUrl = childData['profile_image_url'];
        } else if (data['child_name'] != null && data['child_name'].toString().isNotEmpty) {
          childName = data['child_name'];
          childAge = data['child_age'] ?? 8;
          childPhotoUrl = data['child_photo_url'];
        }
        
        return UserScheduledRide(
          id: data['id'],
          userId: data['user_id'] ?? '',
          driverId: data['driver_id'],
          startAddress: data['start_address'] ?? '',
          endAddress: data['end_address'] ?? '',
          startLat: (data['start_lat'] ?? 0.0).toDouble(),
          startLng: (data['start_lng'] ?? 0.0).toDouble(),
          endLat: (data['end_lat'] ?? 0.0).toDouble(),
          endLng: (data['end_lng'] ?? 0.0).toDouble(),
          price: (data['price'] ?? 0.0).toDouble(),
          scheduledDate: DateTime.parse(data['scheduled_date']),
          status: data['status'] ?? 'scheduled',
          childName: childName,
          childAge: childAge,
          childPhotoUrl: childPhotoUrl,
          driverName: data['driver_name'],
          driverPhotoUrl: data['driver_photo_url'],
          driverRating: data['driver_rating']?.toString(),
        );
      }).toList();
    } catch (e, stackTrace) {
      debugPrint('ОШИБКА получения всех поездок: $e');
      debugPrint('Stack trace: $stackTrace');
      return [];
    }
  }

  // Подписка на обновления расписания
  void _subscribeToScheduleUpdates() {
    final userScheduleService = Provider.of<UserScheduleService>(context, listen: false);
    userScheduleService.subscribeToScheduledRides();
    
    // Слушаем изменения в стриме
    userScheduleService.scheduledRidesStream.listen((rides) {
      if (mounted) {
        _loadScheduledRides();
      }
    });
  }

  // Обработка смены даты
  void _onDateChanged(DateTime newDate) {
    setState(() {
      _selectedDate = newDate;
    });
    _loadScheduledRides();
  }

  // Обработка изменения режима отображения
  void _onViewModeChanged(String mode) {
    setState(() {
      _viewMode = mode;
    });
    _loadScheduledRides();
  }

  // Переход к предыдущему периоду (день, неделя, месяц)
  void _goToPreviousPeriod() {
    DateTime newDate;
    switch (_viewMode) {
      case 'day':
        newDate = _selectedDate.subtract(const Duration(days: 1));
        break;
      case 'week':
        newDate = _selectedDate.subtract(const Duration(days: 7));
        break;
      case 'month':
        newDate = DateTime(
            _selectedDate.year, _selectedDate.month - 1, _selectedDate.day);
        break;
      default:
        newDate = _selectedDate;
    }
    _onDateChanged(newDate);
  }

  // Переход к следующему периоду (день, неделя, месяц)
  void _goToNextPeriod() {
    DateTime newDate;
    switch (_viewMode) {
      case 'day':
        newDate = _selectedDate.add(const Duration(days: 1));
        break;
      case 'week':
        newDate = _selectedDate.add(const Duration(days: 7));
        break;
      case 'month':
        newDate = DateTime(
            _selectedDate.year, _selectedDate.month + 1, _selectedDate.day);
        break;
      default:
        newDate = _selectedDate;
    }
    _onDateChanged(newDate);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.05),
        title: Row(
          children: [
            Icon(Icons.calendar_today, size: 18, color: Colors.black),
            const SizedBox(width: 10),
            Text(
              'Расписание',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: Colors.black,
              ),
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.grey[300],
              ),
              child: _userAvatarUrl != null && _userAvatarUrl!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        _userAvatarUrl!,
                        fit: BoxFit.cover,
                        width: 32,
                        height: 32,
                        errorBuilder: (context, error, stackTrace) {
                          debugPrint('Ошибка загрузки аватарки в расписании: $error');
                          return const Icon(
                            Icons.person,
                            size: 18,
                            color: Colors.grey,
                          );
                        },
                      ),
                    )
                  : const Icon(
                      Icons.person,
                      size: 18,
                      color: Colors.grey,
                    ),
            ),
          ),
        ],
      ),
      body: Column(
              children: [
                // Секция выбора месяца и стрелок навигации
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat('MMMM yyyy', 'ru').format(_selectedDate),
                            style: const TextStyle(
                              fontFamily: 'Rubik',
                              fontSize: 18,
                              fontWeight: FontWeight.w400,
                              color: Colors.black,
                            ),
                          ),
                          Row(
                            children: [
                              InkWell(
                                onTap: _goToPreviousPeriod,
                                child: Container(
                                  width: 26,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(9999),
                                  ),
                                  child: Icon(Icons.chevron_left,
                                      color: Colors.black),
                                ),
                              ),
                              InkWell(
                                onTap: _goToNextPeriod,
                                child: Container(
                                  width: 26,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(9999),
                                  ),
                                  child: Icon(Icons.chevron_right,
                                      color: Colors.black),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Кнопки выбора режима отображения
                      Row(
                        children: [
                          _buildViewModeButton('day', 'День'),
                          const SizedBox(width: 12),
                          _buildViewModeButton('week', 'Неделя'),
                          const SizedBox(width: 12),
                          _buildViewModeButton('month', 'Месяц'),
                        ],
                      ),
                    ],
                  ),
                ),

                // Заголовок с количеством поездок
                Padding(
                  padding: const EdgeInsets.only(left: 16, top: 20, bottom: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _getScheduleTitle(),
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      if (_scheduledRides.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFED56AE).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_scheduledRides.length}',
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFFED56AE),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Отображение текущего периода
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        _getSelectedPeriodText(),
                        style: TextStyle(
                          fontFamily: 'Rubik',
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),

                // Список запланированных поездок
                Expanded(
                  child: _isLoading
                      ? Center(child: CircularProgressIndicator())
                      : _scheduledRides.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.calendar_today_outlined,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _getEmptyStateMessage(),
                                    style: TextStyle(
                                      fontFamily: 'Roboto',
                                      fontSize: 16,
                                      color: Colors.black54,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Отладка: ${_scheduledRides.length} поездок',
                                    style: TextStyle(
                                      fontFamily: 'Roboto',
                                      fontSize: 12,
                                      color: Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _scheduledRides.length,
                          itemBuilder: (context, index) {
                            return _buildScheduledRideCard(
                                _scheduledRides[index]);
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddRideDialog(),
        backgroundColor: const Color(0xFFA5C572),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // Проверяет, выбрана ли текущая дата
  bool _isTodaySelected() {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  // Получает текст для отображения выбранного периода
  String _getSelectedPeriodText() {
    switch (_viewMode) {
      case 'day':
        return _isTodaySelected()
            ? 'Сегодня, ${DateFormat('dd MMMM', 'ru').format(_selectedDate)}'
            : DateFormat('dd MMMM', 'ru').format(_selectedDate);
      case 'week':
        final startOfWeek = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        return '${DateFormat('dd', 'ru').format(startOfWeek)} - ${DateFormat('dd MMMM', 'ru').format(endOfWeek)}';
      case 'month':
        return DateFormat('MMMM yyyy', 'ru').format(_selectedDate);
      default:
        return DateFormat('dd MMMM', 'ru').format(_selectedDate);
    }
  }

  // Получает заголовок для расписания в зависимости от режима
  String _getScheduleTitle() {
    switch (_viewMode) {
      case 'day':
        return 'Поездки на день';
      case 'week':
        return 'Поездки на неделю';
      case 'month':
        return 'Поездки на месяц';
      default:
        return 'Предстоящие поездки';
    }
  }

  // Получает сообщение для пустого состояния
  String _getEmptyStateMessage() {
    switch (_viewMode) {
      case 'day':
        return _isTodaySelected() 
            ? 'Нет поездок на сегодня'
            : 'Нет поездок на выбранный день';
      case 'week':
        return 'Нет поездок на эту неделю';
      case 'month':
        return 'Нет поездок в этом месяце';
      default:
        return 'Нет запланированных поездок';
    }
  }

  // Создает кнопку выбора режима отображения
  Widget _buildViewModeButton(String mode, String title) {
    final isSelected = _viewMode == mode;

    return InkWell(
      onTap: () => _onViewModeChanged(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF654AA) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(9999),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontFamily: 'Rubik',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: isSelected ? Colors.white : const Color(0xFF4B5563),
          ),
        ),
      ),
    );
  }

  // Создает карточку запланированной поездки
  Widget _buildScheduledRideCard(UserScheduledRide ride) {
    return Container(
      width: 358,
      height: 242,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Шапка карточки с информацией о сервисе и цене
            SizedBox(
              width: 326,
              height: 44,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Верхняя строка с иконкой такси, названием и ценой
                  SizedBox(
                    height: 20,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 18,
                              height: 16,
                              child: Icon(Icons.local_taxi, size: 16, color: Colors.black),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Мама такси',
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.black,
                                height: 1.0,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '₽${ride.price.toInt()}',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF6B8E23),
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Время и дата
                  Text(
                    ride.formattedDateTime,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF4B5563),
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Информация о ребенке
            SizedBox(
              width: 326,
              height: 40,
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.grey[200],
                    ),
                    child: ride.childPhotoUrl != null && ride.childPhotoUrl!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              ride.childPhotoUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(Icons.child_care, size: 20, color: Colors.grey[600]);
                              },
                            ),
                          )
                        : Icon(Icons.child_care, size: 20, color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        (ride.childName != null && ride.childName!.isNotEmpty) 
                            ? ride.childName! 
                            : 'Ребенок',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 13.5,
                            height: 12,
                            child: Icon(Icons.cake, size: 12, color: Colors.black54),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${ride.childAge ?? 8} лет',
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF4B5563),
                              height: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Адреса начала и конца поездки
            SizedBox(
              width: 326,
              height: 48,
              child: Column(
                children: [
                  // Начальный адрес
                  SizedBox(
                    height: 20,
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          child: Icon(Icons.circle_outlined, size: 12, color: Colors.black),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            ride.startAddress,
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: Colors.black,
                              height: 1.0,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Конечный адрес
                  SizedBox(
                    height: 20,
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 16,
                          child: Icon(Icons.location_on_outlined, size: 12, color: Colors.black),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            ride.endAddress,
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: Colors.black,
                              height: 1.0,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Кнопки действий
            SizedBox(
              width: 326,
              height: 38,
              child: Row(
                children: [
                  // Кнопка "Изменить"
                  Container(
                    width: 160,
                    height: 38,
                    child: OutlinedButton(
                      onPressed: () {
                        _showEditRideDialog(ride);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFF654AA),
                        side: const BorderSide(color: Color(0xFFF654AA), width: 1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      child: Text(
                        'Изменить',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFFF654AA),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Кнопка "Отследить"
                  Container(
                    width: 158,
                    height: 38,
                    child: ElevatedButton(
                      onPressed: () => _trackRide(ride),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF654AA),
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        'Отследить',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Переход на страницу добавления новой поездки
  void _showAddRideDialog() {
    Navigator.of(context).pushNamed('/add_schedule').then((_) {
      // Обновляем список поездок после возврата со страницы добавления
      _loadScheduledRides();
    });
  }

  // Показывает диалог редактирования поездки
  void _showEditRideDialog(UserScheduledRide ride) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Редактирование поездки',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Откуда: ${ride.startAddress}',
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Куда: ${ride.endAddress}',
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Время: ${ride.formattedDateTime}',
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Цена: ₽${ride.price.toInt()}',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 14,
                  color: Color(0xFF6B8E23),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Отменить',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: Colors.grey[600],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                // Здесь можно добавить логику редактирования
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Функция редактирования будет доступна в следующих версиях'),
                    backgroundColor: Colors.orange,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF654AA),
                foregroundColor: Colors.white,
              ),
              child: const Text(
                'Сохранить',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Метод для отслеживания поездки (построение маршрута)
  void _trackRide(UserScheduledRide ride) {
    // Переходим на карту с построением маршрута
    Navigator.of(context).pushNamed(
      '/map',
      arguments: {
        'startAddress': ride.startAddress,
        'endAddress': ride.endAddress,
        'buildRoute': true,
      },
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}
