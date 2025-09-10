import 'package:flutter/material.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';

class CISCitiesService {
  static final CISCitiesService _instance = CISCitiesService._internal();
  
  factory CISCitiesService() {
    return _instance;
  }
  
  CISCitiesService._internal();

  // Основные города СНГ с их координатами и границами
  static const Map<String, CityInfo> cisCities = {
    // Россия
    'Москва': CityInfo(
      name: 'Москва',
      country: 'Россия',
      center: Point(latitude: 55.751244, longitude: 37.618423),
      bounds: CityBounds(
        north: 56.2,  // Расширено для включения Московской области
        south: 55.3,
        east: 38.2,
        west: 37.0,
      ),
    ),
    'Санкт-Петербург': CityInfo(
      name: 'Санкт-Петербург',
      country: 'Россия',
      center: Point(latitude: 59.9311, longitude: 30.3609),
      bounds: CityBounds(
        north: 60.3,  // Расширено для включения Ленинградской области
        south: 59.5,
        east: 30.9,
        west: 29.8,
      ),
    ),
    'Новосибирск': CityInfo(
      name: 'Новосибирск',
      country: 'Россия',
      center: Point(latitude: 55.0084, longitude: 82.9357),
      bounds: CityBounds(
        north: 55.3,  // Расширено для агломерации
        south: 54.7,
        east: 83.4,
        west: 82.5,
      ),
    ),
    'Екатеринбург': CityInfo(
      name: 'Екатеринбург',
      country: 'Россия',
      center: Point(latitude: 56.8431, longitude: 60.6454),
      bounds: CityBounds(
        north: 57.1,  // Расширено для агломерации
        south: 56.5,
        east: 61.0,
        west: 60.2,
      ),
    ),
    'Казань': CityInfo(
      name: 'Казань',
      country: 'Россия',
      center: Point(latitude: 55.8304, longitude: 49.0661),
      bounds: CityBounds(
        north: 56.1,  // Расширено для агломерации
        south: 55.5,
        east: 49.5,
        west: 48.6,
      ),
    ),
    'Нижний Новгород': CityInfo(
      name: 'Нижний Новгород',
      country: 'Россия',
      center: Point(latitude: 56.2965, longitude: 43.9361),
      bounds: CityBounds(
        north: 56.6,  // Расширено для агломерации
        south: 56.0,
        east: 44.3,
        west: 43.5,
      ),
    ),
    
    // Украина
    'Киев': CityInfo(
      name: 'Киев',
      country: 'Украина',
      center: Point(latitude: 50.4501, longitude: 30.5234),
      bounds: CityBounds(
        north: 50.8,  // Расширено для Киевской области
        south: 50.1,
        east: 31.0,
        west: 30.0,
      ),
    ),
    'Харьков': CityInfo(
      name: 'Харьков',
      country: 'Украина',
      center: Point(latitude: 49.9935, longitude: 36.2304),
      bounds: CityBounds(
        north: 50.3,  // Расширено для агломерации
        south: 49.7,
        east: 36.6,
        west: 35.8,
      ),
    ),
    'Одесса': CityInfo(
      name: 'Одесса',
      country: 'Украина',
      center: Point(latitude: 46.4825, longitude: 30.7233),
      bounds: CityBounds(
        north: 46.8,  // Расширено для агломерации
        south: 46.2,
        east: 31.1,
        west: 30.3,
      ),
    ),
    
    // Беларусь
    'Минск': CityInfo(
      name: 'Минск',
      country: 'Беларусь',
      center: Point(latitude: 53.9006, longitude: 27.559),
      bounds: CityBounds(
        north: 54.2,  // Расширено для Минской области
        south: 53.6,
        east: 28.0,
        west: 27.1,
      ),
    ),
    
    // Казахстан
    'Алматы': CityInfo(
      name: 'Алматы',
      country: 'Казахстан',
      center: Point(latitude: 43.2220, longitude: 76.8512),
      bounds: CityBounds(
        north: 43.5,  // Расширено для агломерации
        south: 42.9,
        east: 77.3,
        west: 76.4,
      ),
    ),
    'Нур-Султан': CityInfo(
      name: 'Нур-Султан',
      country: 'Казахстан',
      center: Point(latitude: 51.1694, longitude: 71.4491),
      bounds: CityBounds(
        north: 51.4,  // Расширено для агломерации
        south: 50.9,
        east: 71.8,
        west: 71.1,
      ),
    ),
    
    // Узбекистан
    'Ташкент': CityInfo(
      name: 'Ташкент',
      country: 'Узбекистан',
      center: Point(latitude: 41.2995, longitude: 69.2401),
      bounds: CityBounds(
        north: 41.6,  // Расширено для агломерации
        south: 41.0,
        east: 69.6,
        west: 68.8,
      ),
    ),
    
    // Азербайджан
    'Баку': CityInfo(
      name: 'Баку',
      country: 'Азербайджан',
      center: Point(latitude: 40.4093, longitude: 49.8671),
      bounds: CityBounds(
        north: 40.7,  // Расширено для агломерации
        south: 40.1,
        east: 50.3,
        west: 49.4,
      ),
    ),
    
    // Армения
    'Ереван': CityInfo(
      name: 'Ереван',
      country: 'Армения',
      center: Point(latitude: 40.1792, longitude: 44.4991),
      bounds: CityBounds(
        north: 40.5,  // Расширено для агломерации
        south: 39.9,
        east: 44.9,
        west: 44.1,
      ),
    ),
    
    // Грузия
    'Тбилиси': CityInfo(
      name: 'Тбилиси',
      country: 'Грузия',
      center: Point(latitude: 41.7151, longitude: 44.8271),
      bounds: CityBounds(
        north: 42.0,  // Расширено для агломерации
        south: 41.4,
        east: 45.2,
        west: 44.4,
      ),
    ),
    
    // Молдова
    'Кишинев': CityInfo(
      name: 'Кишинев',
      country: 'Молдова',
      center: Point(latitude: 47.0105, longitude: 28.8638),
      bounds: CityBounds(
        north: 47.3,  // Расширено для агломерации
        south: 46.7,
        east: 29.2,
        west: 28.5,
      ),
    ),
    
    // Кыргызстан
    'Бишкек': CityInfo(
      name: 'Бишкек',
      country: 'Кыргызстан',
      center: Point(latitude: 42.8746, longitude: 74.5698),
      bounds: CityBounds(
        north: 43.2,  // Расширено для агломерации
        south: 42.5,
        east: 75.0,
        west: 74.1,
      ),
    ),
    
    // Таджикистан
    'Душанбе': CityInfo(
      name: 'Душанбе',
      country: 'Таджикистан',
      center: Point(latitude: 38.5598, longitude: 68.7870),
      bounds: CityBounds(
        north: 38.8,  // Расширено для агломерации
        south: 38.3,
        east: 69.1,
        west: 68.4,
      ),
    ),
    
    // Туркменистан
    'Ашхабад': CityInfo(
      name: 'Ашхабад',
      country: 'Туркменистан',
      center: Point(latitude: 37.9601, longitude: 58.3261),
      bounds: CityBounds(
        north: 38.3,  // Расширено для агломерации
        south: 37.6,
        east: 58.7,
        west: 57.9,
      ),
    ),
    
    // Дополнительные города России
    'Ростов-на-Дону': CityInfo(
      name: 'Ростов-на-Дону',
      country: 'Россия',
      center: Point(latitude: 47.2357, longitude: 39.7015),
      bounds: CityBounds(
        north: 47.5,
        south: 46.9,
        east: 40.0,
        west: 39.4,
      ),
    ),
    'Краснодар': CityInfo(
      name: 'Краснодар',
      country: 'Россия',
      center: Point(latitude: 45.0355, longitude: 38.9753),
      bounds: CityBounds(
        north: 45.3,
        south: 44.8,
        east: 39.3,
        west: 38.7,
      ),
    ),
    'Волгоград': CityInfo(
      name: 'Волгоград',
      country: 'Россия',
      center: Point(latitude: 48.7080, longitude: 44.5133),
      bounds: CityBounds(
        north: 49.0,
        south: 48.4,
        east: 44.8,
        west: 44.2,
      ),
    ),
    'Воронеж': CityInfo(
      name: 'Воронеж',
      country: 'Россия',
      center: Point(latitude: 51.6720, longitude: 39.1843),
      bounds: CityBounds(
        north: 52.0,
        south: 51.4,
        east: 39.5,
        west: 38.9,
      ),
    ),
    'Самара': CityInfo(
      name: 'Самара',
      country: 'Россия',
      center: Point(latitude: 53.2001, longitude: 50.1500),
      bounds: CityBounds(
        north: 53.5,
        south: 52.9,
        east: 50.5,
        west: 49.8,
      ),
    ),
    'Уфа': CityInfo(
      name: 'Уфа',
      country: 'Россия',
      center: Point(latitude: 54.7431, longitude: 55.9678),
      bounds: CityBounds(
        north: 55.0,
        south: 54.5,
        east: 56.3,
        west: 55.6,
      ),
    ),
    'Челябинск': CityInfo(
      name: 'Челябинск',
      country: 'Россия',
      center: Point(latitude: 55.1644, longitude: 61.4368),
      bounds: CityBounds(
        north: 55.4,
        south: 54.9,
        east: 61.7,
        west: 61.1,
      ),
    ),
    
    // Дополнительные города Украины
    'Днепр': CityInfo(
      name: 'Днепр',
      country: 'Украина',
      center: Point(latitude: 48.4647, longitude: 35.0462),
      bounds: CityBounds(
        north: 48.7,
        south: 48.2,
        east: 35.4,
        west: 34.7,
      ),
    ),
    'Львов': CityInfo(
      name: 'Львов',
      country: 'Украина',
      center: Point(latitude: 49.8397, longitude: 24.0297),
      bounds: CityBounds(
        north: 50.1,
        south: 49.6,
        east: 24.3,
        west: 23.7,
      ),
    ),
    
    // Дополнительные города Казахстана
    'Шымкент': CityInfo(
      name: 'Шымкент',
      country: 'Казахстан',
      center: Point(latitude: 42.3000, longitude: 69.5900),
      bounds: CityBounds(
        north: 42.6,
        south: 42.0,
        east: 69.9,
        west: 69.2,
      ),
    ),
  };

