import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../services/user_schedule_service.dart';
import '../services/child_service.dart';
import 'package:mama_taxi/services/driver_user_connection_service.dart';
import 'package:mama_taxi/models/driver_user_connection.dart';
import 'package:mama_taxi/services/price_calculator_service.dart';
import 'package:mama_taxi/services/map_service.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';
import '../models/child_model.dart';
import '../models/user_schedule_model.dart';
import '../utils/constants.dart';

class AddScheduleScreen extends StatefulWidget {
  const AddScheduleScreen({Key? key}) : super(key: key);

  @override
  State<AddScheduleScreen> createState() => _AddScheduleScreenState();
}

class _AddScheduleScreenState extends State<AddScheduleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _startAddressController = TextEditingController();
  final _endAddressController = TextEditingController();
  double _calculatedPrice = 0.0;
  String _priceDisplay = 'Укажите адреса для расчета цены';
  
  // Для автокомплита адресов
  List<SuggestItem> _startSuggestions = [];
  List<SuggestItem> _endSuggestions = [];
  bool _showStartSuggestions = false;
  bool _showEndSuggestions = false;
  
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _isLoading = false;
  bool _isLoadingChildren = true;
  bool _isSearchingDrivers = false;
  
  List<Child> _children = [];
  Child? _selectedChild;
  String? _assignedDriverId;
  List<DriverUserConnection> _connectedDrivers = [];
  DriverUserConnection? _selectedDriver;

  @override
  void initState() {
    super.initState();
    _loadChildren();
    _loadConnectedDrivers();
  }

  Future<void> _loadChildren() async {
    setState(() {
      _isLoadingChildren = true;
    });
    
    try {
      final childService = ChildService();
      final supabaseService = Provider.of<SupabaseService>(context, listen: false);
      
      if (supabaseService.isAuthenticated && supabaseService.currentUserId != null) {
        final children = await childService.getUserChildren(supabaseService.currentUserId!);
        
        setState(() {
          _children = children;
          _isLoadingChildren = false;
        });
        
        debugPrint('Загружено детей: ${children.length}');
      } else {
        setState(() {
          _children = [];
          _isLoadingChildren = false;
        });
      }
    } catch (e) {
      debugPrint('Ошибка загрузки детей: $e');
      setState(() {
        _children = [];
        _isLoadingChildren = false;
      });
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

  // Расчет цены на основе адресов
  void _calculatePriceIfPossible() {
    final startAddress = _startAddressController.text.trim();
    final endAddress = _endAddressController.text.trim();
    
    if (startAddress.isEmpty || endAddress.isEmpty) {
      setState(() {
        _calculatedPrice = 0.0;
        _priceDisplay = 'Укажите адреса для расчета цены';
      });
      return;
    }
    
    // Для демонстрации используем примерные координаты
    final startPoint = Point(latitude: 55.7558, longitude: 37.6176);
    final endPoint = Point(latitude: 55.7558 + 0.01, longitude: 37.6176 + 0.01);
    
    // Рассчитываем расстояние
    final distance = PriceCalculatorService.calculateDistance(startPoint, endPoint);
    
    // Рассчитываем цену
    final priceData = PriceCalculatorService.calculatePrice(
      tariffType: 'Мама такси',
      distanceInMeters: distance,
      selectedServices: [],
      rideTime: DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _selectedTime.hour, _selectedTime.minute),
      isHighDemand: false,
      isBadWeather: false,
      numberOfPassengers: 1,
    );
    
    setState(() {
      _calculatedPrice = priceData['price'].toDouble();
      _priceDisplay = '₽${_calculatedPrice.toInt()}';
    });
  }
  
  // Методы для автокомплита адресов
  Future<void> _fetchStartSuggestions(String query) async {
    if (query.isEmpty) {
      setState(() {
        _startSuggestions = [];
        _showStartSuggestions = false;
      });
      return;
    }
    
    try {
      final suggestions = await MapService.getSuggestions(query);
      setState(() {
        _startSuggestions = suggestions;
        _showStartSuggestions = suggestions.isNotEmpty;
      });
    } catch (e) {
      debugPrint('Ошибка получения подсказок для начального адреса: $e');
    }
  }
  
  Future<void> _fetchEndSuggestions(String query) async {
    if (query.isEmpty) {
      setState(() {
        _endSuggestions = [];
        _showEndSuggestions = false;
      });
      return;
    }
    
    try {
      final suggestions = await MapService.getSuggestions(query);
      setState(() {
        _endSuggestions = suggestions;
        _showEndSuggestions = suggestions.isNotEmpty;
      });
    } catch (e) {
      debugPrint('Ошибка получения подсказок для конечного адреса: $e');
    }
  }

  // Сохранение поездки
  Future<void> _saveRide() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedChild == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Выберите ребенка для поездки'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userScheduleService = Provider.of<UserScheduleService>(context, listen: false);
      final supabaseService = Provider.of<SupabaseService>(context, listen: false);

      if (!supabaseService.isAuthenticated || supabaseService.currentUserId == null) {
        throw Exception('Пользователь не авторизован');
      }

      final scheduledDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      await userScheduleService.createScheduledRide(
        startAddress: _startAddressController.text.trim(),
        endAddress: _endAddressController.text.trim(),
        startLat: 55.7558,
        startLng: 37.6176,
        endLat: 55.7558 + 0.01,
        endLng: 37.6176 + 0.01,
        price: _calculatedPrice,
        scheduledDate: scheduledDateTime,
        childName: _selectedChild!.fullName,
        childAge: _selectedChild!.age,
        childPhotoUrl: _selectedChild!.photoUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Поездка успешно добавлена в расписание'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('Ошибка сохранения поездки: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка сохранения поездки: $e'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.05),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Добавить поездку',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Адрес отправления
              _buildSectionTitle('Откуда'),
              const SizedBox(height: 8),
              _buildAddressField(
                controller: _startAddressController,
                hintText: 'Введите адрес отправления',
                suggestions: _startSuggestions,
                showSuggestions: _showStartSuggestions,
                onChanged: _fetchStartSuggestions,
                onSuggestionSelected: (suggestion) {
                  _startAddressController.text = suggestion.displayText ?? '';
                  setState(() {
                    _showStartSuggestions = false;
                  });
                  _calculatePriceIfPossible();
                },
              ),
              
              const SizedBox(height: 24),
              
              // Адрес назначения
              _buildSectionTitle('Куда'),
              const SizedBox(height: 8),
              _buildAddressField(
                controller: _endAddressController,
                hintText: 'Введите адрес назначения',
                suggestions: _endSuggestions,
                showSuggestions: _showEndSuggestions,
                onChanged: _fetchEndSuggestions,
                onSuggestionSelected: (suggestion) {
                  _endAddressController.text = suggestion.displayText ?? '';
                  setState(() {
                    _showEndSuggestions = false;
                  });
                  _calculatePriceIfPossible();
                },
              ),
              
              const SizedBox(height: 24),
              
              // Дата и время
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('Дата'),
                        const SizedBox(height: 8),
                        _buildDateField(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('Время'),
                        const SizedBox(height: 8),
                        _buildTimeField(),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Выбор ребенка
              _buildSectionTitle('Ребенок'),
              const SizedBox(height: 8),
              _buildChildSelector(),
              
              const SizedBox(height: 24),
              
              // Выбор водителя
              if (_connectedDrivers.isNotEmpty) ...[
                _buildSectionTitle('Водитель'),
                const SizedBox(height: 8),
                _buildDriverSelector(),
                const SizedBox(height: 24),
              ],
              
              // Цена
              _buildPriceDisplay(),
              
              const SizedBox(height: 32),
              
              // Кнопка сохранения
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveRide,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Добавить поездку',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: 'Manrope',
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.black,
      ),
    );
  }

  Widget _buildAddressField({
    required TextEditingController controller,
    required String hintText,
    required List<SuggestItem> suggestions,
    required bool showSuggestions,
    required Function(String) onChanged,
    required Function(SuggestItem) onSuggestionSelected,
  }) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: TextFormField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
            onChanged: onChanged,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Это поле обязательно';
              }
              return null;
            },
          ),
        ),
        if (showSuggestions && suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: suggestions.length > 5 ? 5 : suggestions.length,
              itemBuilder: (context, index) {
                final suggestion = suggestions[index];
                return ListTile(
                  title: Text(
                    suggestion.displayText ?? '',
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 14,
                    ),
                  ),
                  onTap: () => onSuggestionSelected(suggestion),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildDateField() {
    return GestureDetector(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (date != null) {
          setState(() {
            _selectedDate = date;
          });
          _calculatePriceIfPossible();
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Text(
          DateFormat('dd.MM.yyyy').format(_selectedDate),
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 14,
            color: Colors.black,
          ),
        ),
      ),
    );
  }

  Widget _buildTimeField() {
    return GestureDetector(
      onTap: () async {
        final time = await showTimePicker(
          context: context,
          initialTime: _selectedTime,
        );
        if (time != null) {
          setState(() {
            _selectedTime = time;
          });
          _calculatePriceIfPossible();
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Text(
          _selectedTime.format(context),
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 14,
            color: Colors.black,
          ),
        ),
      ),
    );
  }

  Widget _buildChildSelector() {
    if (_isLoadingChildren) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_children.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Text(
          'Нет добавленных детей',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonFormField<Child>(
        value: _selectedChild,
        decoration: const InputDecoration(
          hintText: 'Выберите ребенка',
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(16),
        ),
        items: _children.map((child) {
          return DropdownMenuItem<Child>(
            value: child,
            child: Text(
              '${child.fullName}, ${child.age} лет',
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 14,
              ),
            ),
          );
        }).toList(),
        onChanged: (child) {
          setState(() {
            _selectedChild = child;
          });
        },
        validator: (value) {
          if (value == null) {
            return 'Выберите ребенка';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildDriverSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonFormField<DriverUserConnection>(
        value: _selectedDriver,
        decoration: const InputDecoration(
          hintText: 'Выберите водителя (опционально)',
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(16),
        ),
        items: _connectedDrivers.map((driver) {
          return DropdownMenuItem<DriverUserConnection>(
            value: driver,
            child: Text(
              driver.driverFullName.isNotEmpty ? driver.driverFullName : 'Водитель',
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 14,
              ),
            ),
          );
        }).toList(),
        onChanged: (driver) {
          setState(() {
            _selectedDriver = driver;
          });
        },
      ),
    );
  }

  Widget _buildPriceDisplay() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Стоимость поездки',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _priceDisplay,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _startAddressController.dispose();
    _endAddressController.dispose();
    super.dispose();
  }
}
