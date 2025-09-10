import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/supabase_service.dart';
import '../models/user_model.dart';
import 'payment_screen.dart';

class EditProfileScreen extends StatefulWidget {
  final UserModel? userProfile;

  const EditProfileScreen({super.key, required this.userProfile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();

  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _birthDateController;

  String? _selectedGender;
  String _selectedCity = 'Москва';
  String? _emailError;
  bool _isLoading = false;
  File? _imageFile;
  String? _avatarUrl;
  
  // Для поиска городов
  final TextEditingController _cityController = TextEditingController();
  List<String> _filteredCities = [];
  bool _showCityDropdown = false;
  
  // Список городов РФ
  static const List<String> _russianCities = [
    'Москва', 'Санкт-Петербург', 'Новосибирск', 'Екатеринбург', 'Казань', 'Нижний Новгород',
    'Челябинск', 'Самара', 'Омск', 'Ростов-на-Дону', 'Уфа', 'Красноярск', 'Воронеж', 'Пермь',
    'Волгоград', 'Краснодар', 'Саратов', 'Тюмень', 'Тольятти', 'Ижевск', 'Барнаул', 'Ульяновск',
    'Иркутск', 'Хабаровск', 'Ярославль', 'Владивосток', 'Махачкала', 'Томск', 'Оренбург', 'Кемерово',
    'Новокузнецк', 'Рязань', 'Набережные Челны', 'Астрахань', 'Пенза', 'Липецк', 'Тула', 'Киров',
    'Чебоксары', 'Курск', 'Брянск', 'Магнитогорск', 'Иваново', 'Тверь', 'Ставрополь', 'Белгород',
    'Сочи', 'Нижний Тагил', 'Архангельск', 'Владимир', 'Калуга', 'Чита', 'Сургут', 'Смоленск',
    'Волжский', 'Курган', 'Орёл', 'Череповец', 'Вологда', 'Владикавказ', 'Мурманск', 'Саранск',
    'Якутск', 'Тамбов', 'Стерлитамак', 'Грозный', 'Кострома', 'Петрозаводск', 'Нижневартовск',
    'Йошкар-Ола', 'Новороссийск', 'Комсомольск-на-Амуре', 'Таганрог', 'Сыктывкар', 'Нальчик',
    'Шахты', 'Дзержинск', 'Орск', 'Ангарск', 'Балашиха', 'Благовещенск', 'Прокопьевск', 'Химки',
    'Псков', 'Бийск', 'Энгельс', 'Рыбинск', 'Балаково', 'Северодвинск', 'Армавир', 'Подольск',
    'Королёв', 'Сызрань', 'Норильск', 'Золотое кольцо', 'Каменск-Уральский', 'Волгодонск',
    'Абакан', 'Мытищи', 'Петропавловск-Камчатский', 'Альметьевск', 'Уссурийск', 'Березники',
    'Салават', 'Электросталь', 'Миасс', 'Первоуральск', 'Рубцовск', 'Коломна', 'Майкоп',
    'Ковров', 'Красногорск', 'Новочеркасск', 'Копейск', 'Железнодорожный', 'Хасавюрт',
    'Великий Новгород', 'Серпухов', 'Дербент', 'Орехово-Зуево', 'Димитровград', 'Камышин',
    'Невинномысск', 'Красноуфимск', 'Октябрьский', 'Ачинск', 'Северск', 'Новочебоксарск',
    'Каспийск', 'Зеленодольск', 'Батайск', 'Новошахтинск', 'Ноябрьск', 'Кызыл', 'Муром',
    'Елец', 'Артём', 'Новомосковск', 'Черкесск', 'Междуреченск', 'Сергиев Посад', 'Арзамас',
    'Жуковский', 'Ногинск', 'Новокуйбышевск', 'Елабуга', 'Евпатория', 'Кисловодск', 'Обнинск'
  ];

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: _getFirstName());
    _lastNameController = TextEditingController(text: _getLastName());
    _phoneController = TextEditingController(
      text: widget.userProfile?.phone ?? '',
    );
    _emailController = TextEditingController(
      text: widget.userProfile?.email ?? '',
    );
    _birthDateController = TextEditingController(
      text: widget.userProfile?.birthDate ?? '',
    );
    _selectedGender = widget.userProfile?.gender ?? 'Мужской';
    _avatarUrl = widget.userProfile?.avatarUrl;
    _selectedCity = widget.userProfile?.city ?? 'Москва';
    _cityController.text = _selectedCity;
    _filteredCities = [];
  }

