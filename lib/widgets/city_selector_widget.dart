import 'package:flutter/material.dart';
import '../services/map_service.dart';
import '../services/cis_cities_service.dart';
import '../services/location_service.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';

class CitySelectorWidget extends StatefulWidget {
  final Function(String) onCityChanged;
  
  const CitySelectorWidget({
    Key? key,
    required this.onCityChanged,
  }) : super(key: key);

  @override
  State<CitySelectorWidget> createState() => _CitySelectorWidgetState();
}

class _CitySelectorWidgetState extends State<CitySelectorWidget> {
  String _currentCity = MapService.getCurrentUserCity();
  final LocationService _locationService = LocationService();
  bool _isDetectingLocation = false;
  
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _isDetectingLocation
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : GestureDetector(
                  onTap: _detectLocationAndCity,
                  child: const Icon(
                    Icons.my_location,
                    size: 20,
                    color: Color(0xFF5EC7C3),
                  ),
                ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _showCitySelector,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _currentCity,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.keyboard_arrow_down,
                  size: 20,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCitySelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey, width: 0.5),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Выберите город',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _buildCityList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCityList() {
    final countries = CISCitiesService.getAllCountries();
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: countries.length,
      itemBuilder: (context, index) {
        final country = countries[index];
        final cities = CISCitiesService.getCitiesByCountry(country);
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                country,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
            ...cities.map((city) => _buildCityItem(city)),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildCityItem(String city) {
    final isSelected = city == _currentCity;
    
    return ListTile(
      title: Text(
        city,
        style: TextStyle(
          fontSize: 16,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          color: isSelected ? const Color(0xFF5EC7C3) : Colors.black87,
        ),
      ),
      trailing: isSelected
          ? const Icon(
              Icons.check,
              color: Color(0xFF5EC7C3),
            )
          : null,
      onTap: () {
        if (city != _currentCity) {
          setState(() {
            _currentCity = city;
          });
          MapService.setCurrentUserCity(city);
          widget.onCityChanged(city);
        }
        Navigator.pop(context);
      },
    );
  }

  // Определение местоположения и города
  Future<void> _detectLocationAndCity() async {
    if (_isDetectingLocation) return;

    setState(() {
      _isDetectingLocation = true;
    });

    try {
      // Проверяем разрешения
      final hasPermission = await _locationService.checkPermission();
      if (!hasPermission) {
        final granted = await _locationService.requestPermission();
        if (!granted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Разрешение на геолокацию не предоставлено'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      final location = await _locationService.getCurrentLocation();
      if (location != null) {
        final point = Point(latitude: location.lat, longitude: location.long);
        final detectedCity = MapService.detectCityByPoint(point);
        
        if (detectedCity != null) {
          setState(() {
            _currentCity = detectedCity;
          });
          MapService.setCurrentUserCity(detectedCity);
          widget.onCityChanged(detectedCity);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Город определен: $detectedCity'),
                backgroundColor: const Color(0xFF5EC7C3),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Ваше местоположение находится за пределами поддерживаемых городов СНГ'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Не удалось определить местоположение'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка определения местоположения: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDetectingLocation = false;
        });
      }
    }
  }
}
