import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/constants.dart';
import '../models/child_model.dart';

class EditChildModal extends StatefulWidget {
  final Child child;
  final Function(Child child) onUpdate;
  final Function(String childId) onDelete;

  const EditChildModal({
    super.key,
    required this.child,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  State<EditChildModal> createState() => _EditChildModalState();
}

class _EditChildModalState extends State<EditChildModal> {
  late TextEditingController _nameController;
  late TextEditingController _schoolController;
  final ImagePicker _imagePicker = ImagePicker();
  late int _selectedAge;
  String? _photoUrl;
  File? _photoFile;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.child.fullName);
    _schoolController = TextEditingController(text: widget.child.school ?? '');
    _selectedAge = widget.child.age;
    _photoUrl = widget.child.photoUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _schoolController.dispose();
    super.dispose();
  }

  // Выбор изображения из галереи
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
          _photoUrl = null; // Сбрасываем URL, так как теперь у нас есть файл
        });
      }
    } catch (e) {
      debugPrint('Ошибка при выборе изображения: $e');
    }
  }

  // Сделать фото с камеры
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
          _photoUrl = null; // Сбрасываем URL, так как теперь у нас есть файл
        });
      }
    } catch (e) {
      debugPrint('Ошибка при съемке фото: $e');
    }
  }

  // Показать выбор источника изображения
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

  // Показать диалог подтверждения удаления
  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить ребенка?'),
        content: Text('Вы уверены, что хотите удалить ${widget.child.fullName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Закрыть диалог подтверждения
              Navigator.of(context).pop(); // Закрыть модальное окно редактирования
              widget.onDelete(widget.child.id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        width: 358,
        height: 580,
        child: Column(
          children: [
            // Заголовок и кнопки
            Container(
              height: 60,
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Редактировать ребенка',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: _showDeleteConfirmation,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Форма редактирования
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Аватар ребенка
                    Center(
                      child: Stack(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.grey[300],
                              image: _photoFile != null
                                  ? DecorationImage(
                                      image: FileImage(_photoFile!),
                                      fit: BoxFit.cover,
                                    )
                                  : _photoUrl != null && _photoUrl!.isNotEmpty
                                      ? DecorationImage(
                                          image: NetworkImage(_photoUrl!),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                            ),
                            child: (_photoFile == null && (_photoUrl == null || _photoUrl!.isEmpty))
                                ? const Icon(
                                    Icons.person,
                                    size: 40,
                                    color: Colors.grey,
                                  )
                                : null,
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: const Color(0xFF5EC7C3),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: const Icon(
                                  Icons.camera_alt,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                onPressed: _showImageSourceActionSheet,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Имя ребенка
                    const Text(
                      'Имя ребенка',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        hintText: 'Введите имя',
                        hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderSide: BorderSide.none,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Школа
                    const Text(
                      'Школа (необязательно)',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _schoolController,
                      decoration: InputDecoration(
                        hintText: 'Введите название школы',
                        hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderSide: BorderSide.none,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Возраст ребенка
                    const Text(
                      'Возраст',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _selectedAge,
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down),
                          style: const TextStyle(
                            fontSize: 16,
                            fontFamily: 'Manrope',
                            color: Colors.black,
                          ),
                          onChanged: (int? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _selectedAge = newValue;
                              });
                            }
                          },
                          items: List.generate(18, (index) => index + 1)
                              .map<DropdownMenuItem<int>>((int value) {
                            return DropdownMenuItem<int>(
                              value: value,
                              child: Text('$value лет'),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Кнопки
            Container(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  // Кнопка Отмена
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          side: const BorderSide(color: Color(0xFFE5E7EB)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Отмена',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Кнопка Сохранить
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          if (_nameController.text.isNotEmpty) {
                            // Создаем обновленного ребенка
                            final updatedChild = Child(
                              id: widget.child.id,
                              userId: widget.child.userId,
                              fullName: _nameController.text,
                              age: _selectedAge,
                              school: _schoolController.text.isNotEmpty ? _schoolController.text : null,
                              photoUrl: _photoFile != null ? null : _photoUrl,
                              createdAt: widget.child.createdAt,
                            );
                            // Вызываем callback
                            widget.onUpdate(updatedChild);
                            // Закрываем модальное окно
                            Navigator.of(context).pop();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5EC7C3),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Сохранить',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
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
    );
  }
}