  String _getFirstName() {
    final fullName = widget.userProfile?.fullName ?? '';
    if (fullName.contains(' ')) {
      return fullName.split(' ')[0];
    }
    return fullName;
  }

  String _getLastName() {
    final fullName = widget.userProfile?.fullName ?? '';
    if (fullName.contains(' ') && fullName.split(' ').length > 1) {
      return fullName.split(' ')[1];
    }
    return '';
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _birthDateController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 800,
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      debugPrint('Ошибка выбора изображения: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось выбрать изображение')),
        );
      }
    }
  }

  Future<void> _takePhoto() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 800,
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      debugPrint('Ошибка съемки фото: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось сделать фото')),
        );
      }
    }
  }

  Future<void> _showImageSourceActionSheet() async {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Выбрать из галереи'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage();
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Сделать фото'),
                onTap: () {
                  Navigator.pop(context);
                  _takePhoto();
                },
              ),
              if (_avatarUrl != null || _imageFile != null)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Удалить фото',
                      style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _imageFile = null;
                      _avatarUrl = null;
                    });
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        String? newAvatarUrl = _avatarUrl;

        // Загружаем новое изображение, если оно выбрано
        if (_imageFile != null) {
          newAvatarUrl =
              await _supabaseService.uploadImage(_imageFile!, 'avatars');
          if (newAvatarUrl == null) {
            // Если загрузка не удалась, показываем ошибку
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'Не удалось загрузить изображение. Проверьте настройки хранилища.'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            setState(() {
              _isLoading = false;
            });
            return;
          } else {
            // Если загрузка успешна, обновляем URL и сразу обновляем URL в профиле
            await _supabaseService.updateProfileImageUrl(newAvatarUrl);
          }
        }

        final updatedUser = UserModel(
          id: widget.userProfile?.id,
          fullName:
              '${_firstNameController.text} ${_lastNameController.text}'.trim(),
          email: _emailController.text,
          phone: _phoneController.text,
          avatarUrl: newAvatarUrl,
          role: widget.userProfile?.role ?? 'user',
          birthDate: _birthDateController.text,
          gender: _selectedGender,
          city: _selectedCity,
        );

        await _supabaseService.updateUserProfile(updatedUser);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Профиль успешно обновлен'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(
            context,
            true,
          ); // Возвращаем true, чтобы указать, что профиль был обновлен
        }
      } catch (e) {
        debugPrint('Ошибка обновления профиля: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка обновления профиля: $e'),
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
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      locale: const Locale('ru', 'RU'),
    );

    if (picked != null) {
      setState(() {
        _birthDateController.text =
            '${picked.day}.${picked.month}.${picked.year}';
      });
    }
  }

  void _filterCities(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredCities = _russianCities;
        _showCityDropdown = true;
      } else {
        _filteredCities = _russianCities
            .where((city) => city.toLowerCase().contains(query.toLowerCase()))
            .toList();
        _showCityDropdown = _filteredCities.isNotEmpty;
      }
    });
  }

  void _selectCity(String city) {
    setState(() {
      _selectedCity = city;
      _cityController.text = city;
      _showCityDropdown = false;
    });
  }

  Future<void> _showChangePasswordDialog() async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text(
                'Смена пароля',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: currentPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Текущий пароль',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Введите текущий пароль';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: newPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Новый пароль',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Введите новый пароль';
                        }
                        if (value.length < 6) {
                          return 'Пароль должен содержать минимум 6 символов';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: confirmPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Подтвердите новый пароль',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Подтвердите новый пароль';
                        }
                        if (value != newPasswordController.text) {
                          return 'Пароли не совпадают';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: isLoading ? null : () async {
                    if (formKey.currentState!.validate()) {
                      setState(() {
                        isLoading = true;
                      });

                      try {
                        final success = await _supabaseService.changePassword(
                          currentPassword: currentPasswordController.text,
                          newPassword: newPasswordController.text,
                        );

                        if (success) {
                          if (mounted) {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Пароль успешно изменен'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } else {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Неверный текущий пароль'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Ошибка смены пароля: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } finally {
                        setState(() {
                          isLoading = false;
                        });
                      }
                    }
                  },
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Изменить'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showCityDropdown = false;
        });
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF9FAFB),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text(
            'Редактирование профиля',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          centerTitle: true,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  children: [
                    // Фото профиля
                    Container(
                      width: double.infinity,
                      height: 144,
                      color: Colors.white,
                      child: Center(
                        child: Stack(
                          children: [
                            Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.grey[200],
                                image: _imageFile != null
                                    ? DecorationImage(
                                        image: FileImage(_imageFile!),
                                        fit: BoxFit.cover,
                                      )
                                    : _avatarUrl != null
                                        ? DecorationImage(
                                            image: NetworkImage(_avatarUrl!),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                              ),
                              child: _imageFile == null && _avatarUrl == null
                                  ? const Icon(
                                      Icons.person,
                                      size: 50,
                                      color: Colors.grey,
                                    )
                                  : null,
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF5EC7C3),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 6,
                                      offset: const Offset(0, 4),
                                    ),
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 15,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    size: 14,
                                    color: Colors.black,
                                  ),
                                  padding: EdgeInsets.zero,
                                  onPressed: _showImageSourceActionSheet,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Форма редактирования профиля
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Avatar section
                          Center(
                            child: Stack(
                              children: [
                                Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.grey[300],
                                    image: _photoFile != null
                                        ? DecorationImage(
                                            image: FileImage(_photoFile!),
                                            fit: BoxFit.cover,
                                          )
                                        : (_userProfile?.avatarUrl != null && _userProfile!.avatarUrl!.isNotEmpty)
                                            ? DecorationImage(
                                                image: NetworkImage(_userProfile!.avatarUrl!),
                                                fit: BoxFit.cover,
                                              )
                                            : null,
                                  ),
                                  child: (_photoFile == null && (_userProfile?.avatarUrl == null || _userProfile!.avatarUrl!.isEmpty))
                                      ? const Icon(
                                          Icons.person,
                                          size: 50,
                                          color: Colors.grey,
                                        )
                                      : null,
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF5EC7C3),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 6,
                                          offset: const Offset(0, 4),
                                        ),
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 15,
                                          offset: const Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.edit,
                                        size: 14,
                                        color: Colors.black,
                                      ),
                                      padding: EdgeInsets.zero,
                                      onPressed: _showImageSourceActionSheet,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Form fields
                        ],
                      ),
                    ),

                    // Первый блок формы - основная информация
                    Container(
                      width: 358,
                      margin: const EdgeInsets.only(
                        top: 16,
                        left: 16,
                        right: 16,
                      ),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Form content will be here
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        height: 81,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 4,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _isLoading ? null : _updateProfile,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF5EC7C3),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text(
                  'Сохранить изменения',
                  style: TextStyle(
                    fontFamily: 'Rubik',
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
        ),
      ),
    );
  }

  // Image source action sheet
  void _showImageSourceActionSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Выбрать из галереи'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage();
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Сделать фото'),
                onTap: () {
                  Navigator.of(context).pop();
                  _takePhoto();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Pick image from gallery
  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 90,
      );

      if (pickedFile != null) {
        setState(() {
          _photoFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      debugPrint('Ошибка при выборе изображения: $e');
    }
  }

  // Take photo with camera
  Future<void> _takePhoto() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 90,
      );

      if (pickedFile != null) {
        setState(() {
          _photoFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      debugPrint('Ошибка при съемке фото: $e');
    }
  }

  // Update profile method placeholder
  Future<void> _updateProfile() async {
    // Implementation would go here
  }
}
                                children: [
                                  const Text(
                                    'Дата рождения',
                                    style: TextStyle(
                                      fontFamily: 'Roboto',
                                      fontSize: 14,
                                      color: Color(0xFF4B5563),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  GestureDetector(
                                    onTap: _selectDate,
                                    child: AbsorbPointer(
                                      child: TextFormField(
                                        controller: _birthDateController,
                                        decoration: InputDecoration(
                                          hintText: 'ДД.ММ.ГГГГ',
                                          hintStyle: const TextStyle(
                                            fontFamily: 'Roboto',
                                            fontSize: 16,
                                            color: Color(0xFFADAEBC),
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            borderSide: const BorderSide(
                                              color: Color(0xFFE5E7EB),
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            borderSide: const BorderSide(
                                              color: Color(0xFFE5E7EB),
                                            ),
                                          ),
                                          suffixIcon: const Icon(
                                            Icons.calendar_today,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Пол
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Пол',
                                    style: TextStyle(
                                      fontFamily: 'Roboto',
                                      fontSize: 14,
                                      color: Color(0xFF4B5563),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Row(
                                        children: [
                                          Radio<String>(
                                            value: 'Мужской',
                                            groupValue: _selectedGender,
                                            onChanged: (value) {
                                              setState(() {
                                                _selectedGender = value;
                                              });
                                            },
                                          ),
                                          const Text(
                                            'Мужской',
                                            style: TextStyle(
                                              fontFamily: 'Roboto',
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 16),
                                      Row(
                                        children: [
                                          Radio<String>(
                                            value: 'Женский',
                                            groupValue: _selectedGender,
                                            onChanged: (value) {
                                              setState(() {
                                                _selectedGender = value;
                                              });
                                            },
                                          ),
                                          const Text(
                                            'Женский',
                                            style: TextStyle(
                                              fontFamily: 'Roboto',
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Город
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Город',
                                    style: TextStyle(
                                      fontFamily: 'Roboto',
                                      fontSize: 14,
                                      color: Color(0xFF4B5563),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Stack(
                                    children: [
                                      TextFormField(
                                        controller: _cityController,
                                        decoration: InputDecoration(
                                          hintText: 'Введите название города',
                                          hintStyle: const TextStyle(
                                            fontFamily: 'Roboto',
                                            fontSize: 16,
                                            color: Color(0xFFADAEBC),
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: const BorderSide(
                                              color: Color(0xFFE5E7EB),
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: const BorderSide(
                                              color: Color(0xFFE5E7EB),
                                            ),
                                          ),
                                          suffixIcon: const Icon(
                                            Icons.search,
                                            size: 20,
                                          ),
                                        ),
                                        onChanged: _filterCities,
                                        onTap: () {
                                          setState(() {
                                            if (_filteredCities.isEmpty) {
                                              _filteredCities = _russianCities;
                                            }
                                            _showCityDropdown = true;
                                          });
                                        },
                                      ),
                                      if (_showCityDropdown && _filteredCities.isNotEmpty)
                                        Positioned(
                                          top: 48,
                                          left: 0,
                                          right: 0,
                                          child: Material(
                                            elevation: 4,
                                            borderRadius: BorderRadius.circular(8),
                                            child: Container(
                                              constraints: const BoxConstraints(
                                                maxHeight: 200,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: const Color(0xFFE5E7EB),
                                                ),
                                              ),
                                              child: ListView.builder(
                                                shrinkWrap: true,
                                                itemCount: _filteredCities.length > 5 
                                                    ? 5 
                                                    : _filteredCities.length,
                                                itemBuilder: (context, index) {
                                                  final city = _filteredCities[index];
                                                  return ListTile(
                                                    dense: true,
                                                    title: Text(
                                                      city,
                                                      style: const TextStyle(
                                                        fontFamily: 'Roboto',
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                    onTap: () => _selectCity(city),
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Третий блок - безопасность и настройки
                        Container(
                          width: 358,
                          margin: const EdgeInsets.only(
                            top: 16,
                            left: 16,
                            right: 16,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              // Кнопка смены пароля
                              _buildActionButton('Сменить пароль', () {
                                _showChangePasswordDialog();
                              }, hasBorder: true),

                              // Кнопка управления картами
                              _buildActionButton('Управление картами', () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const PaymentScreen(),
                                  ),
                                );
                              }, hasBorder: false),
                            ],
                          ),
                        ),

                        // Четвертый блок - удаление аккаунта
                        Container(
                          width: 358,
                          margin: const EdgeInsets.only(
                            top: 16,
                            left: 16,
                            right: 16,
                            bottom: 16,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextButton(
                            onPressed: () {
                              // Логика удаления аккаунта
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Удаление аккаунта'),
                                  content: const Text(
                                    'Вы уверены, что хотите удалить свой аккаунт? Это действие нельзя отменить.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Отмена'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        // Логика удаления аккаунта
                                        Navigator.pop(context);
                                      },
                                      child: const Text(
                                        'Удалить',
                                        style: TextStyle(
                                          color: Color(0xFFEF4444),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                              ),
                            ),
                            child: const Center(
                              child: Text(
                                'Удалить аккаунт',
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFFEF4444),
                                ),
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
      bottomNavigationBar: Container(
        height: 81,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 4,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF53CFC4),
                  foregroundColor: const Color(0xFF374151),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  'Отмена',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF654AA),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  'Сохранить',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 14,
            color: Color(0xFF4B5563),
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 16,
              color: Color(0xFFADAEBC),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Поле не может быть пустым';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildActionButton(
    String title,
    VoidCallback onPressed, {
    required bool hasBorder,
  }) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        height: 49,
        decoration: BoxDecoration(
          border: hasBorder
              ? const Border(
                  bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                )
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Roboto',
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