  // Определить город по координатам
  static String? getCityByPoint(Point point) {
    for (final entry in cisCities.entries) {
      final cityInfo = entry.value;
      if (isPointInCity(point, cityInfo)) {
        return entry.key;
      }
    }
    return null;
  }

  // Проверить, находится ли точка в пределах города (с дополнительным буфером)
  static bool isPointInCity(Point point, CityInfo cityInfo) {
    // Добавляем буфер 0.1 градуса (~11 км) для более мягкого определения
    const double buffer = 0.1;
    
    return point.latitude <= (cityInfo.bounds.north + buffer) && 
           point.latitude >= (cityInfo.bounds.south - buffer) && 
           point.longitude <= (cityInfo.bounds.east + buffer) && 
           point.longitude >= (cityInfo.bounds.west - buffer);
  }
  
  // Проверить, находится ли точка в любой стране СНГ (более широкая проверка)
  static bool isPointInCIS(Point point) {
    // Общие границы СНГ (приблизительно)
    const double northBound = 70.0;  // Северная граница России
    const double southBound = 35.0;  // Южная граница Туркменистана
    const double eastBound = 180.0;  // Восточная граница России
    const double westBound = 20.0;   // Западная граница Беларуси/Украины
    
    return point.latitude <= northBound && 
           point.latitude >= southBound && 
           point.longitude <= eastBound && 
           point.longitude >= westBound;
  }

