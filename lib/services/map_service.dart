import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';
import 'package:geocoding/geocoding.dart';
import 'cis_cities_service.dart';

class MapService {
  static final MapService _instance = MapService._internal();

  factory MapService() {
    return _instance;
  }

  MapService._internal();

  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  // API ключ Yandex MapKit
  static const String apiKey = '18fb32f9-5ace-46c2-a283-8c60c38131a0';

  // Текущий город пользователя (по умолчанию Москва)
  static String _currentUserCity = 'Москва';
  
  // Установить текущий город пользователя
  static void setCurrentUserCity(String cityName) {
    if (CISCitiesService.getCityInfo(cityName) != null) {
      _currentUserCity = cityName;
    }
  }
  
  // Получить текущий город пользователя
  static String getCurrentUserCity() {
    return _currentUserCity;
  }
  
  // Получить информацию о текущем городе
  static CityInfo? getCurrentCityInfo() {
    return CISCitiesService.getCityInfo(_currentUserCity);
  }
  
  // Получить ограничивающий прямоугольник для текущего города
  static BoundingBox getCurrentCityBoundingBox() {
    return CISCitiesService.getCityBoundingBox(_currentUserCity);
  }
  
  // Проверка, находится ли точка в пределах текущего города
  static bool isPointInCurrentCity(Point point) {
    final cityInfo = getCurrentCityInfo();
    if (cityInfo == null) return false;
    return CISCitiesService.isPointInCity(point, cityInfo);
  }
  
  // Определить город по координатам
  static String? detectCityByPoint(Point point) {
    // Сначала пытаемся найти конкретный город
    final city = CISCitiesService.getCityByPoint(point);
    if (city != null) {
      return city;
    }
    
    // Если конкретный город не найден, проверяем общие границы СНГ
    if (CISCitiesService.isPointInCIS(point)) {
      return 'Регион СНГ'; // Возвращаем общее название для поддерживаемого региона
    }
    
    return null; // Точка за пределами СНГ
  }

  // Улучшенный метод для поиска адреса по координатам с использованием Yandex Search
  static Future<String?> getAddressByPoint(Point point) async {
    try {
      // Определяем город по координатам
      final detectedCity = detectCityByPoint(point);
      if (detectedCity == null) {
        return 'Адрес за пределами поддерживаемых регионов СНГ';
      }
      
      final searchResult = await YandexSearch.searchByPoint(
        point: point,
        searchOptions: const SearchOptions(
          searchType: SearchType.geo,
          resultPageSize: 1,
        ),
      );
      
      final sessionResult = await searchResult.result;
      final items = sessionResult.items;
      
              if (items != null && items.isNotEmpty) {
          // Формируем читаемый адрес из доступных данных
          final item = items.first;
          String address = item.name;
          
          // Добавляем название города, если оно не указано в адресе
          if (!address.toLowerCase().contains(detectedCity.toLowerCase())) {
            address += ', $detectedCity';
          }
          
          return address;
        }
      
      // Если Yandex Search не дал результатов, используем geocoding пакет
      return getAddressByCoordinates(point.latitude, point.longitude);
    } catch (e) {
      debugPrint('Ошибка при получении адреса: $e');
      return getAddressByCoordinates(point.latitude, point.longitude);
    }
  }
  
