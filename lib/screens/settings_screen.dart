import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import '../services/supabase_service.dart';
import '../utils/constants.dart';
import '../models/user_model.dart';
import 'edit_profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  bool _isLoading = false;
  bool _isCacheLoading = false;
  String _cacheSize = "...";
  UserModel? _userProfile;
  int _supabaseCacheSize = 0;

  @override
  void initState() {
    super.initState();
    _loadCacheSize();
    _loadUserProfile();
    _loadSupabaseCacheSize();
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = await _supabaseService.getCurrentUser();
      setState(() {
        _userProfile = user;
      });
    } catch (e) {
      debugPrint('Ошибка при загрузке профиля: $e');
    }
  }


  Future<void> _loadSupabaseCacheSize() async {
    setState(() {
      _isCacheLoading = true;
    });

    try {
      final cacheSize = await _supabaseService.getCacheSize();
      setState(() {
        _supabaseCacheSize = cacheSize;
      });
    } catch (e) {
      debugPrint('Ошибка при получении размера кэша Supabase: $e');
    } finally {
      setState(() {
        _isCacheLoading = false;
      });
    }
  }

  Future<void> _loadCacheSize() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final cacheDir = await getTemporaryDirectory();
      final cacheSize = await _calculateDirectorySize(cacheDir);
      setState(() {
        _cacheSize = _formatSize(cacheSize + _supabaseCacheSize);
      });
    } catch (e) {
      debugPrint('Ошибка при расчете размера кеша: $e');
      setState(() {
        _cacheSize = "Ошибка";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<int> _calculateDirectorySize(Directory dir) async {
    int totalSize = 0;
    try {
      final List<FileSystemEntity> entities = await dir.list().toList();
      for (final entity in entities) {
        if (entity is File) {
          totalSize += await entity.length();
        } else if (entity is Directory) {
          totalSize += await _calculateDirectorySize(entity);
        }
      }
    } catch (e) {
      debugPrint('Ошибка при расчете размера директории: $e');
    }
    return totalSize;
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes Б';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} КБ';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} МБ';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} ГБ';
    }
  }

  Future<void> _clearCache() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Очистка локального кэша
      final cacheDir = await getTemporaryDirectory();
      if (await cacheDir.exists()) {
        await for (var entity in cacheDir.list()) {
          try {
            await entity.delete(recursive: true);
          } catch (e) {
            debugPrint('Не удалось удалить: $e');
          }
        }
      }

      // Очистка кэша в Supabase
      await _supabaseService.clearAllCache();

      // Обновляем размер кэша
      await _loadSupabaseCacheSize();
      await _loadCacheSize();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Кеш успешно очищен'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      debugPrint('Ошибка при очистке кеша: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ошибка при очистке кеша'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }


  void _navigateToEditProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(
          userProfile: _userProfile,
        ),
      ),
    );

    if (result == true) {
      // Профиль был обновлен, перезагружаем данные
      _loadUserProfile();
    }
  }

  void _navigateToPayments() {
    Navigator.pushNamed(context, '/payment');
  }

  void _navigateToSecurity() {
    Navigator.pushNamed(context, '/security');
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildProfileSection(),
            _buildSettingsOptions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 52,
      color: AppColors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: SvgPicture.asset(
                'assets/icons/arrow_back.svg',
                width: 12.5,
                height: 20,
              ),
            ),
            const SizedBox(width: 16),
            const Text(
              'Настройки',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: AppColors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSection() {
    return Container(
      color: AppColors.white,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Аватар пользователя (кликабельный)
          GestureDetector(
            onTap: _navigateToEditProfile,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.lightGrey,
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
                              'Ошибка загрузки аватарки в настройках: $error');
                          return const Icon(
                            Icons.person,
                            size: 40,
                            color: AppColors.grey,
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
                                color: AppColors.primary,
                              ),
                            ),
                          );
                        },
                      ),
                    )
                  : const Icon(
                      Icons.person,
                      size: 40,
                      color: AppColors.grey,
                    ),
            ),
          ),
          const SizedBox(width: 16),
          // Имя и телефон
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userProfile?.fullName ?? 'Имя не указано',
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    color: AppColors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _userProfile?.phone ?? 'Телефон не указан',
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: AppColors.darkGrey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsOptions() {
    return Expanded(
      child: Container(
        color: AppColors.white,
        margin: const EdgeInsets.only(top: 8),
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildSettingItem(
                icon: 'assets/icons/edit_profile.svg',
                title: 'Редактировать профиль',
                onTap: _navigateToEditProfile,
              ),
              _buildSettingItem(
                icon: 'assets/icons/payments.svg',
                title: 'Платежи и баланс',
                onTap: _navigateToPayments,
              ),
              _buildSettingItem(
                icon: 'assets/icons/security.svg',
                title: 'Безопасность',
                onTap: _navigateToSecurity,
              ),
              _buildSettingItem(
                icon: 'assets/icons/support.svg',
                title: 'Поддержка и информация',
                onTap: () {
                  Navigator.pushNamed(context, '/support');
                },
              ),
              const SizedBox(height: 8),
              _buildCacheClearSettingItem(),
              const SizedBox(height: 16),
              _buildLogoutButton(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required String icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppColors.lighterGrey,
              width: 1,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            SvgPicture.asset(
              icon,
              width: 16,
              height: 16,
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: AppColors.black,
              ),
            ),
            const Spacer(),
            SvgPicture.asset(
              'assets/icons/chevron_right.svg',
              width: 10,
              height: 16,
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildCacheClearSettingItem() {
    return InkWell(
      onTap: _isLoading ? null : _clearCache,
      child: Container(
        height: 56,
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppColors.lighterGrey,
              width: 1,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            SvgPicture.asset(
              'assets/icons/clear_cache.svg',
              width: 18,
              height: 16,
            ),
            const SizedBox(width: 16),
            const Text(
              'Очистка кеша',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: AppColors.black,
              ),
            ),
            const Spacer(),
            _isLoading || _isCacheLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                : Text(
                    _cacheSize,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: AppColors.grey,
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: TextButton(
        onPressed: () async {
          // Показываем диалог подтверждения
          final shouldLogout = await _showLogoutConfirmationDialog();
          if (shouldLogout) {
            await _supabaseService.signOut();
            if (mounted) {
              Navigator.of(context)
                  .pushNamedAndRemoveUntil('/login', (route) => false);
            }
          }
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'assets/icons/logout.svg',
              width: 16,
              height: 16,
              color: AppColors.error,
            ),
            const SizedBox(width: 8),
            const Text(
              'Выход из аккаунта',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: AppColors.error,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _showLogoutConfirmationDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Выход из аккаунта'),
              content: const Text('Вы уверены, что хотите выйти из аккаунта?'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                  child: const Text('Отмена'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                  child: const Text(
                    'Выйти',
                    style: TextStyle(color: AppColors.error),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;
  }
}
