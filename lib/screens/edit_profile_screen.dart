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
  
  // Расширенный список городов РФ
  static const List<String> _russianCities = [
    // Крупнейшие города
    'Москва', 'Санкт-Петербург', 'Новосибирск', 'Екатеринбург', 'Казань', 'Нижний Новгород',
    'Челябинск', 'Самара', 'Омск', 'Ростов-на-Дону', 'Уфа', 'Красноярск', 'Воронеж', 'Пермь',
    'Волгоград', 'Краснодар', 'Саратов', 'Тюмень', 'Тольятти', 'Ижевск', 'Барнаул', 'Ульяновск',
    'Иркутск', 'Хабаровск', 'Ярославль', 'Владивосток', 'Махачкала', 'Томск', 'Оренбург', 'Кемерово',
    'Новокузнецк', 'Рязань', 'Набережные Челны', 'Астрахань', 'Пенза', 'Липецк', 'Тула', 'Киров',
    'Чебоксары', 'Курск', 'Брянск', 'Магнитогорск', 'Иваново', 'Тверь', 'Ставрополь', 'Белгород',
    'Сочи', 'Нижний Тагил', 'Архангельск', 'Владимир', 'Калуга', 'Чита', 'Сургут', 'Смоленск',
    
    // Дополнительные крупные города
    'Волжский', 'Курган', 'Орёл', 'Череповец', 'Вологда', 'Владикавказ', 'Мурманск', 'Саранск',
    'Якутск', 'Тамбов', 'Стерлитамак', 'Грозный', 'Кострома', 'Петрозаводск', 'Нижневартовск',
    'Йошкар-Ола', 'Новороссийск', 'Комсомольск-на-Амуре', 'Таганрог', 'Сыктывкар', 'Нальчик',
    'Шахты', 'Дзержинск', 'Орск', 'Ангарск', 'Балашиха', 'Благовещенск', 'Прокопьевск', 'Химки',
    'Псков', 'Бийск', 'Энгельс', 'Рыбинск', 'Балаково', 'Северодвинск', 'Армавир', 'Подольск',
    
    // Города Московской области и других регионов
    'Королёв', 'Сызрань', 'Норильск', 'Каменск-Уральский', 'Волгодонск', 'Абакан', 'Мытищи',
    'Петропавловск-Камчатский', 'Альметьевск', 'Уссурийск', 'Березники', 'Салават', 'Электросталь',
    'Миасс', 'Первоуральск', 'Рубцовск', 'Коломна', 'Майкоп', 'Ковров', 'Красногорск',
    'Новочеркасск', 'Копейск', 'Железнодорожный', 'Хасавюрт', 'Великий Новгород', 'Серпухов',
    'Дербент', 'Орехово-Зуево', 'Димитровград', 'Камышин', 'Невинномысск', 'Октябрьский',
    'Ачинск', 'Северск', 'Новочебоксарск', 'Каспийск', 'Зеленодольск', 'Батайск',
    
    // Дополнительные города
    'Новошахтинск', 'Ноябрьск', 'Кызыл', 'Муром', 'Елец', 'Артём', 'Новомосковск', 'Черкесск',
    'Междуреченск', 'Сергиев Посад', 'Арзамас', 'Жуковский', 'Ногинск', 'Новокуйбышевск',
    'Кисловодск', 'Обнинск', 'Люберцы', 'Одинцово', 'Домодедово', 'Щёлково', 'Орехово-Зуево',
    'Раменское', 'Долгопрудный', 'Пушкино', 'Реутов', 'Лобня', 'Клин', 'Воскресенск',
    'Егорьевск', 'Электрогорск', 'Дмитров', 'Ступино', 'Павловский Посад', 'Лыткарино',
    
    // Города Сибири и Дальнего Востока
    'Братск', 'Улан-Удэ', 'Магадан', 'Южно-Сахалинск', 'Биробиджан', 'Анадырь', 'Салехард',
    'Ханты-Мансийск', 'Нарьян-Мар', 'Воркута', 'Инта', 'Усинск', 'Печора', 'Ухта',
    'Сосногорск', 'Емва', 'Микунь', 'Котлас', 'Северодвинск', 'Новодвинск', 'Коряжма',
    
    // Города Урала
    'Нижний Тагил', 'Каменск-Уральский', 'Серов', 'Краснотурьинск', 'Верхняя Пышма',
    'Ревда', 'Асбест', 'Полевской', 'Новоуральск', 'Лесной', 'Заречный', 'Верхняя Салда',
    'Качканар', 'Ивдель', 'Карпинск', 'Волчанск', 'Красноуфимск', 'Артёмовский',
    
    // Города Поволжья
    'Волжск', 'Козьмодемьянск', 'Звенигово', 'Волжск', 'Медведево', 'Оршанка', 'Советский',
    'Килемары', 'Мари-Турек', 'Сернур', 'Параньга', 'Юрино', 'Новый Торьял',
    
    // Города Центральной России
    'Можайск', 'Руза', 'Волоколамск', 'Шаховская', 'Лотошино', 'Истра', 'Красногорск',
    'Нахабино', 'Дедовск', 'Снегири', 'Павловская Слобода', 'Ильинское', 'Красновидово',
    
    // Города Северо-Запада
    'Выборг', 'Приозерск', 'Сланцы', 'Кингисепп', 'Волосово', 'Луга', 'Гатчина',
    'Тосно', 'Любань', 'Чудово', 'Малая Вишера', 'Боровичи', 'Валдай', 'Старая Русса',
    
    // Города Юга России
    'Анапа', 'Геленджик', 'Туапсе', 'Горячий Ключ', 'Кропоткин', 'Тихорецк', 'Ейск',
    'Темрюк', 'Приморско-Ахтарск', 'Славянск-на-Кубани', 'Крымск', 'Абинск', 'Белореченск',
    'Апшеронск', 'Лабинск', 'Курганинск', 'Усть-Лабинск', 'Кореновск', 'Тимашёвск'
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
    _filteredCities = List.from(_russianCities);
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
        // Показываем все города при пустом запросе
        _filteredCities = List.from(_russianCities);
        _showCityDropdown = true;
        _selectedCity = query; // Обновляем только при пустом запросе
      } else {
        // Фильтруем города по запросу (поиск с начала слова и содержания)
        _filteredCities = _russianCities
            .where((city) {
              final cityLower = city.toLowerCase();
              final queryLower = query.toLowerCase();
              // Поиск с начала названия города или содержания
              return cityLower.startsWith(queryLower) || 
                     cityLower.contains(queryLower);
            })
            .toList();
        
        // Сортируем результаты: сначала те, что начинаются с запроса
        _filteredCities.sort((a, b) {
          final aLower = a.toLowerCase();
          final bLower = b.toLowerCase();
          final queryLower = query.toLowerCase();
          
          final aStarts = aLower.startsWith(queryLower);
          final bStarts = bLower.startsWith(queryLower);
          
          if (aStarts && !bStarts) return -1;
          if (!aStarts && bStarts) return 1;
          return a.compareTo(b);
        });
        
        _showCityDropdown = _filteredCities.isNotEmpty;
        
        // Обновляем _selectedCity только если введенный текст точно совпадает с городом из списка
        if (_russianCities.contains(query)) {
          _selectedCity = query;
        } else {
          // Если не точное совпадение, сохраняем введенный текст как выбранный город
          _selectedCity = query;
        }
      }
    });
  }

  void _selectCity(String city) {
    // Принудительно устанавливаем текст в контроллер
    _cityController.text = city;
    
    setState(() {
      _selectedCity = city;
      _showCityDropdown = false;
      // Очищаем фильтрованный список, чтобы при следующем открытии показывались все города
      _filteredCities = List.from(_russianCities);
    });
    
    // Дополнительно устанавливаем курсор в конец текста
    _cityController.selection = TextSelection.fromPosition(
      TextPosition(offset: city.length),
    );
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
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Отменить',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFFA5C572),
                ),
              ),
            ),
          ],
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
                                  color: const Color(0xFFA5C572),
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
                        children: [
                          // Первый блок - основная информация
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
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Имя
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Имя',
                                      style: TextStyle(
                                        fontFamily: 'Roboto',
                                        fontSize: 14,
                                        color: Color(0xFF4B5563),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    TextFormField(
                                      controller: _firstNameController,
                                      decoration: InputDecoration(
                                        hintText: 'Введите имя',
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
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                
                                // Фамилия
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Фамилия',
                                      style: TextStyle(
                                        fontFamily: 'Roboto',
                                        fontSize: 14,
                                        color: Color(0xFF4B5563),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    TextFormField(
                                      controller: _lastNameController,
                                      decoration: InputDecoration(
                                        hintText: 'Введите фамилию',
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
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                
                                // Телефон
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Телефон',
                                      style: TextStyle(
                                        fontFamily: 'Roboto',
                                        fontSize: 14,
                                        color: Color(0xFF4B5563),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    TextFormField(
                                      controller: _phoneController,
                                      decoration: InputDecoration(
                                        hintText: '+7 (999) 999-99-99',
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
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                
                                // Email
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Email',
                                      style: TextStyle(
                                        fontFamily: 'Roboto',
                                        fontSize: 14,
                                        color: Color(0xFF4B5563),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    TextFormField(
                                      controller: _emailController,
                                      decoration: InputDecoration(
                                        hintText: 'example@mail.com',
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
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Второй блок - дополнительная информация
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
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Дата рождения
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                    TextFormField(
                                      controller: _birthDateController,
                                      readOnly: true,
                                      onTap: _selectDate,
                                      decoration: InputDecoration(
                                        hintText: 'ДД.ММ.ГГГГ',
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
                                          Icons.calendar_today,
                                          size: 20,
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
                                    const SizedBox(height: 4),
                                    DropdownButtonFormField<String>(
                                      value: _selectedGender,
                                      decoration: InputDecoration(
                                        contentPadding: const EdgeInsets.symmetric(
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
                                      ),
                                      items: ['Мужской', 'Женский']
                                          .map((String value) {
                                        return DropdownMenuItem<String>(
                                          value: value,
                                          child: Text(
                                            value,
                                            style: TextStyle(
                                              color: _selectedGender == value 
                                                  ? const Color(0xFFA5C572) 
                                                  : Colors.black,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (String? newValue) {
                                        setState(() {
                                          _selectedGender = newValue;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                
                                // Город с поиском
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
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
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
                                            contentPadding: const EdgeInsets.symmetric(
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
                                                _filteredCities = List.from(_russianCities);
                                              }
                                              _showCityDropdown = true;
                                            });
                                          },
                                          onTapOutside: (event) {
                                            setState(() {
                                              _showCityDropdown = false;
                                            });
                                          },
                                        ),
                                        if (_showCityDropdown && _filteredCities.isNotEmpty)
                                          Container(
                                            margin: const EdgeInsets.only(top: 4),
                                            constraints: const BoxConstraints(
                                              maxHeight: 200,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: const Color(0xFFE5E7EB),
                                              ),
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
                                              itemCount: _filteredCities.length > 10 
                                                  ? 10 
                                                  : _filteredCities.length,
                                              itemBuilder: (context, index) {
                                                final city = _filteredCities[index];
                                                return InkWell(
                                                  onTap: () => _selectCity(city),
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 12,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      border: Border(
                                                        bottom: BorderSide(
                                                          color: Colors.grey.shade200,
                                                          width: 0.5,
                                                        ),
                                                      ),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        const Icon(
                                                          Icons.location_city,
                                                          size: 16,
                                                          color: Colors.grey,
                                                        ),
                                                        const SizedBox(width: 12),
                                                        Expanded(
                                                          child: Text(
                                                            city,
                                                            style: const TextStyle(
                                                              fontFamily: 'Roboto',
                                                              fontSize: 14,
                                                              color: Colors.black87,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              },
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
                            padding: const EdgeInsets.all(16),
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
                              bottom: 32,
                            ),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                _buildActionButton('Удалить аккаунт', () {
                                  // Логика удаления аккаунта
                                }, hasBorder: false, isDestructive: true),
                              ],
                            ),
                          ),

                          // Кнопка сохранения
                          Container(
                            width: 358,
                            margin: const EdgeInsets.only(
                              left: 16,
                              right: 16,
                              bottom: 32,
                            ),
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _saveProfile,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF654AA),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isLoading
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : const Text(
                                      'Сохранить изменения',
                                      style: TextStyle(
                                        fontFamily: 'Manrope',
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
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
      ),
    );
  }

  Widget _buildActionButton(String title, VoidCallback onTap, {required bool hasBorder, bool isDestructive = false}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: hasBorder ? Border(bottom: BorderSide(color: Colors.grey[300]!)) : null,
      ),
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          alignment: Alignment.centerLeft,
        ),
        child: Text(
          title,
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 16,
            color: isDestructive ? Colors.red : Colors.black,
          ),
        ),
      ),
    );
  }

}
