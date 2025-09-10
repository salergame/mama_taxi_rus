import 'dart:async';
import 'dart:typed_data';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';
import 'package:mama_taxi/models/app_lat_long.dart';
import 'package:mama_taxi/models/order_model.dart';
import 'package:mama_taxi/models/user_model.dart';
import 'package:mama_taxi/services/app_location.dart';
import 'package:mama_taxi/services/location_service.dart';
import 'package:mama_taxi/services/map_service.dart';
import 'package:mama_taxi/services/price_calculator_service.dart';
import 'package:mama_taxi/services/supabase_service.dart';
import 'package:mama_taxi/utils/constants.dart';
import 'package:mama_taxi/widgets/custom_button.dart';
import 'package:mama_taxi/widgets/native_yandex_map.dart';
import 'package:mama_taxi/widgets/user_sidebar.dart';
import 'package:mama_taxi/widgets/waiting_for_taxi_dialog.dart';
import 'package:mama_taxi/widgets/city_selector_widget.dart';
import 'package:mama_taxi/widgets/location_permission_dialog.dart';
import 'package:mama_taxi/screens/user_profile_screen.dart';
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
import 'package:geocoding/geocoding.dart';
import 'package:mama_taxi/screens/chat_screen.dart';
import 'package:mama_taxi/services/driver_user_connection_service.dart';
import 'package:mama_taxi/models/driver_user_connection.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final TextEditingController _startLocationController =
      TextEditingController();
  final TextEditingController _endLocationController = TextEditingController();
  String _selectedTariff = 'Мама такси';
  String _paymentMethod = 'Наличные';
  final SupabaseService _supabaseService = SupabaseService();
  UserModel? _currentUser;
  bool _isLoading = true;
  bool _isMapInitialized = false;
  final LocationService _locationService = LocationService();
  final LocationService _locationService2 = LocationService();
  bool _mapReady = false;
  
  // Переменные для расчета цены
  double _routeDistanceInMeters = 0;
  Map<String, dynamic> _currentPriceData = {};
  bool _isHighDemand = false; // Флаг высокого спроса
  bool _isBadWeather = false; // Флаг плохой погоды
  int _numberOfPassengers = 1; // Количество пассажиров
  
  // Состояние заказа
  // idle - нет активного заказа
  // waiting - ожидание водителя
  // driverAssigned - водитель назначен и едет
  // driverArrived - водитель прибыл
  // inProgress - поездка началась
  // completed - поездка завершена
  String _orderState = 'idle';
  
  // ID текущего заказа
  String? _currentOrderId;
  
  // Информация о водителе (для демонстрации)
  Map<String, dynamic> _driverInfo = {
    'id': 'driver123',
    'name': 'Алексей Иванов',
    'rating': 4.8,
    'car': 'Toyota Camry',
    'carColor': 'Белый',
    'carNumber': 'А123БВ777',
    'phoneNumber': '+7 (999) 123-45-67',
    'avatarUrl': '',
    'estimatedArrival': '7 мин',
    'distance': '2.3 км'
  };

  // Контроллер для управления нижним баром
  final DraggableScrollableController _bottomSheetController =
      DraggableScrollableController();

  // Состояния нижнего бара
  double _initialSheetSize = 0.3; // Начальный размер (30% экрана)
  double _minSheetSize = 0.1; // Минимальный размер (10% экрана)
  double _maxSheetSize = 0.7; // Максимальный размер (70% экрана)

  // Состояние боковой панели
  bool _isSidebarOpen = false;

  // Дополнительные услуги
  final List<ExtraService> _extraServices = [
    ExtraService(
      id: 1,
      name: 'Проводить до входа в квартиру / школу',
      isSelected: true,
      image: '2',
    ),
    ExtraService(
      id: 2,
      name: 'Встретить ребенка у квартиры / подъезда',
      isSelected: true,
      image: '5',
    ),
    ExtraService(
      id: 3,
      name: 'Водитель — мужчина',
      isSelected: false,
      image: '4',
    ),
    ExtraService(
      id: 4,
      name: 'Водитель — женщина',
      isSelected: false,
      image: '3',
    ),
    ExtraService(
      id: 5,
      name: 'Детское автокресло',
      isSelected: false,
      image: '6',
    ),
  ];

  // Получить количество выбранных услуг
  int get selectedServicesCount =>
      _extraServices.where((service) => service.isSelected).length;
      
  // Получение списка ID выбранных услуг
  List<int> get selectedServiceIds =>
      _extraServices.where((service) => service.isSelected).map((service) => service.id).toList();

  String _userName = 'Пользователь';
  String? _userAvatarUrl;

  YandexMapController? _mapController;
  YandexMapController? _yandexMapController;
  final List<PlacemarkMapObject> _placemarks = [];
  SearchSession? _searchSession;
  PolylineMapObject? _routePolyline;
  Point? _startPoint;
  Point? _endPoint;

  List<SuggestItem> _suggestions = [];
  bool _isSuggestingStart = true;

  // Переменные для отслеживания активного режима маркера
  bool _isMarkerModeActive = false;
  bool _isStartMarkerActive = true;
  
  // Ключ для карты, чтобы можно было пересоздать её при необходимости
  final GlobalKey _mapKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _detectUserCity();
    _requestLocationPermission();
    _loadUserProfile();
    _loadUserData();
    _initializePriceData();
    debugPrint('MapScreen: initState вызван');
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Обрабатываем аргументы маршрута из расписания
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      _handleRouteArguments(args);
    }
  }
  
  // Обработка аргументов маршрута
  void _handleRouteArguments(Map<String, dynamic> args) {
    final startAddress = args['startAddress'] as String?;
    final endAddress = args['endAddress'] as String?;
    final buildRoute = args['buildRoute'] as bool? ?? false;
    
    if (startAddress != null && endAddress != null && buildRoute) {
      // Заполняем поля адресов
      _startLocationController.text = startAddress;
      _endLocationController.text = endAddress;
      
      // Строим маршрут после инициализации карты
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _buildRouteFromAddresses(startAddress, endAddress);
      });
    }
  }
  
  // Построение маршрута из адресов
  Future<void> _buildRouteFromAddresses(String startAddress, String endAddress) async {
    try {
      // Поиск точек для адресов
      final startItems = await MapService.searchAddressByText(startAddress);
      final endItems = await MapService.searchAddressByText(endAddress);
      
      if (startItems.isNotEmpty && endItems.isNotEmpty) {
        Point? startPoint;
        Point? endPoint;
        
        // Получаем точку начала
        final startItem = startItems.first;
        if (startItem.geometry is Point) {
          startPoint = startItem.geometry as Point;
        } else if (startItem.geometry is BoundingBox) {
          final boundingBox = startItem.geometry as BoundingBox;
          final centerLat = (boundingBox.northEast.latitude + boundingBox.southWest.latitude) / 2;
          final centerLon = (boundingBox.northEast.longitude + boundingBox.southWest.longitude) / 2;
          startPoint = Point(latitude: centerLat, longitude: centerLon);
        }
        
        // Получаем точку конца
        final endItem = endItems.first;
        if (endItem.geometry is Point) {
          endPoint = endItem.geometry as Point;
        } else if (endItem.geometry is BoundingBox) {
          final boundingBox = endItem.geometry as BoundingBox;
          final centerLat = (boundingBox.northEast.latitude + boundingBox.southWest.latitude) / 2;
          final centerLon = (boundingBox.northEast.longitude + boundingBox.southWest.longitude) / 2;
          endPoint = Point(latitude: centerLat, longitude: centerLon);
        }
        
        if (startPoint != null && endPoint != null) {
          // Проверяем, что точки в СНГ
          final startCity = MapService.detectCityByPoint(startPoint);
          final endCity = MapService.detectCityByPoint(endPoint);
          
          if (startCity != null && endCity != null) {
            final safeStartPoint = Point(latitude: startPoint.latitude, longitude: startPoint.longitude);
            final safeEndPoint = Point(latitude: endPoint.latitude, longitude: endPoint.longitude);
            
            setState(() {
              _startPoint = safeStartPoint;
              _endPoint = safeEndPoint;
            });
            
            // Добавляем маркеры
            setState(() {
              _placemarks.removeWhere((p) => p.mapId.value == 'start');
              _placemarks.removeWhere((p) => p.mapId.value == 'end');
              _placemarks.add(_createMapMarker(
                id: 'start',
                point: safeStartPoint,
                isStart: true,
              ));
              _placemarks.add(_createMapMarker(
                id: 'end',
                point: safeEndPoint,
                isStart: false,
              ));
            });
            
            // Строим маршрут
            await _buildRoute(safeStartPoint, safeEndPoint);
            
            // Показываем уведомление
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Маршрут построен'),
                  backgroundColor: Color(0xFFA5C572),
                ),
              );
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Один из адресов находится вне зоны обслуживания'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Ошибка построения маршрута из адресов: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ошибка построения маршрута'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // Инициализация данных о цене
  void _initializePriceData() {
    // Устанавливаем начальные данные о ценах для всех тарифов
    _currentPriceData = {
      'price': _getPriceForTariff(_selectedTariff),
      'formattedPrice': '${_getPriceForTariff(_selectedTariff)}₽',
      'timeRange': _getTimeRangeForTariff(_selectedTariff),
    };
    
    // Симуляция высокого спроса в 30% случаев
    _isHighDemand = DateTime.now().minute % 10 < 3;
    
    // Симуляция плохой погоды в 20% случаев
    _isBadWeather = DateTime.now().minute % 10 < 2;
  }
  
  // Получение цены для тарифа
  int _getPriceForTariff(String tariff) {
    switch (tariff) {
      case 'Мама такси': return 450;
      case 'Личный водитель': return 650;
      case 'Срочная поездка': return 850;
      case 'Женское такси': return 550;
      default: return 450;
    }
  }
  
  // Получение диапазона времени для тарифа
  String _getTimeRangeForTariff(String tariff) {
    switch (tariff) {
      case 'Мама такси': return '10-15 мин';
      case 'Личный водитель': return '15-20 мин';
      case 'Срочная поездка': return '5-8 мин';
      case 'Женское такси': return '15-20 мин';
      default: return '10-15 мин';
    }
  }

  // Загрузка данных профиля пользователя
  Future<void> _loadUserProfile() async {
    try {
      final userProfile = await _supabaseService.getCurrentUser();
      if (userProfile != null && mounted) {
        setState(() {
          _userName = userProfile.fullName.isNotEmpty
              ? userProfile.fullName
              : 'Пользователь';
          _userAvatarUrl = userProfile.avatarUrl;
        });
      }
    } catch (e) {
      debugPrint('Ошибка загрузки профиля пользователя: $e');
    }
  }

  // Загрузка данных пользователя
  Future<void> _loadUserData() async {
    try {
      final userProfile = await _supabaseService.getCurrentUser();
      if (userProfile != null && mounted) {
        setState(() {
          _currentUser = userProfile;
        });
      }
    } catch (e) {
      debugPrint('Ошибка загрузки данных пользователя: $e');
    }
  }

  // Определение города пользователя по геолокации
  Future<void> _detectUserCity() async {
    try {
      // Сначала проверяем разрешения
      final hasPermission = await _locationService2.checkPermission();
      if (!hasPermission) {
        final granted = await _locationService2.requestPermission();
        if (!granted) {
          debugPrint('Разрешение на геолокацию не предоставлено');
          return;
        }
      }

      final location = await _locationService2.getCurrentLocation();
      if (location != null) {
        final point = Point(latitude: location.lat, longitude: location.long);
        final detectedCity = MapService.detectCityByPoint(point);
        
        if (detectedCity != null) {
          final currentCity = MapService.getCurrentUserCity();
          if (detectedCity != currentCity) {
            MapService.setCurrentUserCity(detectedCity);
            debugPrint('Определен и установлен город пользователя: $detectedCity');
            
            // Показываем уведомление пользователю
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Город определен: $detectedCity'),
                  duration: const Duration(seconds: 3),
                  backgroundColor: const Color(0xFF5EC7C3),
                ),
              );
            }
            
            // Перемещаем карту к новому городу
            await _moveToCurrentCity();
          } else {
            debugPrint('Пользователь уже находится в правильном городе: $detectedCity');
          }
        } else {
          debugPrint('Не удалось определить город по координатам: ${location.lat}, ${location.long}');
          
          // Показываем уведомление о том, что город не поддерживается
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Ваше местоположение находится за пределами поддерживаемых регионов СНГ'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } else {
        debugPrint('Не удалось получить текущее местоположение');
      }
    } catch (e) {
      debugPrint('Ошибка определения города: $e');
    }
  }

  // Перемещение карты к текущему городу
  Future<void> _moveToCurrentCity() async {
    try {
      final cityInfo = MapService.getCurrentCityInfo();
      if (cityInfo != null && _yandexMapController != null) {
        await _yandexMapController!.moveCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: cityInfo.center,
              zoom: 12,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Ошибка перемещения к городу: $e');
    }
  }

  // Запрос разрешений на местоположение
  Future<void> _requestLocationPermission() async {
    try {
      var status = await Permission.location.status;
      
      // Если разрешение уже предоставлено, ничего не делаем
      if (status.isGranted) {
        debugPrint('Разрешение на местоположение уже получено');
        return;
      }
      
      // Если разрешение не запрашивалось или было отклонено, показываем диалог
      if (status.isDenied || status.isRestricted) {
        await _showLocationPermissionDialog();
      } else if (status.isPermanentlyDenied) {
        // Если разрешение отклонено навсегда, показываем диалог с предложением перейти в настройки
        await _showPermanentlyDeniedDialog();
      }
    } catch (e) {
      debugPrint('Ошибка запроса разрешений: $e');
    }
  }

  // Показать диалог запроса разрешения на местоположение
  Future<void> _showLocationPermissionDialog() async {
    if (!mounted) return;
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return LocationPermissionDialog(
          onAllow: () async {
            Navigator.of(context).pop();
            await _requestPermissionFromSystem();
          },
          onDeny: () {
            Navigator.of(context).pop();
            _showPermissionDeniedMessage();
          },
        );
      },
    );
  }

  // Запросить разрешение у системы
  Future<void> _requestPermissionFromSystem() async {
    try {
      var status = await Permission.location.request();
      if (status.isGranted) {
        debugPrint('Разрешение на местоположение получено');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Разрешение на местоположение получено'),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        // Автоматически определяем текущее местоположение
        _moveToCurrentLocation();
      } else if (status.isPermanentlyDenied) {
        await _showPermanentlyDeniedDialog();
      } else {
        _showPermissionDeniedMessage();
      }
    } catch (e) {
      debugPrint('Ошибка запроса разрешений у системы: $e');
    }
  }

  // Показать диалог для случая, когда разрешение отклонено навсегда
  Future<void> _showPermanentlyDeniedDialog() async {
    if (!mounted) return;
    
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Требуется разрешение',
            style: AppTextStyles.heading.copyWith(
              color: AppColors.text,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            'Для работы приложения необходим доступ к местоположению. Пожалуйста, предоставьте разрешение в настройках приложения.',
            style: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Отмена',
                style: AppTextStyles.button.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Настройки',
                style: AppTextStyles.button.copyWith(
                  color: AppColors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Показать сообщение об отклонении разрешения
  void _showPermissionDeniedMessage() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Без доступа к местоположению некоторые функции будут недоступны'),
          backgroundColor: AppColors.warning,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Разрешить',
            textColor: AppColors.white,
            onPressed: _showLocationPermissionDialog,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _startLocationController.dispose();
    _endLocationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Используем ключ для карты, чтобы можно было пересоздать её при необходимости
          YandexMap(
            key: _mapKey,
            onMapCreated: (controller) async {
              _mapController = controller;
              _yandexMapController = controller;
              await _mapController?.moveCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(
                    target: MapService.getCurrentCityInfo()?.center ?? const Point(latitude: 55.751244, longitude: 37.618423),
                    zoom: 12,
                  ),
                ),
              );
              
              setState(() {
                _mapReady = true;
              });
              
              // Показываем подсказку при инициализации карты
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Нажмите на карту, чтобы отметить точку отправления или назначения'),
                    duration: Duration(seconds: 3),
                  ),
                );
              }
              
              // Пытаемся определить текущее местоположение после инициализации карты
              await Future.delayed(const Duration(seconds: 1));
              _moveToCurrentLocation();
            },
            onMapTap: (point) async {
              // Блокируем изменение маршрута если заказ активен
              if (_orderState != 'idle') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Нельзя изменить маршрут во время активного заказа'),
                    duration: Duration(seconds: 2),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }
              
              // Если активен режим установки маркера, используем его
              if (_isMarkerModeActive) {
                final isStart = _isStartMarkerActive;
                final pointType = isStart ? 'отправления' : 'назначения';

                setState(() {
                  _placemarks.removeWhere(
                      (p) => p.mapId.value == (isStart ? 'start' : 'end'));
                  _placemarks.add(
                    _createMapMarker(
                      id: isStart ? 'start' : 'end',
                      point: point,
                      isStart: isStart,
                    ),
                  );
                  if (isStart) {
                    _startPoint = point;
                    _startLocationController.text = 'Определение адреса...';
                  } else {
                    _endPoint = point;
                    _endLocationController.text = 'Определение адреса...';
                  }

                  // Выключаем режим установки маркера
                  _isMarkerModeActive = false;
                });
                
                // Получаем адрес для установленной точки
                await _setAddressFromPoint(point: point, isStart: isStart);
              } else {
                // Обычный режим - пытаемся определить, какую точку установить
                final isStart = _startPoint == null;
                final pointType = isStart ? 'отправления' : 'назначения';

                setState(() {
                  _placemarks.removeWhere(
                      (p) => p.mapId.value == (isStart ? 'start' : 'end'));
                  _placemarks.add(
                    _createMapMarker(
                      id: isStart ? 'start' : 'end',
                      point: point,
                      isStart: isStart,
                    ),
                  );
                  if (isStart) {
                    _startPoint = point;
                    _startLocationController.text = 'Определение адреса...';
                  } else {
                    _endPoint = point;
                    _endLocationController.text = 'Определение адреса...';
                  }
                });
                
                // Получаем адрес для установленной точки
                await _setAddressFromPoint(point: point, isStart: isStart);
              }

              // Уведомляем пользователя о добавлении точки
              final pointType = _isMarkerModeActive
                  ? (_isStartMarkerActive ? 'отправления' : 'назначения')
                  : (_startPoint == null ? 'отправления' : 'назначения');

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Точка $pointType добавлена'),
                  duration: const Duration(seconds: 2),
                ),
              );

              if (_startPoint != null && _endPoint != null) {
                _buildRoute(_startPoint!, _endPoint!);
              }
            },
            mapObjects: _mapObjects,
          ),

          if (!_mapReady) 
            Container(
              color: Colors.white,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Загрузка карты...', style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            ),

          // Селектор города

          // Верхняя навигационная панель
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 85,
              padding: const EdgeInsets.symmetric(horizontal: 20),
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
                    Center(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(35),
                          onTap: _toggleSidebar,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            child: const Icon(Icons.menu, size: 32),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Мама такси',
                      style: TextStyle(
                        fontSize: 24,
                        color: AppColors.secondary,
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    // Аватарка пользователя с увеличенной областью нажатия
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(30),
                        onTap: () async {
                          // Переход в профиль пользователя
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const UserProfileScreen(),
                            ),
                          );
                          
                          // Обрабатываем результат возврата из профиля
                          if (result != null && result is Map<String, dynamic>) {
                            if (result['reorder_trip'] != null) {
                              final order = result['reorder_trip'] as OrderModel;
                              _reorderTrip(order);
                            }
                          }
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
                            child: _userAvatarUrl != null &&
                                    _userAvatarUrl!.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: Image.network(
                                      _userAvatarUrl!,
                                      fit: BoxFit.cover,
                                      width: 40,
                                      height: 40,
                                      errorBuilder: (context, error, stackTrace) {
                                        debugPrint(
                                            'Ошибка загрузки аватарки в шапке: $error');
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

                      // Секция ввода адресов
                      _buildAddressSection(),

                      // Секция выбора тарифа
                      _buildTariffSection(),

                      // Секция способа оплаты
                      _buildPaymentSection(),

                      // Секция дополнительных услуг
                      _buildExtraServicesSection(),

                      // Секция комментария
                      _buildCommentSection(),

                      // Кнопка заказа
                      _buildOrderButton(),

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
              right: 0,
              bottom: 0,
              child: GestureDetector(
                onHorizontalDragUpdate: (details) {
                  if (details.delta.dx < -10) {
                    _toggleSidebar();
                  }
                },
                child: Row(
                  children: [
                    UserSidebar(
                      userName: _userName,
                      userRating: '0.0',
                      userImageUrl: _userAvatarUrl,
                      onClose: _toggleSidebar,
                    ),
                    // Полупрозрачная область для закрытия при нажатии
                    Expanded(
                      child: GestureDetector(
                        onTap: _toggleSidebar,
                        child: Container(
                          color: Colors.black.withOpacity(0.3),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (_suggestions.isNotEmpty) _buildSuggestionsWidget(),
        ],
      ),
    );
  }

  // Переключение состояния боковой панели
  void _toggleSidebar() {
    setState(() {
      _isSidebarOpen = !_isSidebarOpen;
    });
  }

  // Секция ввода адресов
  Widget _buildAddressSection() {
    return Container(
      margin: const EdgeInsets.all(24),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Column(
                  children: [
                    const Icon(Icons.circle_outlined, size: 12),
                    Container(width: 1, height: 32, color: AppColors.secondary),
                    const Icon(Icons.location_on_outlined, size: 12),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    children: [
                      TextField(
                        controller: _startLocationController,
                        decoration: InputDecoration(
                          hintText: 'Место отправления',
                          hintStyle: TextStyle(
                            color: AppColors.placeholderText,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                          ),
                          border: OutlineInputBorder(
                            borderSide: BorderSide.none,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onChanged: (value) =>
                            _fetchSuggestions(value, isStart: true),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _endLocationController,
                        decoration: InputDecoration(
                          hintText: 'Место назначения',
                          hintStyle: TextStyle(
                            color: AppColors.placeholderText,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                          ),
                          border: OutlineInputBorder(
                            borderSide: BorderSide.none,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onChanged: (value) =>
                            _fetchSuggestions(value, isStart: false),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: _showRecentTrips,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.transparent,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.history, size: 14, color: AppColors.success),
                        const SizedBox(width: 8),
                        Text(
                          'Недавние',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.success,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.success),
                      ],
                    ),
                  ),
                ),
                // Кнопка для определения текущего местоположения
                ElevatedButton.icon(
                  onPressed: _moveToCurrentLocation,
                  icon: const Icon(Icons.my_location, size: 16),
                  label: const Text('Моё местоположение'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Секция выбора тарифа
  Widget _buildTariffSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Выбор тарифа',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    fontFamily: 'Rubik',
                  ),
                ),
                const SizedBox(height: 8),
                // Индикаторы текущих условий
                if (_isHighDemand || _isBadWeather)
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (_isHighDemand)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.trending_up, size: 14, color: Colors.orange[700]),
                              const SizedBox(width: 4),
                              Text(
                                'Высокий спрос',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_isBadWeather)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.cloudy_snowing, size: 14, color: Colors.blue[700]),
                              const SizedBox(width: 4),
                              Text(
                                'Плохая погода',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _buildTariffOption(
              'Мама такси',
              '10-15 мин',
              '450₽',
              Icons.family_restroom,
              isSelected: _selectedTariff == 'Мама такси',
            ),
            const SizedBox(height: 12),
            _buildTariffOption(
              'Личный водитель',
              '15-20 мин',
              '650₽',
              Icons.person,
              isSelected: _selectedTariff == 'Личный водитель',
            ),
            const SizedBox(height: 12),
            _buildTariffOption(
              'Срочная поездка',
              '5-8 мин',
              '850₽',
              Icons.local_taxi,
              isSelected: _selectedTariff == 'Срочная поездка',
            ),
            const SizedBox(height: 12),
            _buildTariffOption(
              'Женское такси',
              '15-20 мин',
              '550₽',
              Icons.woman,
              isSelected: _selectedTariff == 'Женское такси',
            ),
            if (_routeDistanceInMeters > 0)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Цена может меняться в зависимости от расстояния, времени, погоды и спроса',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
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

  // Опция тарифа
  Widget _buildTariffOption(
    String title,
    String time,
    String price,
    IconData icon, {
    bool isSelected = false,
  }) {
    // Если есть маршрут и текущий тариф совпадает с выбранным, используем динамическую цену
    String displayPrice = price;
    String displayTime = time;
    
    if (_routeDistanceInMeters > 0 && isSelected) {
      displayPrice = _currentPriceData['formattedPrice'] ?? price;
      displayTime = _currentPriceData['timeRange'] ?? time;
    } else if (_routeDistanceInMeters > 0) {
      // Для невыбранных тарифов тоже рассчитываем цену, но не сохраняем в _currentPriceData
      final priceData = PriceCalculatorService.calculatePrice(
        tariffType: title,
        distanceInMeters: _routeDistanceInMeters,
        selectedServices: selectedServiceIds,
        rideTime: DateTime.now(),
        isHighDemand: _isHighDemand,
        isBadWeather: _isBadWeather,
        numberOfPassengers: _numberOfPassengers,
      );
      displayPrice = priceData['formattedPrice'] ?? price;
      displayTime = priceData['timeRange'] ?? time;
    }
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTariff = title;
          
          // Пересчитываем цену при смене тарифа, если есть маршрут
          if (_routeDistanceInMeters > 0) {
            _calculatePrice(_routeDistanceInMeters);
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.lightGrey : AppColors.white,
          border: Border.all(
            color: isSelected ? AppColors.lightGrey : AppColors.accent,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontFamily: 'Rubik'),
                ),
                const SizedBox(height: 4),
                Text(
                  displayTime,
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: 'Rubik',
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  displayPrice,
                  style: const TextStyle(fontSize: 16, fontFamily: 'Rubik', fontWeight: FontWeight.w500),
                ),
                if (_isHighDemand)
                  Text(
                    'Высокий спрос',
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'Rubik',
                      color: Colors.orange[700],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Секция способа оплаты
  Widget _buildPaymentSection() {
    return Container(
      margin: const EdgeInsets.only(left: 24, right: 24, top: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.accent,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Способ оплаты',
                  style: TextStyle(fontSize: 18, fontFamily: 'Rubik'),
                ),
                TextButton(
                  onPressed: _showPaymentMethodSelector,
                  child: Text(
                    'Изменить',
                    style: TextStyle(
                      fontSize: 16,
                      fontFamily: 'Rubik',
                      color: AppColors.secondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  _paymentMethod == 'Наличные' ? Icons.money : Icons.credit_card,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  _paymentMethod == 'Наличные' ? 'Наличными' : 'ЮКасса (Онлайн)',
                  style: const TextStyle(fontSize: 16, fontFamily: 'Rubik'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Показать селектор способа оплаты
  void _showPaymentMethodSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Выберите способ оплаты',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Rubik',
                ),
              ),
            ),
            _buildPaymentOption(
              title: 'Наличными',
              subtitle: 'Оплата водителю при получении',
              icon: Icons.money,
              value: 'Наличные',
              isSelected: _paymentMethod == 'Наличные',
            ),
            _buildPaymentOption(
              title: 'ЮКасса (Онлайн)',
              subtitle: 'Безопасная оплата картой через интернет',
              icon: Icons.credit_card,
              value: 'ЮКасса',
              isSelected: _paymentMethod == 'ЮКасса',
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Виджет опции оплаты
  Widget _buildPaymentOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required String value,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () {
        setState(() {
          _paymentMethod = value;
        });
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 4,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey[600],
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Rubik',
                      color: isSelected ? AppColors.primary : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'Rubik',
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: AppColors.primary,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  // Секция дополнительных услуг
  Widget _buildExtraServicesSection() {
    return Container(
      margin: const EdgeInsets.only(left: 24, right: 24, top: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.accent,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Доп. услуги',
                  style: TextStyle(fontSize: 18, fontFamily: 'Rubik'),
                ),
                TextButton(
                  onPressed: () {
                    _showExtraServicesModal(context);
                  },
                  child: Text(
                    'Изменить',
                    style: TextStyle(
                      fontSize: 16,
                      fontFamily: 'Rubik',
                      color: AppColors.secondary,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              'Выбрано: $selectedServicesCount услуги',
              style: TextStyle(
                fontSize: 16,
                fontFamily: 'Manrope',
                color: AppColors.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Модальное окно выбора дополнительных услуг
  void _showExtraServicesModal(BuildContext context) {
    // Создаем копию списка услуг для редактирования
    final tempServices = List<ExtraService>.from(_extraServices);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Container(
                width: 358,
                height: 690,
                child: Column(
                  children: [
                    // Заголовок и кнопка закрытия
                    Container(
                      height: 133,
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Color(0xFFF3F4F6),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Выберите дополнительные услуги',
                                  style: TextStyle(
                                    fontFamily: 'Manrope',
                                    fontSize: 20,
                                    fontWeight: FontWeight.w400,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Выбрано: ${tempServices.where((s) => s.isSelected).length} услуги',
                              style: const TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Список услуг
                    Container(
                      height: 400,
                      padding: const EdgeInsets.all(16),
                      child: ListView.builder(
                        itemCount: tempServices.length,
                        itemBuilder: (context, index) {
                          final service = tempServices[index];
                          
                          // Получаем надбавку к цене для услуги (для отображения)
                          String priceAddition = '';
                          switch (service.id) {
                            case 1: // Проводить до входа в квартиру / школу
                              priceAddition = '+15%';
                              break;
                            case 2: // Встретить ребенка у квартиры / подъезда
                              priceAddition = '+10%';
                              break;
                            case 3: // Водитель — мужчина
                            case 4: // Водитель — женщина
                              priceAddition = '+5%';
                              break;
                            case 5: // Детское автокресло
                              priceAddition = '+5%';
                              break;
                          }
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            height: 65,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                // Изображение (заглушка)
                                Container(
                                  margin: const EdgeInsets.only(left: 12),
                                  width: 53,
                                  height: 53,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text(
                                      service.image,
                                      style: const TextStyle(
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ),
                                ),

                                // Название услуги и надбавка к цене
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          service.name,
                                          style: const TextStyle(
                                            fontFamily: 'Manrope',
                                            fontSize: 13,
                                            fontWeight: FontWeight.w400,
                                            color: Color(0xFF111827),
                                          ),
                                        ),
                                        if (priceAddition.isNotEmpty)
                                          Text(
                                            priceAddition,
                                            style: TextStyle(
                                              fontFamily: 'Manrope',
                                              fontSize: 12,
                                              fontWeight: FontWeight.w400,
                                              color: Colors.orange[700],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),

                                // Чекбокс
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      service.isSelected = !service.isSelected;
                                    });
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(right: 16),
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: service.isSelected
                                          ? AppColors.success
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(6),
                                      border: service.isSelected
                                          ? null
                                          : Border.all(
                                              color: AppColors.primary,
                                              width: 2,
                                            ),
                                    ),
                                    child: service.isSelected
                                        ? const Icon(
                                            Icons.check,
                                            size: 16,
                                            color: Colors.white,
                                          )
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    // Кнопки
                    Container(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          // Кнопка Применить
                          SizedBox(
                            width: 310,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: () {
                                // Сохраняем выбранные услуги
                                setState(() {
                                  _extraServices.clear();
                                  _extraServices.addAll(tempServices);
                                });
                                Navigator.of(context).pop();
                                
                                // Пересчитываем цену, если есть маршрут
                                if (_routeDistanceInMeters > 0) {
                                  _calculatePrice(_routeDistanceInMeters);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Применить',
                                style: TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Кнопка Отмена
                          SizedBox(
                            width: 310,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.success,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Отмена',
                                style: TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                  color: Color(0xFF111827),
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
          },
        );
      },
    ).then((_) {
      // Обновляем UI после закрытия модального окна
      setState(() {});
    });
  }

  // Секция комментария
  Widget _buildCommentSection() {
    return Container(
      margin: const EdgeInsets.only(left: 24, right: 24, top: 16),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Комментарий к заказу',
              style: TextStyle(fontSize: 18, fontFamily: 'Rubik'),
            ),
            IconButton(onPressed: () {}, icon: const Icon(Icons.edit)),
          ],
        ),
      ),
    );
  }

  // Кнопка заказа с учетом состояния
  Widget _buildOrderButton() {
    // Определяем доступность и текст кнопки в зависимости от состояния заказа
    bool isButtonEnabled = false;
    String buttonText = 'Заказать';
    Color buttonColor = AppColors.primary;
    VoidCallback? onPressed;
    
    switch (_orderState) {
      case 'idle':
        // Начальное состояние - можно заказать, если есть маршрут
        isButtonEnabled = _startPoint != null && _endPoint != null;
        buttonText = isButtonEnabled 
          ? 'Заказать за ${_currentPriceData['formattedPrice'] ?? '450₽'}'
          : 'Заказать';
        onPressed = isButtonEnabled ? _placeOrder : null;
        break;
        
      case 'waiting':
        // Ожидание водителя - можно отменить заказ
        isButtonEnabled = true;
        buttonText = 'Отменить заказ';
        buttonColor = Colors.red;
        onPressed = _cancelOrder;
        break;
        
      case 'driverAssigned':
        // Водитель назначен - можно позвонить или отменить
        isButtonEnabled = true;
        buttonText = 'Позвонить водителю';
        onPressed = _callDriver;
        break;
        
      case 'driverArrived':
        // Водитель прибыл - можно начать поездку
        isButtonEnabled = true;
        buttonText = 'Водитель прибыл';
        onPressed = _startRide;
        break;
        
      case 'inProgress':
        // Поездка началась - можно завершить поездку
        isButtonEnabled = true;
        buttonText = 'Завершить поездку';
        buttonColor = Colors.green;
        onPressed = () => _showRideCompletionDialog();
        break;
        
      case 'completed':
        // Поездка завершена - можно оценить
        isButtonEnabled = true;
        buttonText = 'Оценить поездку';
        onPressed = _rateRide;
        break;
    }
    
    return Container(
      margin: const EdgeInsets.only(left: 24, right: 24, top: 24),
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          disabledBackgroundColor: Colors.grey[400],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              buttonText,
              style: const TextStyle(
                fontSize: 18,
                color: AppColors.white,
                fontFamily: 'Manrope',
              ),
            ),
            if (_isHighDemand && _orderState == 'idle')
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange[700],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Высокий спрос',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontFamily: 'Manrope',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  // Методы для обработки действий в зависимости от состояния заказа
  
  // Размещение заказа
  void _placeOrder() async {
    // Создаем заказ в базе данных
    final orderId = await _supabaseService.createOrder(
      startAddress: _startLocationController.text,
      endAddress: _endLocationController.text,
      startLat: _startPoint?.latitude ?? 0,
      startLng: _startPoint?.longitude ?? 0,
      endLat: _endPoint?.latitude ?? 0,
      endLng: _endPoint?.longitude ?? 0,
      price: (_currentPriceData['price'] ?? 450).toDouble(),
      comment: '', // Можно добавить поле для комментария
      childCount: 0, // Можно добавить выбор количества детей
    );

    if (orderId != null) {
      _currentOrderId = orderId;
      debugPrint('Заказ создан с ID: $orderId');
      
      setState(() {
        _orderState = 'waiting';
      });
      
      // Показываем экран ожидания такси
      _showWaitingScreen();
      
      // Начинаем реальный поиск водителей
      _startDriverSearch();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ошибка создания заказа. Попробуйте еще раз.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // Поиск водителей с прогрессивным расширением радиуса
  void _startDriverSearch() async {
    if (_startPoint == null) return;
    
    // Начальный радиус поиска: 500м - 1км
    double searchRadius = 1000; // метры
    const double maxRadius = 3000; // максимальный радиус 3км
    const int searchTimeoutMinutes = 10; // время до расширения радиуса
    
    debugPrint('Начинаем поиск водителей в радиусе ${searchRadius}м');
    
    // Поиск водителей в текущем радиусе
    final drivers = await _searchDriversInRadius(searchRadius);
    
    if (drivers.isNotEmpty) {
      // Найдены водители - отправляем им уведомления о заказе
      _notifyDriversAboutOrder(drivers);
    } else {
      // Водители не найдены - запускаем таймер для расширения радиуса
      debugPrint('Водители в радиусе ${searchRadius}м не найдены. Запускаем таймер расширения.');
      
      Timer(Duration(minutes: searchTimeoutMinutes), () async {
        if (mounted && _orderState == 'waiting') {
          // Расширяем радиус поиска
          searchRadius = maxRadius;
          debugPrint('Расширяем радиус поиска до ${searchRadius}м');
          
          final expandedDrivers = await _searchDriversInRadius(searchRadius);
          
          if (expandedDrivers.isNotEmpty) {
            _notifyDriversAboutOrder(expandedDrivers);
          } else {
            // Даже в расширенном радиусе водители не найдены
            _handleNoDriversFound();
          }
        }
      });
    }
  }
  
  // Поиск водителей в указанном радиусе
  Future<List<Map<String, dynamic>>> _searchDriversInRadius(double radiusMeters) async {
    if (_startPoint == null) return [];
    
    try {
      // Используем Supabase для поиска активных водителей в радиусе
      final drivers = await _supabaseService.searchNearbyDrivers(
        latitude: _startPoint!.latitude,
        longitude: _startPoint!.longitude,
        radiusMeters: radiusMeters,
      );
      
      debugPrint('Найдено ${drivers.length} водителей в радиусе ${radiusMeters}м');
      return drivers;
    } catch (e) {
      debugPrint('Ошибка поиска водителей: $e');
      return [];
    }
  }
  
  // Уведомление водителей о новом заказе
  void _notifyDriversAboutOrder(List<Map<String, dynamic>> drivers) async {
    if (_currentOrderId == null) return;
    
    try {
      // Отправляем push-уведомления всем найденным водителям
      for (final driver in drivers) {
        await _supabaseService.sendOrderNotificationToDriver(
          driverId: driver['id'],
          orderId: _currentOrderId!,
          startAddress: _startLocationController.text,
          endAddress: _endLocationController.text,
          price: (_currentPriceData['price'] ?? 450).toDouble(),
        );
      }
      
      debugPrint('Уведомления отправлены ${drivers.length} водителям');
      
      // Запускаем мониторинг ответов водителей
      _monitorDriverResponses();
    } catch (e) {
      debugPrint('Ошибка отправки уведомлений водителям: $e');
    }
  }
  
  // Мониторинг ответов водителей
  void _monitorDriverResponses() {
    if (_currentOrderId == null) return;
    
    // Подписываемся на изменения статуса заказа
    _supabaseService.subscribeToOrderUpdates(_currentOrderId!, (orderData) {
      if (!mounted) return;
      
      if (orderData['status'] == 'driver_assigned' && orderData['driver_id'] != null) {
        // Водитель принял заказ
        _handleDriverAssigned(orderData);
      }
    });
    
    // Устанавливаем таймаут на ожидание ответа водителей (5 минут)
    Timer(const Duration(minutes: 5), () {
      if (mounted && _orderState == 'waiting') {
        // Если за 5 минут никто не откликнулся, показываем сообщение
        _handleNoDriverResponse();
      }
    });
  }
  
  // Обработка назначения водителя
  void _handleDriverAssigned(Map<String, dynamic> orderData) async {
    if (!mounted) return;
    
    setState(() {
      _orderState = 'driverAssigned';
    });
    
    // Получаем информацию о водителе
    final driverInfo = await _supabaseService.getDriverInfo(orderData['driver_id']);
    
    if (driverInfo != null) {
      _driverInfo = driverInfo;
      
      // Закрываем экран ожидания
      Navigator.of(context).pop();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Водитель ${driverInfo['name'] ?? 'Неизвестный'} принял ваш заказ!'),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.green,
        ),
      );
      
      // Показываем диалог с информацией о водителе
      _showDriverInfoDialog();
    }
  }
  
  // Обработка отсутствия ответа от водителей
  void _handleNoDriverResponse() {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Водители временно недоступны. Попробуйте позже или измените маршрут.'),
        duration: Duration(seconds: 5),
        backgroundColor: Colors.orange,
      ),
    );
  }
  
  // Обработка случая, когда водители не найдены
  void _handleNoDriversFound() {
    if (!mounted) return;
    
    // Автоматически отменяем заказ
    setState(() {
      _orderState = 'idle';
    });
    
    // Закрываем экран ожидания
    Navigator.of(context).pop();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('В данный момент нет доступных водителей в вашем районе. Попробуйте позже.'),
        duration: Duration(seconds: 5),
        backgroundColor: Colors.red,
      ),
    );
  }
  
  // Отмена заказа
  void _cancelOrder() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Отменить заказ?'),
        content: const Text('Вы уверены, что хотите отменить заказ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Нет'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _orderState = 'idle';
              });
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Заказ отменен'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Да'),
          ),
        ],
      ),
    );
  }
  
  // Звонок водителю
  void _callDriver() {
    _showCallScreen();
  }
  
  // Начало поездки
  void _startRide() {
    setState(() {
      _orderState = 'inProgress';
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Поездка началась'),
        duration: Duration(seconds: 2),
      ),
    );
    
    // Убираем автоматическое завершение - пользователь сам нажмет кнопку
  }
  
  // Открытие чата
  void _openChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(chatId: 'your-chat-id', userId: 'your-user-id'),
      ),
    );
  }
  
  // Диалог завершения поездки
  void _showRideCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Поездка завершена'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'Стоимость поездки: ${_currentPriceData['formattedPrice'] ?? '450₽'}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'Способ оплаты: $_paymentMethod',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _completeRide();
            },
            child: const Text('Завершить поездку'),
          ),
        ],
      ),
    );
  }

  // Завершение поездки и начисление баллов
  void _completeRide() async {
    // Обновляем статус заказа в базе данных
    if (_currentOrderId != null) {
      final success = await _supabaseService.updateOrderStatus(
        orderId: _currentOrderId!,
        status: 'completed',
        completedAt: DateTime.now(),
      );
      
      if (success) {
        debugPrint('Статус заказа $_currentOrderId обновлен на completed');
      } else {
        debugPrint('Ошибка обновления статуса заказа $_currentOrderId');
      }
    }

    setState(() {
      _orderState = 'completed';
    });

    // Начисляем баллы за поездку
    _awardLoyaltyPoints();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Поездка завершена! Баллы начислены'),
        duration: Duration(seconds: 3),
        backgroundColor: Colors.green,
      ),
    );

    // Показываем диалог оценки через 2 секунды
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _showRatingDialog();
      }
    });
  }

  // Начисление баллов лояльности
  void _awardLoyaltyPoints() {
    // Рассчитываем баллы: 1 балл за каждые 100 рублей
    final price = _currentPriceData['price'] ?? 450;
    final points = (price / 100).floor();
    
    // Добавляем баллы через сервис
    _supabaseService.addLoyaltyPoints(
      points: points, 
      description: 'Поездка завершена'
    );
    
    debugPrint('Начислено $points баллов за поездку на сумму ${price}₽');
  }

  // Оценка поездки
  void _rateRide() {
    _showRatingDialog();
  }

  // Инициализация карты
  Future<void> _initializeMap() async {
    try {
      // Проверяем и запрашиваем разрешения на местоположение
      await _requestLocationPermission();
      
    setState(() {
      _isMapInitialized = true;
      });
      
      // Добавляем небольшую задержку для гарантированной инициализации карты
      await Future.delayed(const Duration(milliseconds: 500));
      
      setState(() {
      _mapReady = true;
    });
      
      // После инициализации карты, пытаемся получить текущее местоположение
      await _moveToCurrentLocation();
    } catch (e) {
      debugPrint('Ошибка при инициализации карты: $e');
    }
  }

  Future<void> _fetchSuggestions(String query, {required bool isStart}) async {
    if (query.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    
    try {
      // Используем улучшенный метод из MapService для получения подсказок
      final items = await MapService.getSuggestions(query);
      
      setState(() {
        _suggestions = items;
        _isSuggestingStart = isStart;
      });
      
      // Выводим информацию о найденных подсказках для отладки
      if (items.isNotEmpty) {
        debugPrint('Найдено ${items.length} подсказок по запросу "$query"');
      } else {
        debugPrint('Не найдено подсказок по запросу "$query"');
      }
    } catch (e) {
      debugPrint('Ошибка при получении подсказок: $e');
      setState(() => _suggestions = []);
    }
  }

  void _onSuggestionTap(SuggestItem item) {
    // Формируем полный адрес из подсказки
    final address = item.title + (item.subtitle != null ? ', ${item.subtitle}' : '');
    
    // Устанавливаем адрес в поле ввода
    if (_isSuggestingStart) {
      _startLocationController.text = address;
      // Ищем и устанавливаем маркер для начальной точки
      _searchAndMark(address, isStart: true, suggestItem: item);
    } else {
      _endLocationController.text = address;
      // Ищем и устанавливаем маркер для конечной точки
      _searchAndMark(address, isStart: false, suggestItem: item);
    }
    
    // Скрываем список подсказок
    setState(() => _suggestions = []);
    
    // Показываем индикатор загрузки
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Поиск выбранного адреса...'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _searchAndMark(String address, {
    required bool isStart, 
    SuggestItem? suggestItem
  }) async {
    if (address.isEmpty) return;
    
    // Показываем индикатор загрузки
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Поиск адреса...'), duration: Duration(seconds: 1)),
    );

    try {
      debugPrint('Поиск адреса: $address');
      
      // Используем улучшенный метод из MapService для поиска адреса
      final items = await MapService.searchAddressByText(address);

      if (items.isNotEmpty) {
        debugPrint('Найдено результатов: ${items.length}');
        
        // Пробуем получить точку из первого результата
        Point? point;
        String? displayName;
        
        try {
          final firstItem = items.first;
          displayName = firstItem.name;
          
          // Проверяем различные типы геометрии
          if (firstItem.geometry is Point) {
            point = firstItem.geometry as Point;
            debugPrint('Найдена точка: ${point.latitude},${point.longitude}, имя: $displayName');
          } else if (firstItem.geometry is BoundingBox) {
            // Если результат - область, берем её центр
            final boundingBox = firstItem.geometry as BoundingBox;
            final centerLat = (boundingBox.northEast.latitude + boundingBox.southWest.latitude) / 2;
            final centerLon = (boundingBox.northEast.longitude + boundingBox.southWest.longitude) / 2;
            point = Point(latitude: centerLat, longitude: centerLon);
            debugPrint('Найдена область, используем центр: ${point.latitude},${point.longitude}, имя: $displayName');
          } else {
            // Попытка использовать suggestItem если он есть
            if (suggestItem != null && suggestItem.center != null) {
              point = suggestItem.center!;
              debugPrint('Используем центр из suggestItem: ${point.latitude},${point.longitude}');
            } else {
              debugPrint('Неизвестный тип геометрии: ${firstItem.geometry.runtimeType}');
            }
          }
        } catch (e) {
          debugPrint('Ошибка при получении точки: $e');
          
          // Попытка использовать suggestItem как запасной вариант
          if (suggestItem != null && suggestItem.center != null) {
            point = suggestItem.center!;
            displayName = suggestItem.title;
            debugPrint('Используем запасной вариант из suggestItem: ${point.latitude},${point.longitude}');
          }
        }

        if (point != null) {
          // Создаем копию точки для безопасного использования
          final safePoint = Point(latitude: point.latitude, longitude: point.longitude);

          // Проверяем, находится ли точка в пределах поддерживаемых регионов СНГ
          final detectedCity = MapService.detectCityByPoint(safePoint);
          if (detectedCity == null) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Такси доступно только в регионах СНГ'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }
          
          // Если пользователь находится в другом городе, предлагаем переключиться
          final currentUserCity = MapService.getCurrentUserCity();
          if (detectedCity != currentUserCity) {
            if (context.mounted) {
              final shouldSwitch = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Смена города'),
                  content: Text('Вы находитесь в городе $detectedCity. Переключиться на этот город?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Отмена'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Переключить'),
                    ),
                  ],
                ),
              );
              
              if (shouldSwitch == true) {
                MapService.setCurrentUserCity(detectedCity);
                // Обновляем карту для нового города
                _moveToCurrentCity();
              }
            }
          }

          setState(() {
            _placemarks.removeWhere((p) => p.mapId.value == (isStart ? 'start' : 'end'));
            _placemarks.add(
              _createBetterVisibleMarker(
                id: isStart ? 'start' : 'end',
                point: safePoint,
                isStart: isStart,
              ),
            );

            if (isStart) {
              _startPoint = safePoint;
              // Используем полное название из результатов поиска
              _startLocationController.text = displayName ?? address;
            } else {
              _endPoint = safePoint;
              // Используем полное название из результатов поиска
              _endLocationController.text = displayName ?? address;
            }
          });

          // Плавно перемещаем камеру на найденную точку с анимацией
          await _mapController?.moveCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: safePoint, zoom: 16),
            ),
            animation: const MapAnimation(type: MapAnimationType.smooth, duration: 1),
          );

          if (_startPoint != null && _endPoint != null) {
            // Небольшая задержка перед построением маршрута
            await Future.delayed(const Duration(milliseconds: 500));
            _buildRoute(_startPoint!, _endPoint!);
          }

          // Успешное добавление маркера
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Адрес найден'), duration: Duration(seconds: 2)),
          );

          return;
        } else {
          debugPrint('Точка не найдена в результатах поиска');
        }
      } else {
        debugPrint('Нет результатов поиска для адреса: $address');
        
        // Пробуем использовать подсказки, если поиск не дал результатов
        final suggestions = await MapService.getSuggestions(address);
        if (suggestions.isNotEmpty) {
          // Используем первую подсказку для поиска
          final suggestion = suggestions.first;
          final fullAddress = suggestion.title + (suggestion.subtitle != null ? ', ${suggestion.subtitle}' : '');
          
          debugPrint('Используем подсказку: $fullAddress');
          
          // Рекурсивно вызываем поиск с полным адресом из подсказки
          await _searchAndMark(fullAddress, isStart: isStart);
          return;
        }
      }

      // Если точка не найдена
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Адрес не найден. Попробуйте указать более точный адрес или отметьте точку на карте вручную.'),
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      // Обработка ошибок
      debugPrint('Ошибка при поиске адреса: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка поиска: $e')),
        );
      }
    }
  }

  Future<void> _buildRoute(Point start, Point end) async {
    try {
      // Показываем индикатор загрузки
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Построение маршрута...')),
      );
      
      debugPrint('Построение маршрута от ${start.latitude},${start.longitude} до ${end.latitude},${end.longitude}');
      
      final result = await YandexDriving.requestRoutes(
        points: [
          RequestPoint(point: start, requestPointType: RequestPointType.wayPoint),
          RequestPoint(point: end, requestPointType: RequestPointType.wayPoint)
        ],
        drivingOptions: const DrivingOptions(),
      );
      
      final sessionResult = await result.result;
      final routes = sessionResult.routes;
      
      if (routes != null && routes.isNotEmpty) {
        final route = routes.first;
        final distance = route.metadata.weight.distance.value;
        debugPrint('Маршрут успешно построен: ${route.geometry.length} точек, расстояние: $distance м');
        
        final polyline = PolylineMapObject(
          mapId: const MapObjectId('route'),
          polyline: Polyline(points: route.geometry),
          strokeColor: AppColors.primary,
          strokeWidth: 5,
        );
        
        setState(() {
          _routePolyline = polyline;
        });
        
        // Рассчитываем цену на основе расстояния
        if (distance != null && distance > 0) {
          _calculatePrice(distance.toDouble());
          
          // Показываем сообщение об успешном построении маршрута с ценой
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Маршрут построен. Расстояние: ${(distance / 1000).toStringAsFixed(1)} км. Стоимость: ${_currentPriceData['formattedPrice']}'),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } else {
          // Если расстояние не определено, используем приблизительное расстояние
          final approxDistance = PriceCalculatorService.calculateDistance(start, end);
          _calculatePrice(approxDistance);
          
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Маршрут построен. Приблизительная стоимость: ${_currentPriceData['formattedPrice']}'),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
        
        // Обновляем нижний бар для отображения актуальной цены
        _bottomSheetController.animateTo(
          _initialSheetSize,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        debugPrint('Не удалось построить маршрут: нет доступных маршрутов');
        
        // Показываем сообщение об ошибке
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Не удалось построить маршрут между указанными точками. Попробуйте выбрать другие точки.'),
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Ошибка при построении маршрута: $e');
      
      // Показываем сообщение об ошибке
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при построении маршрута: $e'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  List<MapObject> get _mapObjects {
    final objects = <MapObject>[];
    objects.addAll(_placemarks);
    if (_routePolyline != null) objects.add(_routePolyline!);
    return objects;
  }

  // Метод для активации режима установки маркера
  void _activateMarkerMode({required bool isStart}) {
    setState(() {
      _isMarkerModeActive = true;
      _isStartMarkerActive = isStart;
    });

    // Показываем подсказку пользователю
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isStart
            ? 'Нажмите на карту, чтобы установить точку отправления'
            : 'Нажмите на карту, чтобы установить точку назначения'),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Отмена',
          onPressed: () {
            setState(() {
              _isMarkerModeActive = false;
            });
          },
        ),
      ),
    );
  }

  // Метод для перемещения камеры на текущее местоположение
  Future<void> _moveToCurrentLocation() async {
    try {
      final position = await _locationService.getCurrentLocation();
      if (position != null && _mapController != null) {
        final point = Point(latitude: position.lat, longitude: position.long);

        await _mapController!.moveCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: point, zoom: 16),
          ),
          animation:
              const MapAnimation(type: MapAnimationType.smooth, duration: 1),
        );

        // Добавляем маркер текущего местоположения
        setState(() {
          _placemarks.removeWhere((p) => p.mapId.value == 'current_location');
          _placemarks.add(
            _createMapMarker(
              id: 'current_location',
              point: point,
              isStart: false,
            ),
          );
        });

        // Предлагаем установить эту точку как точку отправления
        if (_startPoint == null) {
          _showSetAsStartDialog(point);
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Не удалось определить текущее местоположение'),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
          ),
        );
      }
    }
  }

  // Диалог для установки текущего местоположения как точки отправления
  void _showSetAsStartDialog(Point point) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Использовать текущее местоположение?'),
          content: const Text(
              'Установить текущее местоположение как точку отправления?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _placemarks.removeWhere((p) => p.mapId.value == 'start');
                  _placemarks.add(
                    _createMapMarker(
                      id: 'start',
                      point: point,
                      isStart: true,
                    ),
                  );
                  _startPoint = point;
                  _startLocationController.text = 'Текущее местоположение';

                  // Если есть конечная точка, строим маршрут
                  if (_endPoint != null) {
                    _buildRoute(_startPoint!, _endPoint!);
                  }
                });
                Navigator.of(context).pop();
              },
              child: const Text('Да'),
            ),
          ],
        );
      },
    );
  }

  // Создание маркера на карте
  PlacemarkMapObject _createMapMarker({
    required String id,
    required Point point,
    required bool isStart,
  }) {
    // Используем разные цвета для начальной и конечной точек
    final Color markerColor = isStart ? Colors.green : Colors.red;
    final String markerText = isStart ? 'A' : 'B';

    return PlacemarkMapObject(
      mapId: MapObjectId(id),
      point: point,
      opacity: 1.0,
      icon: PlacemarkIcon.single(
        PlacemarkIconStyle(
          image: BitmapDescriptor.fromAssetImage('assets/icons/marker_${isStart ? 'start' : 'end'}.svg'),
          scale: 1.0,
          anchor: const Offset(0.5, 1.0), // Якорь внизу по центру как у каплевидного маркера
        ),
      ),
      isDraggable: true,
      onDragStart: (_) {
        // Обработка начала перетаскивания
        if (isStart) {
          _startLocationController.text = 'Перемещение маркера...';
        } else {
          _endLocationController.text = 'Перемещение маркера...';
        }
      },
      onDrag: (_, Point newPoint) {
        // Обновляем позицию точки при перетаскивании
        if (id == 'start') {
          _startPoint = newPoint;
        } else if (id == 'end') {
          _endPoint = newPoint;
        }
      },
      onDragEnd: (_) {
        // Обработка окончания перетаскивания
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Точка ${id == 'start' ? 'отправления' : 'назначения'} перемещена'),
            duration: const Duration(seconds: 1),
          ),
        );
        
        // Получаем текущую точку после перемещения
        final currentPoint = id == 'start' ? _startPoint! : _endPoint!;
        
        // Обновляем адрес после перемещения маркера
        _setAddressFromPoint(point: currentPoint, isStart: id == 'start');
        
        // Если есть обе точки, обновляем маршрут
        if (_startPoint != null && _endPoint != null) {
          _buildRoute(_startPoint!, _endPoint!);
        }
      },
      text: PlacemarkText(
        text: markerText,
        style: const PlacemarkTextStyle(
          color: Colors.white,
          size: 14.0,
        ),
      ),
    );
  }

  // Генерация каплевидного маркера как на Google Maps
  Uint8List _generateMapMarker(Color color, String text) {
    // Создаем простой битмап для маркера в стиле Google Maps
    // В реальном приложении здесь должен быть код для создания каплевидного маркера
    // с буквой внутри, но для демонстрации используем стандартный подход
    return Uint8List(0);
  }

  // Метод для создания более заметного маркера
  PlacemarkMapObject _createBetterVisibleMarker({
    required String id,
    required Point point,
    required bool isStart,
  }) {
    // Используем разные цвета для начальной и конечной точек
    final Color markerColor = isStart ? Colors.green : Colors.red;
    final String markerText = isStart ? 'A' : 'B';
    
    // Создаем более заметный маркер с большим размером и текстом
    return PlacemarkMapObject(
      mapId: MapObjectId(id),
      point: point,
      opacity: 1.0,
             icon: PlacemarkIcon.single(
        PlacemarkIconStyle(
          image: BitmapDescriptor.fromAssetImage('assets/images/logo.png'),
          scale: 3.0, // Увеличиваем размер маркера для лучшей видимости
        ),
      ),
      isDraggable: true,
      onDragStart: (_) {
        // Обработка начала перетаскивания
        if (isStart) {
          _startLocationController.text = 'Перемещение маркера...';
        } else {
          _endLocationController.text = 'Перемещение маркера...';
        }
      },
      onDrag: (_, Point newPoint) {
        // Обновляем позицию точки при перетаскивании
        if (id == 'start') {
          _startPoint = newPoint;
        } else if (id == 'end') {
          _endPoint = newPoint;
        }
      },
      onDragEnd: (_) {
        // Обработка окончания перетаскивания
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Точка ${id == 'start' ? 'отправления' : 'назначения'} перемещена'),
            duration: const Duration(seconds: 1),
          ),
        );
        
        // Получаем текущую точку после перемещения
        final currentPoint = id == 'start' ? _startPoint! : _endPoint!;
        
        // Обновляем адрес после перемещения маркера
        _setAddressFromPoint(point: currentPoint, isStart: id == 'start');
        
        // Если есть обе точки, обновляем маршрут
        if (_startPoint != null && _endPoint != null) {
          _buildRoute(_startPoint!, _endPoint!);
        }
      },
      text: PlacemarkText(
        text: markerText,
        style: const PlacemarkTextStyle(
          color: Colors.white,
          size: 16.0,
        ),
      ),
    );
  }

  Future<void> _setAddressFromPoint(
      {required Point point, required bool isStart}) async {
    try {
      setState(() {
        if (isStart) {
          _startLocationController.text = 'Определение адреса...';
        } else {
          _endLocationController.text = 'Определение адреса...';
        }
      });
      
      // Используем улучшенный метод из MapService для получения адреса
      final address = await MapService.getAddressByPoint(point);
      
      if (address != null && address.isNotEmpty) {
        debugPrint('Получен адрес для точки ${point.latitude},${point.longitude}: $address');
        
        setState(() {
          if (isStart) {
            _startLocationController.text = address;
          } else {
            _endLocationController.text = address;
          }
        });
      } else {
        debugPrint('Не удалось получить адрес для точки ${point.latitude},${point.longitude}');
        
        // Пробуем использовать альтернативный метод
        final fallbackAddress = await MapService.getAddressByCoordinates(point.latitude, point.longitude);
        
        setState(() {
          if (isStart) {
            _startLocationController.text = fallbackAddress ?? 'Адрес не найден';
          } else {
            _endLocationController.text = fallbackAddress ?? 'Адрес не найден';
          }
        });
      }
    } catch (e) {
      debugPrint('Ошибка при получении адреса: $e');
      setState(() {
        if (isStart) {
          _startLocationController.text = 'Ошибка определения адреса';
        } else {
          _endLocationController.text = 'Ошибка определения адреса';
        }
      });
    }
  }

  // Метод для отображения результатов поиска
  Widget _buildSuggestionsWidget() {
    if (_suggestions.isEmpty) return const SizedBox.shrink();
    
    return Positioned(
      top: 100,
      left: 24,
      right: 24,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
        child: Container(
          constraints: BoxConstraints(maxHeight: 300), // Ограничиваем высоту списка
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _suggestions.length,
            itemBuilder: (context, index) {
              final item = _suggestions[index];
              final String title = item.title;
              final String? subtitle = item.subtitle;
              
              return ListTile(
                leading: Icon(
                  _isSuggestingStart ? Icons.trip_origin : Icons.location_on,
                  color: _isSuggestingStart ? Colors.green : Colors.red,
                ),
                title: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: subtitle != null 
                  ? Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ) 
                  : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                onTap: () => _onSuggestionTap(item),
                // Добавляем разделитель между элементами
                trailing: index < _suggestions.length - 1
                  ? const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey)
                  : null,
              );
            },
          ),
        ),
      ),
    );
  }

  // Расчет цены на основе маршрута
  void _calculatePrice(double distanceInMeters) {
    if (distanceInMeters <= 0) {
      debugPrint('Ошибка: неверное расстояние для расчета цены');
      return;
    }
    
    setState(() {
      _routeDistanceInMeters = distanceInMeters;
      
      // Рассчитываем цену с учетом всех параметров
      _currentPriceData = PriceCalculatorService.calculatePrice(
        tariffType: _selectedTariff,
        distanceInMeters: distanceInMeters,
        selectedServices: selectedServiceIds,
        rideTime: DateTime.now(), // Используем текущее время для расчета
        isHighDemand: _isHighDemand,
        isBadWeather: _isBadWeather,
        numberOfPassengers: _numberOfPassengers,
      );
      
      debugPrint('Рассчитана цена: ${_currentPriceData['formattedPrice']} за ${_currentPriceData['distance'].toStringAsFixed(1)} км');
    });
  }

  // Показать диалог с информацией о водителе
  void _showDriverInfoDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Водитель в пути',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.grey[300],
                  child: Icon(Icons.person, size: 50, color: Colors.grey[700]),
                ),
                const SizedBox(height: 12),
                Text(
                  _driverInfo['name'] ?? 'Водитель',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
                Text(
                  'Рейтинг: ${_driverInfo['rating'] ?? '4.8'}',
                  style: TextStyle(fontSize: 16, color: Colors.amber[800]),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${_driverInfo['car'] ?? 'Автомобиль'} • ',
                      style: TextStyle(fontSize: 16),
                    ),
                    Text(
                      '${_driverInfo['carColor'] ?? 'Цвет'} • ',
                      style: TextStyle(fontSize: 16),
                    ),
                    Text(
                      _driverInfo['carNumber'] ?? 'Номер',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      children: [
                        Text(
                          'Прибытие через',
                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        ),
                        Text(
                          _driverInfo['estimatedArrival'] ?? '7 мин',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Text(
                          'Расстояние',
                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        ),
                        Text(
                          _driverInfo['distance'] ?? '2.3 км',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _callDriver();
                      },
                      icon: Icon(Icons.call, color: Colors.white),
                      label: Text('Позвонить'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _openChat();
                      },
                      icon: Icon(Icons.chat, color: Colors.white),
                      label: Text('Чат'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _cancelOrder();
                        },
                        icon: Icon(Icons.cancel, color: Colors.red),
                        label: Text('Отменить заказ', style: TextStyle(color: Colors.red)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          setState(() {
                            _orderState = 'driverArrived';
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Водитель прибыл! Можете начать поездку'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: Icon(Icons.directions_car, color: Colors.white),
                        label: Text('Водитель прибыл'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  // Показать экран звонка
  void _showCallScreen() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Звонок водителю',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey[300],
                  child: Icon(Icons.person, size: 60, color: Colors.grey[700]),
                ),
                const SizedBox(height: 16),
                Text(
                  _driverInfo['name'] ?? 'Водитель',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
                Text(
                  _driverInfo['phoneNumber'] ?? '+7 (999) 123-45-67',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      onPressed: () {},
                      icon: Icon(Icons.mic_off, size: 30),
                      color: Colors.grey[700],
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: CircleBorder(),
                        padding: EdgeInsets.all(20),
                      ),
                      child: Icon(Icons.call_end, color: Colors.white, size: 30),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: Icon(Icons.volume_up, size: 30),
                      color: Colors.grey[700],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  // Показать экран чата
  void _showChatScreen() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: double.maxFinite,
            height: 500,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.arrow_back),
                    ),
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.grey[300],
                      child: Icon(Icons.person, color: Colors.grey[700]),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _driverInfo['name'] ?? 'Водитель',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                        Text(
                          'В пути',
                          style: TextStyle(fontSize: 14, color: Colors.green),
                        ),
                      ],
                    ),
                  ],
                ),
                Divider(),
                Expanded(
                  child: ListView(
                    reverse: true,
                    children: [
                      _buildChatMessage('Здравствуйте! Я буду у вас через ${_driverInfo['estimatedArrival'] ?? '7 минут'}.', isDriver: true),
                      _buildChatMessage('Спасибо! Буду ждать.', isDriver: false),
                    ],
                  ),
                ),
                Divider(),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Введите сообщение...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      backgroundColor: AppColors.primary,
                      child: IconButton(
                        onPressed: () {},
                        icon: Icon(Icons.send, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  // Вспомогательный метод для создания сообщения в чате
  Widget _buildChatMessage(String message, {required bool isDriver}) {
    return Align(
      alignment: isDriver ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDriver ? Colors.grey[200] : AppColors.primary.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          message,
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }
  
  // Показать список недавних поездок
  void _showRecentTrips() async {
    try {
      // Получаем недавние поездки пользователя
      final recentOrders = await _supabaseService.getUserOrders(limit: 5);
      
      if (!mounted) return;
      
      if (recentOrders.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('У вас пока нет завершенных поездок'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }
      
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // Заголовок
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Недавние поездки',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Список поездок
              Expanded(
                child: ListView.builder(
                  itemCount: recentOrders.length,
                  itemBuilder: (context, index) {
                    final order = recentOrders[index];
                    return _buildRecentTripItem(order);
                  },
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      debugPrint('Ошибка загрузки недавних поездок: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ошибка загрузки недавних поездок'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Элемент недавней поездки
  Widget _buildRecentTripItem(OrderModel order) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Маршрут
          Row(
            children: [
              const Icon(Icons.trip_origin, color: Colors.green, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  order.startAddress,
                  style: const TextStyle(fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.red, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  order.endAddress,
                  style: const TextStyle(fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Информация о поездке
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.formattedCreatedAt,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    '${order.price.toInt()}₽',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              // Кнопка повторного заказа
              ElevatedButton(
                onPressed: () => _reorderTrip(order),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Повторить'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Повторный заказ поездки
  void _reorderTrip(OrderModel order) async {
    if (!mounted) return;
    
    Navigator.pop(context); // Закрываем модальное окно
    
    // Блокируем если есть активный заказ
    if (_orderState != 'idle') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Завершите текущий заказ перед созданием нового'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    
    try {
      // Устанавливаем адреса
      if (mounted) {
        setState(() {
          _startLocationController.text = order.startAddress;
          _endLocationController.text = order.endAddress;
          _startPoint = Point(latitude: order.startLat, longitude: order.startLng);
          _endPoint = Point(latitude: order.endLat, longitude: order.endLng);
        });
        
        // Очищаем старые маркеры и добавляем новые
        _placemarks.clear();
        _placemarks.add(_createMapMarker(
          id: 'start',
          point: _startPoint!,
          isStart: true,
        ));
        _placemarks.add(_createMapMarker(
          id: 'end',
          point: _endPoint!,
          isStart: false,
        ));
      }
      
      // Строим маршрут
      await _buildRoute(_startPoint!, _endPoint!);
      
      // Показываем уведомление
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Маршрут восстановлен. Можете заказать поездку!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
      
      // Перемещаем камеру к маршруту
      if (_mapController != null && mounted) {
        await _mapController!.moveCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: Point(
                latitude: (order.startLat + order.endLat) / 2,
                longitude: (order.startLng + order.endLng) / 2,
              ),
              zoom: 12,
            ),
          ),
        );
      }
      
    } catch (e) {
      debugPrint('Ошибка при восстановлении маршрута: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ошибка при восстановлении маршрута'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Показать диалог оценки поездки
  void _showRatingDialog() {
    double _rating = 5.0;
    String _comment = '';
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Оцените поездку',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              _rating = index + 1.0;
                            });
                          },
                          child: Icon(
                            Icons.star,
                            size: 32,
                            color: index < _rating ? Colors.amber : Colors.grey[300],
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      onChanged: (value) => _comment = value,
                      decoration: const InputDecoration(
                        hintText: 'Оставьте комментарий (необязательно)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _showDriverOfferDialog();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Отправить', style: TextStyle(fontSize: 16, color: Colors.white)),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _showDriverOfferDialog();
                      },
                      child: const Text('Пропустить'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Показать диалог предложения водителя как постоянного
  void _showDriverOfferDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                Icons.person_add,
                color: AppColors.primary,
                size: 24,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Предложить водителя',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Хотите предложить этого водителя как постоянного для вашего ребенка?',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9D3E2).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Постоянный водитель будет получать ваши запросы в первую очередь',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _completeRideAndReset();
              },
              child: Text(
                'Не сейчас',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _sendDriverConnectionRequest();
                _completeRideAndReset();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Предложить',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Завершить поездку и сбросить состояние
  void _completeRideAndReset() {
    if (mounted) {
      setState(() {
        _orderState = 'idle';
        _routePolyline = null;
        _placemarks.clear();
        _startPoint = null;
        _endPoint = null;
        _startLocationController.clear();
        _endLocationController.clear();
        _currentOrderId = null;
      });
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Поездка завершена'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // Отправить запрос на подключение водителя
  Future<void> _sendDriverConnectionRequest() async {
    try {
      final supabaseService = _supabaseService;
      final connectionService = DriverUserConnectionService();
      
      if (!supabaseService.isAuthenticated || supabaseService.currentUserId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ошибка: пользователь не авторизован'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Получаем ID текущего водителя из активного заказа
      // В реальном приложении это должно браться из данных заказа
      const driverId = 'current_driver_id'; // TODO: получить реальный ID водителя
      const driverFullName = 'Водитель'; // TODO: получить реальное имя водителя
      const userFullName = 'Пользователь'; // TODO: получить реальное имя пользователя
      
      final connection = await connectionService.createConnectionRequest(
        userId: supabaseService.currentUserId!,
        driverId: driverId,
        driverFullName: driverFullName,
        userFullName: userFullName,
      );
      
      if (connection != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Предложение отправлено водителю!'),
            backgroundColor: Color(0xFFA5C572),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось отправить предложение'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Ошибка отправки запроса на подключение водителя: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // Показать экран ожидания такси
  void _showWaitingScreen() {
    // Начальное время ожидания (будет динамически обновляться)
    int initialWaitingTime = _getInitialWaitingTime();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return WaitingForTaxiDialog(
          initialWaitingTime: initialWaitingTime,
          price: _currentPriceData['price'] ?? 450,
          formattedPrice: _currentPriceData['formattedPrice'] ?? '450₽',
          startAddress: _startLocationController.text,
          endAddress: _endLocationController.text,
          onCancel: () {
            Navigator.of(context).pop();
            _cancelOrder();
          },
          weatherCondition: _isBadWeather ? 'Плохая погода' : 'Хорошая погода',
          highDemand: _isHighDemand,
          startPoint: _startPoint,
          endPoint: _endPoint,
        );
      },
    );
  }
  
  // Получить начальное время ожидания на основе различных факторов
  int _getInitialWaitingTime() {
    // Базовое время ожидания в зависимости от времени суток
    final hour = DateTime.now().hour;
    int baseTime;
    
    if (hour >= 7 && hour <= 9) {
      // Утренний час пик
      baseTime = 8;
    } else if (hour >= 17 && hour <= 19) {
      // Вечерний час пик
      baseTime = 10;
    } else if (hour >= 22 || hour <= 6) {
      // Ночное время
      baseTime = 15;
    } else {
      // Обычное время
      baseTime = 5;
    }
    
    // Добавляем случайную вариацию ±2 минуты
    final random = Random();
    baseTime += random.nextInt(5) - 2;
    
    // Минимальное время ожидания - 3 минуты
    return max(3, baseTime);
  }

}

// Класс для хранения дополнительных услуг
class ExtraService {
  final int id;
  final String name;
  bool isSelected;
  final String image;

  ExtraService({
    required this.id,
    required this.name,
    required this.isSelected,
    required this.image,
  });
}