  // Получить информацию о городе
  static CityInfo? getCityInfo(String cityName) {
    return cisCities[cityName];
  }

  // Получить список всех городов
  static List<String> getAllCities() {
    return cisCities.keys.toList();
  }

  // Получить города по стране
  static List<String> getCitiesByCountry(String country) {
    return cisCities.entries
        .where((entry) => entry.value.country == country)
        .map((entry) => entry.key)
        .toList();
  }

  // Получить ограничивающий прямоугольник для города
  static BoundingBox getCityBoundingBox(String cityName) {
    final cityInfo = cisCities[cityName];
    if (cityInfo == null) {
      throw ArgumentError('Город $cityName не найден');
    }
    
    return BoundingBox(
      northEast: Point(
        latitude: cityInfo.bounds.north,
        longitude: cityInfo.bounds.east,
      ),
      southWest: Point(
        latitude: cityInfo.bounds.south,
        longitude: cityInfo.bounds.west,
      ),
    );
  }

  // Получить все страны СНГ
  static List<String> getAllCountries() {
    return cisCities.values
        .map((cityInfo) => cityInfo.country)
        .toSet()
        .toList();
  }
}

// Класс для хранения информации о городе
class CityInfo {
  final String name;
  final String country;
  final Point center;
  final CityBounds bounds;

  const CityInfo({
    required this.name,
    required this.country,
    required this.center,
    required this.bounds,
  });
}

// Класс для хранения границ города
class CityBounds {
  final double north;
  final double south;
  final double east;
  final double west;

  const CityBounds({
    required this.north,
    required this.south,
    required this.east,
    required this.west,
  });
}
