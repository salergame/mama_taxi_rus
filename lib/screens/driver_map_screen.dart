import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:typed_data';
import 'dart:math';
import 'package:permission_handler/permission_handler.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart'
    show
        YandexMapController,
        YandexMap,
        Point,
        PlacemarkMapObject,
        PolylineMapObject,
        Polyline,
        MapObjectId,
        CameraUpdate,
        CameraPosition,
        YandexDriving,
        RequestPoint,
        RequestPointType,
        DrivingOptions,
        PlacemarkIcon,
        PlacemarkIconStyle,
        BitmapDescriptor;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/constants.dart';
import '../widgets/driver_sidebar.dart';
import '../services/supabase_service.dart';
import '../services/app_location.dart';
import '../services/location_service.dart';
import '../services/map_service.dart';
import '../models/user_model.dart';
import '../models/driver_model.dart';
import '../models/order_model.dart';
import '../widgets/custom_yandex_map.dart';
import '../widgets/native_yandex_map.dart';
import '../widgets/city_selector_widget.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart'
    show
        YandexSearch,
        SearchSession,
        SearchOptions,
        SearchResult,
        Point,
        PlacemarkMapObject,
        PlacemarkIconStyle,
        YandexDriving,
        DrivingSession,
        DrivingOptions,
        DrivingRoute,
        PolylineMapObject,
        Polyline,
        PolylineStyle,
        YandexSuggest,
        SuggestSession,
        SuggestOptions,
        SuggestItem,
        SuggestType;

class DriverMapScreen extends StatefulWidget {
  const DriverMapScreen({super.key});

  @override
  State<DriverMapScreen> createState() => _DriverMapScreenState();
}

class _DriverMapScreenState extends State<DriverMapScreen> {
  // Контроллер для управления нижним баром
  final DraggableScrollableController _bottomSheetController =
      DraggableScrollableController();

  // Состояния нижнего бара
  double _initialSheetSize = 0.3; // Начальный размер (30% экрана)
  double _minSheetSize = 0.1; // Минимальный размер (10% экрана)
  double _maxSheetSize = 0.7; // Максимальный размер (70% экрана)

  // Статус заказа
  String _orderStatus =
      'available'; // available, assigned, inProgress, waitingForClient, completed

  // Статистика водителя
  double _todayEarnings = 0.0;
  int _todayTrips = 0;
  double _totalEarnings = 0.0;
  int _totalTrips = 0;
  double _driverRating = 5.0;
  Duration _todayOnlineTime = Duration.zero;
  DateTime _onlineStartTime = DateTime.now();
  
  // Таймеры
  Timer? _testOrderTimer;
  Timer? _waitingTimer;
  int _waitingMinutes = 0;
  int _waitingSeconds = 0;
  double _waitingFee = 0.0;
  
  // Маршруты
  bool _isRouteToClient = true; // true - к клиенту, false - к назначению
  
  // Время до прибытия к клиенту
  Duration? _estimatedTimeToClient;
  Duration? _estimatedTimeToDestination;

  // Состояние боковой панели
  bool _isSidebarOpen = false;

  // Сервис для доступа к Supabase
  final SupabaseService _supabaseService = SupabaseService();
  // Текущий пользователь (водитель)
  UserModel? _currentDriver;
  bool _isLoading = true;
  bool _isOnline = false;

  // Подписка на изменения статуса
  StreamSubscription<bool>? _statusSubscription;
  
  // Карта и местоположение
  YandexMapController? _mapController;
  final LocationService _locationService = LocationService();
  Point? _currentLocation;
  bool _isMapInitialized = false;
  
  // Маркеры и маршруты
  final List<PlacemarkMapObject> _placemarks = [];
  PolylineMapObject? _routePolyline;
  
  // Заказы
  List<OrderModel> _availableOrders = [];
  OrderModel? _currentOrder;
  
  // Фильтр по городу
  String _selectedCity = 'Все города';
  final MapService _mapService = MapService();

