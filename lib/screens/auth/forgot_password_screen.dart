import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../utils/constants.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/input_field.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _supabaseService = SupabaseService();
  bool _isLoading = false;
  bool _isEmailSent = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _supabaseService.resetPassword(_emailController.text.trim());
      setState(() {
        _isEmailSent = true;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка при отправке запроса на сброс пароля. Попробуйте еще раз.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Восстановление пароля',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _isEmailSent ? _buildSuccessView() : _buildFormView(),
        ),
      ),
    );
  }

  Widget _buildFormView() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          // Иконка
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(40),
              ),
              child: const Icon(
                Icons.lock_reset,
                size: 40,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 32),
          // Заголовок
          Center(
            child: const Text(
              'Забыли пароль?',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          // Описание
          Text(
            'Введите email, который вы использовали при регистрации. Мы отправим вам ссылку для восстановления пароля.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          // Поле email
          InputField(
            label: 'Email',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Введите email';
              }
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                return 'Введите корректный email';
              }
              return null;
            },
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red[600], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Colors.red[600],
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 32),
          // Кнопка отправки
          Center(
            child: PrimaryButton(
              text: 'Отправить ссылку',
              onPressed: _resetPassword,
              isLoading: _isLoading,
            ),
          ),
          const SizedBox(height: 24),
          // Ссылка назад
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Вернуться к входу',
                style: TextStyle(
                  color: AppColors.link,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    return Column(
      children: [
        const SizedBox(height: 60),
        // Иконка успеха
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(50),
          ),
          child: const Icon(
            Icons.mark_email_read,
            size: 50,
            color: Colors.green,
          ),
        ),
        const SizedBox(height: 32),
        // Заголовок
        const Text(
          'Письмо отправлено!',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        // Описание
        Text(
          'Мы отправили инструкции по восстановлению пароля на адрес:\n${_emailController.text}',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        // Дополнительная информация
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Column(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[600], size: 24),
              const SizedBox(height: 8),
              Text(
                'Проверьте папку "Спам", если письмо не пришло в течение нескольких минут.',
                style: TextStyle(
                  color: Colors.blue[700],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const Spacer(),
        // Кнопки действий
        Column(
          children: [
            PrimaryButton(
              text: 'Отправить повторно',
              onPressed: () {
                setState(() {
                  _isEmailSent = false;
                  _errorMessage = null;
                });
              },
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Вернуться к входу',
                style: TextStyle(
                  color: AppColors.link,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}
