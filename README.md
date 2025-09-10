# Мама Такси

Мобильное приложение такси с поддержкой реальных карт и маршрутов.

## Функциональность

- Авторизация пользователя
- Отображение карты Google Maps
- Ввод адресов отправления и назначения
- Построение маршрута между точками
- Выбор тарифа поездки
- Заказ поездки и отслеживание статуса
- Отмена поездки
- Связь с водителем (чат, звонок)

## Настройка

### 1. Получение ключа Google Maps API

Для использования Google Maps в приложении вам понадобится API ключ:

1. Перейдите в [Google Cloud Console](https://console.cloud.google.com/)
2. Создайте новый проект или выберите существующий
3. Включите API для:
   - Maps SDK for Android
   - Maps SDK for iOS
   - Directions API
   - Places API
   - Geocoding API
4. Создайте ключ API в разделе Credentials
5. Добавьте ограничения для вашего ключа (по приложениям и IP)

### 2. Настройка приложения

После получения ключа API, необходимо внести его в приложение:

**Android:**
Замените `YOUR_API_KEY_HERE` в файле `android/app/src/main/AndroidManifest.xml` на ваш ключ API.

**iOS:**
Замените `YOUR_API_KEY_HERE` в файле `ios/Runner/Info.plist` на ваш ключ API.

**Dart:**
Замените значение переменной `_apiKey` в файле `lib/services/map_service.dart` на ваш ключ API.

## Установка и запуск

1. Убедитесь, что у вас установлен Flutter и Dart:
   ```
   flutter --version
   ```

2. Клонируйте репозиторий:
   ```
   git clone https://github.com/your-username/mama_taxi.git
   cd mama_taxi
   ```

3. Установите зависимости:
   ```
   flutter pub get
   ```

4. Запустите приложение:
   ```
   flutter run
   ```

## Демо-режим

По умолчанию приложение работает в демо-режиме, который не требует реального API ключа. Для переключения в реальный режим:

1. Измените значение переменной `demoMode` на `false` в файле `lib/services/map_service.dart`
2. Убедитесь, что вы добавили действительный API ключ как описано выше

## Требования

- Flutter 2.5+ / Dart 2.14+
- Android 5.0+ (API level 21+)
- iOS 11.0+

## Структура проекта

- **lib/models** - Модели данных
- **lib/providers** - Провайдеры состояния
- **lib/screens** - Экраны приложения
- **lib/services** - Сервисы (карты, авторизация)
- **lib/components** - Переиспользуемые компоненты

## Лицензия

[MIT License](LICENSE)

## Настройка Firebase

Для работы авторизации через телефон, необходимо настроить Firebase:

1. Создайте проект в [Firebase Console](https://console.firebase.google.com/)
2. Добавьте приложения для Android и iOS:

### Android:
- Добавьте приложение с package name: `com.example.mama_taxi`
- Скачайте `google-services.json` и поместите его в папку `android/app/`
- Включите авторизацию через телефон в разделе Authentication

### iOS:
- Добавьте приложение с bundle ID: `com.example.mamaTaxi`
- Скачайте `GoogleService-Info.plist` и поместите его в папку `ios/Runner/`
- Настройте необходимые параметры в Xcode

## Настройка FlutterFire

Установите FlutterFire CLI и настройте проект:

```
dart pub global activate flutterfire_cli
flutterfire configure --project=ваш-firebase-проект-id
```

## Включение авторизации по телефону

1. В консоли Firebase откройте раздел Authentication
2. Включите метод входа "Phone" (Телефон)
3. Для тестирования добавьте свой номер телефона в список разрешенных телефонов
4. **Важно:** В разделе "Countries/regions" нажмите "Add region" и добавьте вашу страну/регион (например, Россия)
5. В коде проекта измените значение `_isDemoMode = false` в файле `lib/services/auth_service.dart`

## Настройка reCAPTCHA

Если вы сталкиваетесь с ошибкой "Failed to initialize reCAPTCHA Enterprise config":

1. В Firebase Console перейдите в Authentication > Settings > Advanced settings
2. Раздел reCAPTCHA Enterprise: Выберите "False" для "Use enhanced phone number verification"
3. Это отключит reCAPTCHA Enterprise и будет использовать обычную reCAPTCHA v2

Для устранения проблемы с reCAPTCHA на Android:
1. Проверьте, что ваше приложение зарегистрировано в Firebase с корректным SHA-1 ключом
2. Получите SHA-1 ключ с помощью команды:
   ```
   cd android && ./gradlew signingReport
   ```
3. Добавьте полученный SHA-1 ключ в настройки приложения в Firebase Console
4. Пересоздайте файл google-services.json и обновите его в проекте

## Запуск проекта

```
flutter pub get
flutter run
```

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