  @override
  void initState() {
    super.initState();
    _loadDriverData();
    _loadDriverStatus();
    _loadDriverStatistics();
    _initializeLocation();
    _loadAvailableOrders();

    // Подписываемся на изменения статуса
    _statusSubscription =
        _supabaseService.driverStatusStream.listen((isOnline) {
      debugPrint('Получено обновление статуса: $isOnline');
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
    _testOrderTimer?.cancel();
    _waitingTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  // Загрузка данных текущего водителя
  Future<void> _loadDriverData() async {
    try {
      final driver = await _supabaseService.getCurrentUser();
      setState(() {
        _currentDriver = driver;
      });
    } catch (e) {
      debugPrint('Ошибка загрузки данных водителя: $e');
    } finally {
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

  // Загрузка статистики водителя
  Future<void> _loadDriverStatistics() async {
    try {
      if (_supabaseService.currentUserId == null) return;
      
      final response = await Supabase.instance.client
          .from('profiles')
          .select('today_earnings, today_trips, total_earnings, total_trips, rating, last_trip_date')
          .eq('id', _supabaseService.currentUserId!)
          .maybeSingle();
      
      if (response != null && mounted) {
        final today = DateTime.now();
        final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
        final lastTripDate = response['last_trip_date'] as String?;
        
        setState(() {
          // Если последняя поездка была не сегодня, сбрасываем дневную статистику
          if (lastTripDate != todayStr) {
            _todayEarnings = 0.0;
            _todayTrips = 0;
          } else {
            _todayEarnings = (response['today_earnings'] as num?)?.toDouble() ?? 0.0;
            _todayTrips = (response['today_trips'] as int?) ?? 0;
          }
          
          _totalEarnings = (response['total_earnings'] as num?)?.toDouble() ?? 0.0;
          _totalTrips = (response['total_trips'] as int?) ?? 0;
          _driverRating = (response['rating'] as num?)?.toDouble() ?? 5.0;
        });
        
        debugPrint('📊 Загружена статистика: $_todayTrips поездок, ${_todayEarnings}₽ за сегодня');
      }
    } catch (e) {
      debugPrint('❌ Ошибка загрузки статистики: $e');
    }
  }

  // Инициализация местоположения
  Future<void> _initializeLocation() async {
    try {
      final hasPermission = await _locationService.requestPermission();
      if (hasPermission) {
        final location = await _locationService.getCurrentLocation();
        if (location != null && mounted) {
          setState(() {
            _currentLocation = Point(
              latitude: location.lat,
              longitude: location.long,
            );
          });
          
          // Определяем город по координатам
          // Определяем город по координатам (заглушка)
          final city = 'Москва'; // TODO: Реализовать определение города
          if (city != null && mounted) {
            setState(() {
              _selectedCity = city;
            });
          }
          
          // Перемещаем камеру к текущему местоположению
          if (_mapController != null) {
            await _moveToCurrentLocation();
          }
        }
      }
    } catch (e) {
      debugPrint('Ошибка инициализации местоположения: $e');
    }
  }
  
  // Перемещение камеры к текущему местоположению
  Future<void> _moveToCurrentLocation() async {
    if (_mapController != null && _currentLocation != null) {
      await _mapController!.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _currentLocation!,
            zoom: 15,
          ),
        ),
      );
      
      // Добавляем маркер водителя
      _updateDriverMarker();
    }
  }
  
  // Обновление маркера водителя
  void _updateDriverMarker() {
    if (_currentLocation == null) return;
    
    _placemarks.removeWhere((marker) => marker.mapId.value == 'driver_location');
    
    _placemarks.add(
      PlacemarkMapObject(
        mapId: const MapObjectId('driver_location'),
        point: _currentLocation!,
        icon: PlacemarkIcon.single(
          PlacemarkIconStyle(
            image: BitmapDescriptor.fromAssetImage('assets/icons/car_marker.png'),
            scale: 0.5,
          ),
        ),
      ),
    );
    
    if (mounted) {
      setState(() {});
    }
  }
  
  // Загрузка доступных заказов
  Future<void> _loadAvailableOrders() async {
    if (!_isOnline) return;
    
    try {
      // Создаем тестовый заказ через 3 секунды после перехода в онлайн
      _testOrderTimer?.cancel();
      _testOrderTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && _isOnline && _orderStatus == 'available') {
          _createTestOrder();
        }
      });
      
      if (mounted) {
        setState(() {
          _availableOrders = [];
        });
        
        // Показываем маркеры заказов на карте
        _showOrderMarkers();
      }
    } catch (e) {
      debugPrint('Ошибка загрузки заказов: $e');
    }
  }
  
  // Показ маркеров заказов на карте
  void _showOrderMarkers() {
    // Удаляем старые маркеры заказов
    _placemarks.removeWhere((marker) => 
        marker.mapId.value.startsWith('order_'));
    
    // Добавляем новые маркеры
    for (final order in _availableOrders) {
      _placemarks.add(
        PlacemarkMapObject(
          mapId: MapObjectId('order_${order.id}'),
          point: Point(
            latitude: order.startLat,
            longitude: order.startLng,
          ),
          icon: PlacemarkIcon.single(
            PlacemarkIconStyle(
              image: BitmapDescriptor.fromAssetImage('assets/icons/pickup_marker.png'),
              scale: 0.4,
            ),
          ),
          onTap: (_, __) => _showOrderDetails(order),
        ),
      );
    }
    
    if (mounted) {
      setState(() {});
    }
  }
  
  // Показ деталей заказа
  void _showOrderDetails(OrderModel order) {
    setState(() {
      _currentOrder = order;
      _orderStatus = 'assigned';
    });
    
    // Строим маршрут до точки подачи
    _buildRouteToPickup(order);
  }
  
  // Построение маршрута до точки подачи
  Future<void> _buildRouteToPickup(OrderModel order) async {
    if (_currentLocation == null) return;
    
    try {
      debugPrint('Построение маршрута к клиенту...');
      
      final result = await YandexDriving.requestRoutes(
        points: [
          RequestPoint(
            point: _currentLocation!,
            requestPointType: RequestPointType.wayPoint,
          ),
          RequestPoint(
            point: Point(latitude: order.startLat, longitude: order.startLng),
            requestPointType: RequestPointType.wayPoint,
          ),
        ],
        drivingOptions: const DrivingOptions(),
      );
      
      final sessionResult = await result.result;
      final routes = sessionResult.routes;
      
      if (routes != null && routes.isNotEmpty && mounted) {
        final route = routes.first;
        final distance = route.metadata.weight.distance.value;
        final time = route.metadata.weight.time.value;
        
        setState(() {
          _routePolyline = PolylineMapObject(
            mapId: const MapObjectId('route_to_pickup'),
            polyline: Polyline(points: route.geometry),
            strokeColor: const Color(0xFFF654AA),
            strokeWidth: 4,
          );
          
          // Сохраняем время до прибытия к клиенту
          if (time != null) {
            _estimatedTimeToClient = Duration(seconds: time.toInt());
          }
        });
        
        debugPrint('Маршрут к клиенту построен: ${(distance?.toDouble() ?? 0) / 1000} км, время: ${time != null ? Duration(seconds: time.toInt()).inMinutes : 0} мин');
      }
    } catch (e) {
      debugPrint('Ошибка построения маршрута к клиенту: $e');
      // При ошибке создаем простой маршрут
      _createSimpleRoute(
        _currentLocation!,
        Point(latitude: order.startLat, longitude: order.startLng),
        'route_to_pickup',
        const Color(0xFFF654AA),
      );
    }
  }
  
  // Построение маршрута от клиента до назначения
  Future<void> _buildRouteToDestination(OrderModel order) async {
    try {
      debugPrint('Построение маршрута от клиента до назначения...');
      
      final result = await YandexDriving.requestRoutes(
        points: [
          RequestPoint(
            point: Point(latitude: order.startLat, longitude: order.startLng),
            requestPointType: RequestPointType.wayPoint,
          ),
          RequestPoint(
            point: Point(latitude: order.endLat, longitude: order.endLng),
            requestPointType: RequestPointType.wayPoint,
          ),
        ],
        drivingOptions: const DrivingOptions(),
      );
      
      final sessionResult = await result.result;
      final routes = sessionResult.routes;
      
      if (routes != null && routes.isNotEmpty && mounted) {
        final route = routes.first;
        final distance = route.metadata.weight.distance.value;
        final time = route.metadata.weight.time.value;
        
        setState(() {
          _routePolyline = PolylineMapObject(
            mapId: const MapObjectId('route_to_destination'),
            polyline: Polyline(points: route.geometry),
            strokeColor: const Color(0xFFA5C572),
            strokeWidth: 4,
          );
          _isRouteToClient = false;
          
          // Сохраняем время до назначения
          if (time != null) {
            _estimatedTimeToDestination = Duration(seconds: time.toInt());
          }
        });
        
        debugPrint('Маршрут до назначения построен: ${(distance?.toDouble() ?? 0) / 1000} км, время: ${time != null ? Duration(seconds: time.toInt()).inMinutes : 0} мин');
      }
    } catch (e) {
      debugPrint('Ошибка построения маршрута до назначения: $e');
      // При ошибке создаем простой маршрут
      _createSimpleRoute(
        Point(latitude: order.startLat, longitude: order.startLng),
        Point(latitude: order.endLat, longitude: order.endLng),
        'route_to_destination',
        const Color(0xFFA5C572),
      );
    }
  }
  
  // Создание простого маршрута (запасной вариант)
  void _createSimpleRoute(Point start, Point end, String routeId, Color color) {
    if (mounted) {
      setState(() {
        _routePolyline = PolylineMapObject(
          mapId: MapObjectId(routeId),
          polyline: Polyline(points: [start, end]),
          strokeColor: color,
          strokeWidth: 4,
        );
      });
    }
  }
  
  // Принятие заказа
  Future<void> _acceptOrder(OrderModel order) async {
    try {
      // Заглушка для принятия заказа
      final success = true;
      
      if (success && mounted) {
        setState(() {
          _currentOrder = order;
          _orderStatus = 'inProgress';
          _isRouteToClient = true; // Начинаем с маршрута к клиенту
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Заказ принят! Построен маршрут к клиенту'),
            backgroundColor: Color(0xFFA5C572),
          ),
        );
        
        // Построить маршрут до точки подачи
        _buildRouteToPickup(order);
      }
    } catch (e) {
      debugPrint('Ошибка принятия заказа: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ошибка при принятии заказа'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // Отклонение заказа
  Future<void> _declineOrder(OrderModel order) async {
    try {
      // Снижаем рейтинг водителя за отклонение
      // Заглушка для обновления рейтинга
      // TODO: Реализовать обновление рейтинга водителя
      
      setState(() {
        _currentOrder = null;
        _orderStatus = 'available';
        _routePolyline = null;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Заказ отклонен. Рейтинг снижен на 0.1'),
          backgroundColor: Color(0xFFFDAD6),
        ),
      );
      
      // Обновляем список заказов
      _loadAvailableOrders();
    } catch (e) {
      debugPrint('Ошибка отклонения заказа: $e');
    }
  }

  // Обновление статуса водителя (асинхронная версия)
  Future<void> _updateDriverStatusAsync(bool isOnline) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Заглушка для обновления статуса в базе данных
      await Future.delayed(const Duration(milliseconds: 500));
      
      setState(() {
        _isOnline = isOnline;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isOnline ? 'Вы в сети' : 'Вы не в сети'),
          backgroundColor: isOnline ? const Color(0xFFA5C572) : Colors.grey,
        ),
      );
      
      if (isOnline) {
        _loadAvailableOrders();
      }
    } catch (e) {
      debugPrint('Ошибка обновления статуса водителя: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Яндекс карта
          YandexMap(
            onMapCreated: (YandexMapController controller) {
              _mapController = controller;
              setState(() {
                _isMapInitialized = true;
              });
              
              // Перемещаемся к текущему местоположению
              if (_currentLocation != null) {
                _moveToCurrentLocation();
              }
            },
            mapObjects: [
              ..._placemarks,
              if (_routePolyline != null) _routePolyline!,
            ],
          ),

          // Верхняя навигационная панель
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 70,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    // Увеличиваем область нажатия для кнопки меню
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(30),
                        onTap: _toggleSidebar,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          child: const Icon(Icons.menu, size: 28),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Мама такси',
                      style: TextStyle(
                        fontSize: 24,
                        color: AppColors.success,
                        fontFamily: 'Nunito',
                      ),
                    ),
                    const Spacer(),
                    // Аватарка водителя с увеличенной областью нажатия
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(30),
                        onTap: () {
                          // Можно добавить переход в профиль водителя
                          _toggleSidebar();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(9999),
                              color: Colors.grey[300],
                            ),
                            child: _currentDriver?.avatarUrl != null &&
                                    _currentDriver!.avatarUrl!.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: Image.network(
                                      _currentDriver!.avatarUrl!,
                                      fit: BoxFit.cover,
                                      width: 40,
                                      height: 40,
                                      errorBuilder: (context, error, stackTrace) {
                                        return const Icon(
                                          Icons.person,
                                          size: 24,
                                          color: Colors.grey,
                                        );
                                      },
                                    ),
                                  )
                                : const Icon(
                                    Icons.person,
                                    size: 24,
                                    color: Colors.grey,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Кнопка "онлайн/офлайн"
          Positioned(
            top: 80,
            right: 16,
            child: GestureDetector(
              onTap: () => _updateDriverStatus(!_isOnline),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _isOnline ? AppColors.success : Colors.grey,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.circle, color: Colors.white, size: 12),
                    SizedBox(width: 8),
                    Text(
                      _isOnline ? 'Онлайн' : 'Оффлайн',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Нижний бар с перетаскиванием
          DraggableScrollableSheet(
            initialChildSize: _initialSheetSize,
            minChildSize: _minSheetSize,
            maxChildSize: _maxSheetSize,
            controller: _bottomSheetController,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Индикатор перетаскивания
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),

                      // Секция с информацией в зависимости от статуса
                      if (_orderStatus == 'available')
                        _buildAvailableSection()
                      else if (_orderStatus == 'assigned')
                        _buildAssignedSection()
                      else if (_orderStatus == 'inProgress')
                        _buildInProgressSection()
                      else if (_orderStatus == 'waitingForClient')
                        _buildWaitingSection()
                      else
                        _buildCompletedSection(),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              );
            },
          ),

          // Боковая панель (выдвигается слева)
          if (_isSidebarOpen)
            Positioned(
              top: 0,
              left: 0,
              bottom: 0,
              child: GestureDetector(
                onHorizontalDragUpdate: (details) {
                  if (details.delta.dx < -10) {
                    _toggleSidebar();
                  }
                },
                child: Row(
                  children: [
                    DriverSidebar(
                      driverName: _currentDriver?.fullName ?? "Загрузка...",
                      driverRating: _driverRating.toStringAsFixed(1),
                      driverImageUrl: _currentDriver?.avatarUrl,
                      onClose: _toggleSidebar,
                      isOnline: _isOnline,
                      onStatusChange: _updateDriverStatus,
                    ),
                    // Полупрозрачная область для закрытия при нажатии
                    GestureDetector(
                      onTap: _toggleSidebar,
                      child: Container(width: 50, color: Colors.transparent),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _isOnline ? Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            onPressed: _createTestOrder,
            backgroundColor: const Color(0xFFFDAD6),
            heroTag: "test_order",
            child: const Icon(Icons.add_task),
            tooltip: 'Создать тестовый заказ',
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            onPressed: _changeOrderStatus,
            backgroundColor: AppColors.primary,
            heroTag: "change_status",
            child: const Icon(Icons.refresh),
            tooltip: 'Изменить статус заказа (демо)',
          ),
        ],
      ) : null,
    );
  }

  // Переключение состояния боковой панели
  void _toggleSidebar() {
    setState(() {
      _isSidebarOpen = !_isSidebarOpen;
    });
  }

  // Изменение статуса заказа (для демонстрации)
  void _changeOrderStatus() {
    setState(() {
      if (_orderStatus == 'available')
        _orderStatus = 'assigned';
      else if (_orderStatus == 'assigned')
        _orderStatus = 'inProgress';
      else if (_orderStatus == 'inProgress')
        _orderStatus = 'completed';
      else
        _orderStatus = 'available';
    });
  }

  // Создание тестового заказа
  void _createTestOrder() {
    final testOrder = OrderModel(
      id: 'test_order_${DateTime.now().millisecondsSinceEpoch}',
      clientId: 'test_client_001',
      driverId: null,
      startLat: 55.7558,
      startLng: 37.6176,
      endLat: 55.7522,
      endLng: 37.6156,
      startAddress: 'Красная площадь, 1',
      endAddress: 'ул. Тверская, 15',
      price: 450.0,
      status: OrderStatus.created,
      createdAt: DateTime.now(),
      clientName: 'Анна Петрова',
      clientPhone: '+7 (999) 123-45-67',
      clientRating: '4.9',
      childCount: 1,
      comment: 'Нужно детское автокресло для ребенка 5 лет',
    );
    
    setState(() {
      _currentOrder = testOrder;
      _orderStatus = 'assigned';
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Новый заказ! Проверьте детали в нижней панели'),
        backgroundColor: Color(0xFFF654AA),
        duration: Duration(seconds: 4),
      ),
    );
  }
  
  // Принятие текущего заказа
  void _acceptCurrentOrder() {
    if (_currentOrder != null) {
      _acceptOrder(_currentOrder!);
    } else {
      _createTestOrder();
    }
  }

  // Отклонение текущего заказа
  void _declineCurrentOrder() {
    if (_currentOrder != null) {
      _declineOrder(_currentOrder!);
    } else {
      setState(() {
        _orderStatus = 'available';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Заказ отклонен'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  // Получение текущего времени онлайн
  Duration _getOnlineTime() {
    if (!_isOnline) return _todayOnlineTime;
    return _todayOnlineTime + DateTime.now().difference(_onlineStartTime);
  }

  // Форматирование длительности
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0) {
      return '${hours}ч ${minutes}м';
    } else {
      return '${minutes}м';
    }
  }

  // Обновление статистики при завершении поездки
  void _updateStatsOnRideComplete() {
    setState(() {
      _todayTrips++;
      _totalTrips++;
      if (_currentOrder != null) {
        _todayEarnings += _currentOrder!.price;
        _totalEarnings += _currentOrder!.price;
        // Повышаем рейтинг водителя (случайно от 0.1 до 0.3)
        final ratingIncrease = 0.1 + (DateTime.now().millisecond % 3) * 0.1;
        _driverRating = (_driverRating + ratingIncrease).clamp(0.0, 5.0);
      }
    });
  }

  // Обновление статуса онлайн
  void _updateOnlineStatus(bool isOnline) {
    if (isOnline && !_isOnline) {
      _onlineStartTime = DateTime.now();
    } else if (!isOnline && _isOnline) {
      _todayOnlineTime += DateTime.now().difference(_onlineStartTime);
    }
  }

  // Прибытие к клиенту
  void _arrivedAtClient() {
    if (_currentOrder == null) return;
    
    setState(() {
      _orderStatus = 'waitingForClient';
      _waitingMinutes = 0;
      _waitingSeconds = 0;
      _waitingFee = 0.0;
    });
    
    // Построить маршрут от клиента до назначения
    _buildRouteToDestination(_currentOrder!);
    
    // Запускаем 5-минутный таймер
    _startWaitingTimer();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Прибыл к клиенту! Ожидание 5 минут'),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 3),
      ),
    );
  }
  
  // Запуск таймера ожидания
  void _startWaitingTimer() {
    _waitingTimer?.cancel();
    _waitingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _waitingSeconds++;
        if (_waitingSeconds >= 60) {
          _waitingSeconds = 0;
          _waitingMinutes++;
          
          // После 5 минут начинаем начислять доплату
          if (_waitingMinutes > 5) {
            _waitingFee += 10.0;
          }
        }
      });
    });
  }
  
  // Остановка таймера ожидания
  void _stopWaitingTimer() {
    _waitingTimer?.cancel();
  }
  
  // Клиент сел в машину
  void _clientBoarded() {
    _stopWaitingTimer();
    
    setState(() {
      _orderStatus = 'inProgress';
      _isRouteToClient = false;
    });
    
    final totalPrice = (_currentOrder?.price ?? 0) + _waitingFee;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Клиент сел! Поездка началась. Стоимость: ${totalPrice.toStringAsFixed(0)}₽'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }
  
  // Клиент не пришел
  void _clientNoShow() {
    _stopWaitingTimer();
    
    setState(() {
      _orderStatus = 'completed';
      _currentOrder = null;
      _routePolyline = null;
      _waitingMinutes = 0;
      _waitingSeconds = 0;
      _waitingFee = 0.0;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Клиент не пришел. Рейтинг не снижен'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 3),
      ),
    );
    
    // Возвращаемся к поиску новых заказов
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _orderStatus = 'available';
        });
      }
    });
  }
  
  // Подождать еще
  void _waitMore() {
    // Просто продолжаем ожидание, таймер уже работает
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Продолжаем ожидание... +10₽ за каждую минуту'),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 2),
      ),
    );
  }
  
  // Завершение поездки
  void _completeTrip() async {
    if (_currentOrder == null) return;
    
    // Используем реальную цену заказа вместо фиксированной суммы
    final baseAmount = _currentOrder!.price; // Цена из заказа
    final totalAmount = baseAmount + _waitingFee;
    
    // Сохраняем статистику в базе данных
    try {
      // Сохраняем статистику через прямое обращение к Supabase
      final success = await _saveDriverStatistics(
        earnings: totalAmount,
        trips: 1,
      );
      
      if (success) {
        debugPrint('Статистика водителя успешно обновлена: +${totalAmount}₽, +1 поездка');
      } else {
        debugPrint('Ошибка обновления статистики водителя');
      }

      // Начисляем баллы лояльности за завершенную поездку
      final pointsAdded = await _supabaseService.addLoyaltyPoints(
        points: 15,
        description: 'Завершенная поездка',
      );
      
      if (pointsAdded) {
        debugPrint('Начислено 15 баллов лояльности за поездку');
      }

      // Обновляем статус заказа на завершенный
      await _supabaseService.updateOrderStatus(
        orderId: _currentOrder!.id,
        status: 'completed',
      );
    } catch (e) {
      debugPrint('Ошибка сохранения статистики: $e');
    }
    
    // Обновляем локальную статистику для отображения
    _todayTrips++;
    _todayEarnings += totalAmount;
    _driverRating = (_driverRating + 4.8) / 2; // Средний рейтинг
    
    setState(() {
      _orderStatus = 'completed';
      _currentOrder = null;
      _routePolyline = null;
      // Убираем маркеры (если они есть)
      _placemarks.removeWhere((placemark) => 
          placemark.mapId.value == 'pickup' || 
          placemark.mapId.value == 'destination');
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Поездка завершена! +${totalAmount.toStringAsFixed(0)}₽ | +15 баллов | Рейтинг: ${_driverRating.toStringAsFixed(1)}⭐'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 5),
      ),
    );
    
    // Возвращаемся к поиску новых заказов через 5 секунд
    Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _orderStatus = 'available';
        });
        // Автоматически создаем новый тестовый заказ через 10 секунд
        Timer(const Duration(seconds: 10), () {
          if (mounted && _orderStatus == 'available') {
            _createTestOrder();
          }
        });
      }
    });
  }

  // Диалог связи с клиентом
  void _showContactDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Связаться с клиентом'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.phone),
                title: const Text('Позвонить'),
                subtitle: Text(_currentOrder?.clientPhone ?? '+7 XXX XXX XX XX'),
                onTap: () {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Звонок клиенту...')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.message),
                title: const Text('Написать'),
                subtitle: const Text('Отправить сообщение'),
                onTap: () {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Сообщение отправлено')),
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Закрыть'),
            ),
          ],
        );
      },
    );
  }

  // Расчет расстояния поездки (заглушка)
  String _calculateDistanceString() {
    if (_currentOrder == null) return '0';
    // Простая заглушка для расчета расстояния
    final lat1 = _currentOrder!.startLat;
    final lng1 = _currentOrder!.startLng;
    final lat2 = _currentOrder!.endLat;
    final lng2 = _currentOrder!.endLng;
    
    // Упрощенный расчет расстояния
    final distance = _calculateDistance(lat1, lng1, lat2, lng2);
    return distance.toStringAsFixed(1);
  }
  
  // Вспомогательные функции для расчета расстояния и времени
  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    // Простая заглушка для расчета расстояния
    return 5.2; // км
  }
  
  int _calculateDuration(double lat1, double lng1, double lat2, double lng2) {
    // Простая заглушка для расчета времени
    return 15; // минут
  }

  // Расчет времени поездки (заглушка)
  String _calculateDurationString() {
    if (_currentOrder == null) return '0';
    // Простая заглушка - примерно 3 км/мин
    final distance = double.tryParse(_calculateDistanceString()) ?? 0;
    final duration = (distance * 3).round();
    return duration.toString();
  }
  
  
  // Сохранение статистики водителя в базе данных
  Future<bool> _saveDriverStatistics({
    required double earnings,
    required int trips,
  }) async {
    try {
      if (_supabaseService.currentUserId == null) {
        debugPrint('❌ Нет ID пользователя для сохранения статистики');
        return false;
      }
      
      final today = DateTime.now();
      final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      
      debugPrint('💾 Сохраняем статистику: +${earnings}₽, +${trips} поездок для водителя ${_supabaseService.currentUserId} на дату $todayStr');
      
      // Используем простое сохранение в таблицу profiles вместо отдельной таблицы
      final currentProfile = await Supabase.instance.client
          .from('profiles')
          .select('today_earnings, today_trips, total_earnings, total_trips')
          .eq('id', _supabaseService.currentUserId!)
          .maybeSingle();
      
      if (currentProfile != null) {
        // Обновляем существующий профиль
        final newTodayEarnings = (currentProfile['today_earnings'] ?? 0.0) + earnings;
        final newTodayTrips = (currentProfile['today_trips'] ?? 0) + trips;
        final newTotalEarnings = (currentProfile['total_earnings'] ?? 0.0) + earnings;
        final newTotalTrips = (currentProfile['total_trips'] ?? 0) + trips;
        
        await Supabase.instance.client
            .from('profiles')
            .update({
              'today_earnings': newTodayEarnings,
              'today_trips': newTodayTrips,
              'total_earnings': newTotalEarnings,
              'total_trips': newTotalTrips,
              'last_trip_date': todayStr,
            })
            .eq('id', _supabaseService.currentUserId!);
            
        debugPrint('✅ Статистика обновлена: $newTodayTrips поездок, ${newTodayEarnings}₽ за сегодня');
      } else {
        debugPrint('❌ Профиль водителя не найден');
        return false;
      }
      
      return true;
    } catch (e) {
      debugPrint('❌ Ошибка сохранения статистики: $e');
      return false;
    }
  }
  
  // Обновление статуса водителя
  void _updateDriverStatus(bool isOnline) {
    _updateOnlineStatus(isOnline);
    
    setState(() {
      _isOnline = isOnline;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isOnline ? 'Вы в сети' : 'Вы не в сети'),
        backgroundColor: isOnline ? Colors.green : Colors.grey,
      ),
    );
    
    if (isOnline) {
      _loadAvailableOrders();
    } else {
      // Очищаем заказы при переходе в оффлайн
      setState(() {
        _availableOrders.clear();
        _currentOrder = null;
        _orderStatus = 'available';
      });
    }
  }
  

  // Секция когда нет активных заказов
  Widget _buildAvailableSection() {
    return Container(
      margin: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Нет активных заказов',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Rubik',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Ожидание заказов',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                    fontFamily: 'Rubik',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Статистика за сегодня',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Rubik',
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatItem('Поездок', _todayTrips.toString()),
                    _buildStatItem('Заработано', '${_todayEarnings.toStringAsFixed(0)}₽'),
                    _buildStatItem('Онлайн', _formatDuration(_getOnlineTime())),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Секция с назначенным заказом
  Widget _buildAssignedSection() {
    return Container(
      margin: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Новый заказ',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Rubik',
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 24,
                      backgroundColor: Color(0xFFF3F4F6),
                      child: Icon(Icons.person, color: Color(0xFF9CA3AF)),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentOrder?.clientName ?? 'Клиент',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Rubik',
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.star,
                              size: 16,
                              color: Color(0xFFF59E0B),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _currentOrder?.clientRating ?? '4.8',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                                fontFamily: 'Rubik',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      '${_currentOrder?.price.toStringAsFixed(0) ?? '0'}₽',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Rubik',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0xFFE5E7EB)),
                const SizedBox(height: 16),
                _buildAddressRow(
                  'Откуда',
                  _currentOrder?.startAddress ?? 'Адрес загрузки...',
                  Icons.circle_outlined,
                ),
                Container(
                  margin: const EdgeInsets.only(left: 12),
                  width: 1,
                  height: 16,
                  color: AppColors.link,
                ),
                _buildAddressRow(
                  'Куда',
                  _currentOrder?.endAddress ?? 'Адрес назначения...',
                  Icons.location_on_outlined,
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0xFFE5E7EB)),
                const SizedBox(height: 16),
                if (_currentOrder?.childCount != null && _currentOrder!.childCount! > 0)
                  _buildInfoRow(
                    'Детей',
                    '${_currentOrder!.childCount}',
                  ),
                const SizedBox(height: 8),
                if (_currentOrder?.comment != null && _currentOrder!.comment!.isNotEmpty)
                  _buildInfoRow(
                    'Комментарий',
                    _currentOrder!.comment!,
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _declineCurrentOrder,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.text,
                          side: BorderSide(color: AppColors.border),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Отклонить'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _acceptCurrentOrder,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Принять'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Секция с заказом в процессе
  Widget _buildInProgressSection() {
    if (_currentOrder == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.directions_car, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isRouteToClient ? 'Еду к клиенту' : 'Поездка в процессе',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    if (_isRouteToClient && _estimatedTimeToClient != null)
                      Text(
                        'Прибытие через ${_formatDuration(_estimatedTimeToClient!)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    if (!_isRouteToClient && _estimatedTimeToDestination != null)
                      Text(
                        'До назначения ${_formatDuration(_estimatedTimeToDestination!)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.green.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Информация о клиенте
          Row(
            children: [
              const Icon(Icons.person, size: 20, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                _currentOrder?.clientName ?? 'Клиент',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Маршрут
          Row(
            children: [
              const Icon(Icons.location_on, size: 20, color: Colors.green),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'От: ${_currentOrder?.startAddress ?? 'Адрес подачи'}',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.flag, size: 20, color: Colors.red),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'До: ${_currentOrder?.endAddress ?? 'Адрес назначения'}',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Информация о поездке
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Расстояние', style: TextStyle(color: Colors.grey)),
                  Text(
                    '${_calculateDistanceString()} км',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Время', style: TextStyle(color: Colors.grey)),
                  Text(
                    '${_calculateDurationString()} мин',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Стоимость', style: TextStyle(color: Colors.grey)),
                  Text(
                    '${_currentOrder?.price.toStringAsFixed(0) ?? '0'}₽',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Кнопки действий
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showContactDialog(),
                  icon: const Icon(Icons.phone),
                  label: const Text('Связаться'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade100,
                    foregroundColor: Colors.blue.shade700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (_isRouteToClient)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _arrivedAtClient,
                    icon: const Icon(Icons.location_on),
                    label: const Text('Прибыл'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFDAD6),
                      foregroundColor: Colors.white,
                    ),
                  ),
                )
              else
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _completeTrip,
                    icon: const Icon(Icons.check),
                    label: const Text('Завершить'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // Секция ожидания клиента
  Widget _buildWaitingSection() {
    if (_currentOrder == null) return const SizedBox.shrink();

    final isOvertime = _waitingMinutes > 5;
    final displayMinutes = _waitingMinutes;
    final displaySeconds = _waitingSeconds;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isOvertime ? Colors.orange.shade50 : Colors.yellow.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOvertime ? Colors.orange.shade200 : Colors.yellow.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.access_time,
                color: isOvertime ? Colors.orange.shade700 : Colors.yellow.shade700,
              ),
              const SizedBox(width: 8),
              Text(
                'Ожидание клиента',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isOvertime ? Colors.orange.shade700 : Colors.yellow.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Таймер
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isOvertime ? Colors.orange.shade100 : Colors.yellow.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.timer,
                  size: 32,
                  color: isOvertime ? Colors.orange.shade700 : Colors.yellow.shade700,
                ),
                const SizedBox(width: 12),
                Text(
                  '${displayMinutes.toString().padLeft(2, '0')}:${displaySeconds.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isOvertime ? Colors.orange.shade700 : Colors.yellow.shade700,
                  ),
                ),
              ],
            ),
          ),
          
          if (isOvertime) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.attach_money, color: Colors.red.shade700, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Доплата: +${_waitingFee.toStringAsFixed(0)}₽',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 16),
          
          // Информация о клиенте
          Row(
            children: [
              const Icon(Icons.person, size: 20, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                _currentOrder?.clientName ?? 'Клиент',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          Row(
            children: [
              const Icon(Icons.location_on, size: 20, color: Colors.green),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _currentOrder?.startAddress ?? 'Адрес подачи',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Кнопки действий
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _clientBoarded,
                  icon: const Icon(Icons.directions_car),
                  label: const Text('Клиент сел'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _waitMore,
                  icon: const Icon(Icons.schedule),
                  label: const Text('Подождать'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade100,
                    foregroundColor: Colors.blue.shade700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _clientNoShow,
                  icon: const Icon(Icons.cancel),
                  label: const Text('Не пришел'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade100,
                    foregroundColor: Colors.orange.shade700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  // Секция завершенного заказа
  Widget _buildCompletedSection() {
    return Container(
      margin: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Поездка завершена',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Rubik',
                    color: Color(0xFF059669),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildResultItem('Заработано', '${_currentOrder?.price.toStringAsFixed(0) ?? '0'}₽'),
                    _buildResultItem('Расстояние', '${_calculateDistanceString()} км'),
                    _buildResultItem('Время', '${_calculateDurationString()} мин'),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0xFFE5E7EB)),
                const SizedBox(height: 16),
                const Text(
                  'Оцените поездку',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Rubik',
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return Icon(
                      Icons.star,
                      size: 32,
                      color: index < 4
                          ? const Color(0xFFF59E0B)
                          : Colors.grey[300],
                    );
                  }),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      // Перейти к новым заказам
                      setState(() {
                        _orderStatus = 'available';
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Готов к новым заказам'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Вспомогательные виджеты
  Widget _buildStatItem(String title, String value) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            fontFamily: 'Rubik',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            fontFamily: 'Rubik',
          ),
        ),
      ],
    );
  }

  Widget _buildAddressRow(String title, String address, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 12),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontFamily: 'Rubik',
              ),
            ),
            const SizedBox(height: 2),
            Text(
              address,
              style: const TextStyle(fontSize: 14, fontFamily: 'Rubik'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoRow(String title, String value) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              fontFamily: 'Rubik',
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14, fontFamily: 'Rubik'),
          ),
        ),
      ],
    );
  }

  Widget _buildResultItem(String title, String value) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            fontFamily: 'Rubik',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            fontFamily: 'Rubik',
          ),
        ),
      ],
    );
  }
}