  // Улучшенный метод для получения адреса по координатам с использованием geocoding пакета
  static Future<String?> getAddressByCoordinates(double latitude, double longitude) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        latitude, longitude,
        localeIdentifier: 'ru',
      );
      
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        
        // Формируем полный адрес из компонентов
        List<String> addressComponents = [];
        
        // Добавляем улицу и номер дома
        if (placemark.thoroughfare != null && placemark.thoroughfare!.isNotEmpty) {
          String streetAddress = placemark.thoroughfare!;
          
          if (placemark.subThoroughfare != null && placemark.subThoroughfare!.isNotEmpty) {
            streetAddress += ', ${placemark.subThoroughfare}';
          }
          
          addressComponents.add(streetAddress);
        } else if (placemark.street != null && placemark.street!.isNotEmpty) {
          String streetAddress = placemark.street!;
          
          if (placemark.name != null && placemark.name!.isNotEmpty && 
              placemark.name != placemark.street) {
            streetAddress += ', ${placemark.name}';
          }
          
          addressComponents.add(streetAddress);
        }
        
        // Добавляем район
        if (placemark.subLocality != null && placemark.subLocality!.isNotEmpty) {
          addressComponents.add(placemark.subLocality!);
        }
        
        // Добавляем город
        if (placemark.locality != null && placemark.locality!.isNotEmpty) {
          addressComponents.add(placemark.locality!);
        } else {
          // Определяем город по координатам
          final detectedCity = detectCityByPoint(Point(latitude: latitude, longitude: longitude));
          if (detectedCity != null) {
            addressComponents.add(detectedCity);
          } else {
            addressComponents.add('Неизвестный город');
          }
        }
        
        // Собираем адрес
        String address = addressComponents.join(', ');
        
        // Если адрес пустой, используем запасной вариант
        if (address.isEmpty) {
          List<String> fallbackComponents = [];
          
          if (placemark.name != null && placemark.name!.isNotEmpty) {
            fallbackComponents.add(placemark.name!);
          }
          
          if (placemark.administrativeArea != null && placemark.administrativeArea!.isNotEmpty) {
            fallbackComponents.add(placemark.administrativeArea!);
          }
          
          if (fallbackComponents.isEmpty) {
            final detectedCity = detectCityByPoint(Point(latitude: latitude, longitude: longitude));
            return '${detectedCity ?? 'Неизвестный город'}, координаты: $latitude, $longitude';
          } else {
            final detectedCity = detectCityByPoint(Point(latitude: latitude, longitude: longitude));
            return fallbackComponents.join(', ') + ', ${detectedCity ?? 'Неизвестный город'}';
          }
        }
        
        return address;
      }
      
      final detectedCity = detectCityByPoint(Point(latitude: latitude, longitude: longitude));
      return '${detectedCity ?? 'Неизвестный город'}, координаты: $latitude, $longitude';
    } catch (e) {
      debugPrint('Ошибка при получении адреса через geocoding: $e');
      final detectedCity = detectCityByPoint(Point(latitude: latitude, longitude: longitude));
      return '${detectedCity ?? 'Неизвестный город'}, координаты: $latitude, $longitude';
    }
  }

  // Поиск адресов по запросу с ограничением по текущему городу пользователя
  static Future<List<SearchItem>> searchAddressByText(String query) async {
    try {
      // Добавляем название текущего города к запросу, если не указан город
      String searchQuery = query;
      final currentCity = getCurrentUserCity();
      if (!searchQuery.toLowerCase().contains(currentCity.toLowerCase())) {
        searchQuery = '$searchQuery, $currentCity';
      }
      
      final searchResult = await YandexSearch.searchByText(
        searchText: searchQuery,
        geometry: Geometry.fromBoundingBox(getCurrentCityBoundingBox()),
        searchOptions: const SearchOptions(
          searchType: SearchType.geo,
          resultPageSize: 10,
        ),
      );

      final sessionResult = await searchResult.result;
      final items = sessionResult.items;
      
      if (items != null && items.isNotEmpty) {
        return items;
      }
      
      return [];
    } catch (e) {
      debugPrint('Ошибка при поиске адреса: $e');
      return [];
    }
  }

  // Получение подсказок по адресам с ограничением по текущему городу пользователя
  static Future<List<SuggestItem>> getSuggestions(String query) async {
    try {
      // Добавляем название текущего города к запросу, если не указан город
      String searchQuery = query;
      final currentCity = getCurrentUserCity();
      if (!searchQuery.toLowerCase().contains(currentCity.toLowerCase())) {
        searchQuery = '$searchQuery, $currentCity';
      }
      
      final session = YandexSuggest.getSuggestions(
        text: searchQuery,
        boundingBox: getCurrentCityBoundingBox(),
        suggestOptions: const SuggestOptions(
          suggestType: SuggestType.geo,
          suggestWords: true,
        ),
      );
      
      final result = await session.result;
      final items = result.items ?? [];
      
      return items;
    } catch (e) {
      debugPrint('Ошибка при получении подсказок: $e');
      return [];
    }
  }

  // Инициализация Yandex MapKit (разрешения теперь обрабатываются в MapScreen)
  Future<bool> initializeMapKit(BuildContext context) async {
    if (_isInitialized) {
      return true;
    }

    try {
      // Карта уже инициализирована в нативном коде, просто устанавливаем флаг
      debugPrint('Yandex MapKit готов к использованию');
      _isInitialized = true;
      return true;
    } catch (e) {
      debugPrint('Ошибка инициализации Yandex MapKit: $e');
      return false;
    }
  }

  // Проверка статуса разрешения на местоположение
  static Future<PermissionStatus> checkLocationPermission() async {
    return await Permission.location.status;
  }

  // Запрос разрешения на местоположение
  static Future<PermissionStatus> requestLocationPermission() async {
    return await Permission.location.request();
  }
}
