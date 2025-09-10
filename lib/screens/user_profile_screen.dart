import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../services/supabase_service.dart';
import '../models/user_model.dart';
import '../models/order_model.dart';
import '../models/child_model.dart';
import '../widgets/add_child_modal.dart' show AddChildModal, ChildWithFile;
import '../widgets/edit_child_modal.dart';
import 'edit_profile_screen.dart';
import 'loyalty_screen.dart';
import 'support_screen.dart';
import 'user_schedule_screen.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  UserModel? _userProfile;
  bool _isLoading = true;
  List<Child> _children = [];
  bool _isLoadingChildren = true;
  List<OrderModel> _recentOrders = [];
  bool _isLoadingOrders = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadChildren();
    _loadRecentOrders();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Обновляем данные при возврате на экран
    _refreshData();
  }

  // Метод для обновления всех данных
  Future<void> _refreshData() async {
    await Future.wait([
      _loadUserProfile(),
      _loadChildren(),
      _loadRecentOrders(),
    ]);
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = await _supabaseService.getCurrentUser();
      setState(() {
        _userProfile = user;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Ошибка загрузки профиля: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadChildren() async {
    try {
      final children = await _supabaseService.getChildren();
      setState(() {
        _children = children;
        _isLoadingChildren = false;
      });
    } catch (e) {
      debugPrint('Ошибка загрузки списка детей: $e');
      setState(() {
        _isLoadingChildren = false;
      });
    }
  }

  Future<void> _loadRecentOrders() async {
    try {
      final orders = await _supabaseService.getUserOrders(limit: 3);
      setState(() {
        _recentOrders = orders;
        _isLoadingOrders = false;
      });
    } catch (e) {
      debugPrint('Ошибка загрузки недавних поездок: $e');
      setState(() {
        _isLoadingOrders = false;
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
          : RefreshIndicator(
              onRefresh: _refreshData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Профиль пользователя
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(top: 16),
                    color: Colors.white,
                    child: Row(
                      children: [
                        // Аватар пользователя
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey[200],
                          ),
                          child: _userProfile?.avatarUrl != null &&
                                  _userProfile!.avatarUrl!.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(32),
                                  child: Image.network(
                                    _userProfile!.avatarUrl!,
                                    fit: BoxFit.cover,
                                    width: 64,
                                    height: 64,
                                    errorBuilder: (context, error, stackTrace) {
                                      debugPrint(
                                          'Ошибка загрузки аватарки в профиле: $error');
                                      return const Icon(
                                        Icons.person,
                                        size: 40,
                                        color: Colors.grey,
                                      );
                                    },
                                    loadingBuilder:
                                        (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return const Center(
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                )
                              : const Icon(
                                  Icons.person,
                                  size: 40,
                                  color: Colors.grey,
                                ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _userProfile?.fullName ?? 'Имя не указано',
                              style: const TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 18,
                                fontWeight: FontWeight.w400,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _userProfile?.phone ?? 'Телефон не указан',
                              style: const TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                            if (_userProfile?.city != null && _userProfile!.city!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on,
                                      size: 16,
                                      color: Color(0xFF6B7280),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _userProfile!.city!,
                                      style: const TextStyle(
                                        fontFamily: 'Manrope',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w400,
                                        color: Color(0xFF6B7280),
                                      ),
                                    ),
                                  ],
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
                                  userProfile: _userProfile,
                                ),
                              ),
                            ).then((result) {
                              // Если профиль был обновлен, перезагружаем данные
                              if (result == true) {
                                _loadUserProfile();
                              }
                            });
                          },
                          icon: const Icon(Icons.arrow_forward_ios, size: 16),
                        ),
                      ],
                    ),
                  ),

                  // Раздел действий
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 16),
                    padding: const EdgeInsets.all(16),
                    color: Colors.white,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildActionItem(
                            'Новая поездка',
                            Icons.directions_car,
                            AppColors.secondary,
                            () {
                              Navigator.of(
                                context,
                              ).pop(); // Возврат на экран карты
                            },
                          ),
                        ),
                        Expanded(
                          child: _buildActionItem(
                            'Расписание',
                            Icons.schedule,
                            AppColors.accent,
                            () {
                              // Открыть расписание
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const UserScheduleScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                        Expanded(
                          child: _buildActionItem(
                            'Оплата',
                            Icons.credit_card,
                            AppColors.secondary,
                            () {
                              // Открыть оплату
                            },
                          ),
                        ),
                        Expanded(
                          child: _buildActionItem(
                            'Лояльность',
                            Icons.stars,
                            AppColors.accent,
                            () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const LoyaltyScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Раздел детей
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 16),
                    padding: const EdgeInsets.all(16),
                    color: Colors.white,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Дети',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 18,
                            fontWeight: FontWeight.w400,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _isLoadingChildren
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            : SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        _showAddChildModal();
                                      },
                                      child: _buildChildAddItem(),
                                    ),
                                    ..._children.map(
                                      (child) => _buildChildItem(child),
                                    ),
                                  ],
                                ),
                              ),
                      ],
                    ),
                  ),

                  // Раздел недавних поездок
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 16),
                    padding: const EdgeInsets.all(16),
                    color: Colors.white,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Недавние поездки',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 18,
                            fontWeight: FontWeight.w400,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _isLoadingOrders
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            : _recentOrders.isEmpty
                                ? const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: Text(
                                        'У вас пока нет поездок',
                                        style: TextStyle(
                                          fontFamily: 'Manrope',
                                          fontSize: 16,
                                          fontWeight: FontWeight.w400,
                                          color: Color(0xFF6B7280),
                                        ),
                                      ),
                                    ),
                                  )
                                : Column(
                                    children: _recentOrders
                                        .asMap()
                                        .entries
                                        .map((entry) {
                                      final index = entry.key;
                                      final order = entry.value;
                                      return Column(
                                        children: [
                                          if (index > 0) const SizedBox(height: 16),
                                          _buildRideItem(
                                            '${order.startAddress} → ${order.endAddress}',
                                            order.formattedCreatedAt,
                                            '${order.price.toInt()}₽',
                                            order: order,
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                      ],
                    ),
                  ),

                  // Добавление пункта "Поддержка" в меню
                  ListTile(
                    leading: const Icon(Icons.help_outline),
                    title: const Text(
                      'Поддержка',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SupportScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                ],
                ),
              ),
            ),
    );
  }

  Widget _buildActionItem(
    String title,
    IconData icon,
    Color bgColor,
    VoidCallback onTap,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Icon(icon, size: 28, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 32,
          child: Text(
            title,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildChildAddItem() {
    return Container(
      margin: const EdgeInsets.only(right: 16),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(9999),
            ),
            child: const Icon(Icons.add, size: 24, color: Colors.black),
          ),
          const SizedBox(height: 8),
          const Text(
            'Добавить',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Color(0xFF6B7280),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildChildItem(Child child) {
    return Container(
      margin: const EdgeInsets.only(right: 16),
      child: GestureDetector(
        onLongPress: () {
          _showEditChildModal(child);
        },
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(9999),
              ),
              child: child.photoUrl != null && child.photoUrl!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(32),
                      child: Image.network(
                        child.photoUrl!,
                        fit: BoxFit.cover,
                        width: 64,
                        height: 64,
                        errorBuilder: (context, error, stackTrace) {
                          debugPrint('Ошибка загрузки фото ребенка: $error');
                          return Center(
                            child: Text(
                              child.fullName.isNotEmpty ? child.fullName[0] : '?',
                              style: const TextStyle(
                                fontSize: 24,
                                color: Colors.black,
                              ),
                            ),
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            ),
                          );
                        },
                      ),
                    )
                  : Center(
                      child: Text(
                        child.fullName.isNotEmpty ? child.fullName[0] : '?',
                        style: const TextStyle(
                          fontSize: 24,
                          color: Colors.black,
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            Text(
              child.fullName,
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Функция для сокращения адреса
  String _truncateAddress(String address, {int maxLength = 25}) {
    if (address.length <= maxLength) return address;
    return '${address.substring(0, maxLength)}...';
  }

  Widget _buildRideItem(String route, String time, String price, {OrderModel? order}) {
    // Разделяем маршрут на начальный и конечный адрес
    final addresses = route.split(' → ');
    final startAddress = addresses.isNotEmpty ? addresses[0] : '';
    final endAddress = addresses.length > 1 ? addresses[1] : '';
    
    // Сокращаем адреса
    final truncatedStart = _truncateAddress(startAddress);
    final truncatedEnd = _truncateAddress(endAddress);
    final truncatedRoute = '$truncatedStart → $truncatedEnd';
    
    return GestureDetector(
      onTap: () {
        // Показываем диалог с полной информацией о поездке
        _showRideDetailsDialog(route, time, price, order);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.lightGrey, width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.accentLight,
                borderRadius: BorderRadius.circular(9999),
              ),
              child: const Icon(
                Icons.directions_car,
                size: 20,
                color: Colors.black,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    truncatedRoute,
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: Colors.black,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    time,
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              price,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Диалог с деталями поездки
  void _showRideDetailsDialog(String fullRoute, String time, String price, OrderModel? order) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Детали поездки',
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
              const Text(
                'Маршрут:',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                fullRoute,
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Время:',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        Text(
                          time,
                          style: const TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Стоимость:',
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      Text(
                        price,
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.white,
              ),
              child: const Text(
                'Закрыть',
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

  // Открыть модальное окно добавления ребенка
  void _showAddChildModal() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AddChildModal(
          onAdd: (ChildWithFile childWithFile) async {
            // Создаем объект Child для Supabase
            final child = Child(
              id: childWithFile.id,
              userId: '', // Будет установлен в сервисе
              fullName: childWithFile.name,
              age: childWithFile.age,
              photoUrl: childWithFile.photoUrl,
              createdAt: DateTime.now(),
            );
            
            // Добавляем ребенка в Supabase
            final childId = await _supabaseService.addChild(child);
            if (childId != null) {
              // Обновляем список детей
              _loadChildren();
            }
          },
        );
      },
    );
  }

  // Открыть модальное окно редактирования ребенка
  void _showEditChildModal(Child child) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return EditChildModal(
          child: child,
          onUpdate: (Child updatedChild) async {
            try {
              // Обновляем данные ребенка в Supabase
              await _supabaseService.updateChild(updatedChild);
              // Обновляем список детей
              _loadChildren();
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Данные ребенка обновлены'),
                  backgroundColor: Colors.green,
                ),
              );
            } catch (e) {
              debugPrint('Ошибка обновления данных ребенка: $e');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Не удалось обновить данные ребенка'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          onDelete: (String childId) async {
            try {
              // Удаляем ребенка из Supabase
              await _supabaseService.deleteChild(childId);
              // Обновляем список детей
              _loadChildren();
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Ребенок удален'),
                  backgroundColor: Colors.orange,
                ),
              );
            } catch (e) {
              debugPrint('Ошибка удаления ребенка: $e');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Не удалось удалить ребенка'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
        );
      },
    );
  }
}
