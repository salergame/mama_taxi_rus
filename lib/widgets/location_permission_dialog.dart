import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mama_taxi/utils/constants.dart';

class LocationPermissionDialog extends StatelessWidget {
  final VoidCallback onAllow;
  final VoidCallback onDeny;

  const LocationPermissionDialog({
    super.key,
    required this.onAllow,
    required this.onDeny,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Иконка местоположения
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.accentLight,
                borderRadius: BorderRadius.circular(40),
              ),
              child: Icon(
                Icons.location_on,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Заголовок
            Text(
              'Разрешить доступ к местоположению?',
              style: AppTextStyles.heading.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 16),
            
            // Описание
            Text(
              'Мама Такси использует ваше местоположение для:',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 20),
            
            // Список преимуществ
            _buildFeatureItem(
              icon: Icons.navigation,
              title: 'Определения вашего местоположения',
              description: 'Автоматическое определение точки отправления',
            ),
            
            const SizedBox(height: 16),
            
            _buildFeatureItem(
              icon: Icons.route,
              title: 'Построения оптимального маршрута',
              description: 'Быстрый поиск ближайших водителей',
            ),
            
            const SizedBox(height: 16),
            
            _buildFeatureItem(
              icon: Icons.security,
              title: 'Обеспечения безопасности',
              description: 'Отслеживание поездки в реальном времени',
            ),
            
            const SizedBox(height: 32),
            
            // Кнопки
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: onDeny,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: AppColors.border),
                      ),
                    ),
                    child: Text(
                      'Не сейчас',
                      style: AppTextStyles.button.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(width: 12),
                
                Expanded(
                  child: ElevatedButton(
                    onPressed: onAllow,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Разрешить',
                      style: AppTextStyles.button.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Дополнительная информация
            Text(
              'Вы можете изменить это разрешение в любое время в настройках приложения',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textTertiary,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.accent.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 16,
            color: AppColors.primary,
          ),
        ),
        
        const SizedBox(width: 12),
        
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              
              const SizedBox(height: 4),
              
              Text(
                description,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
