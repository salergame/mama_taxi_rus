import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import '../utils/constants.dart';

class DocumentViewer extends StatefulWidget {
  final String title;
  final String documentPath;

  const DocumentViewer({
    super.key,
    required this.title,
    required this.documentPath,
  });

  @override
  State<DocumentViewer> createState() => _DocumentViewerState();
}

class _DocumentViewerState extends State<DocumentViewer> {
  String _documentContent = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  Future<void> _loadDocument() async {
    try {
      final String content = await rootBundle.loadString(widget.documentPath);
      setState(() {
        if (widget.documentPath.endsWith('.md')) {
          _documentContent = _renderMarkdown(content);
        } else {
          _documentContent = _parseRtfToText(content);
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _documentContent = 'Ошибка загрузки документа: $e';
        _isLoading = false;
      });
    }
  }

  String _parseRtfToText(String rtfContent) {
    String text = rtfContent;
    
    // Находим начало основного текста (ищем первый заголовок)
    final startPattern = RegExp(r'\\b\\f1\\fs48\\cf0\s*\\u\d+');
    final mainTextStart = text.indexOf(startPattern);
    if (mainTextStart != -1) {
      text = text.substring(mainTextStart);
    }
    
    // Основная обработка Unicode символов с hex fallback (\u<code>\'<hex>)
    text = text.replaceAllMapped(RegExp(r"\\u(\d+)\\'([a-fA-F0-9]{2})"), (match) {
      final code = int.parse(match.group(1)!);
      return String.fromCharCode(code);
    });
    
    // Обработка простых Unicode символов (\u<code>)
    text = text.replaceAllMapped(RegExp(r'\\u(\d+)\s*'), (match) {
      final code = int.parse(match.group(1)!);
      return String.fromCharCode(code);
    });
    
    // Обработка отрицательных Unicode кодов
    text = text.replaceAllMapped(RegExp(r'\\u-(\d+)\s*'), (match) {
      final code = int.parse(match.group(1)!);
      return String.fromCharCode(65536 - code);
    });
    
    // Обработка оставшихся hex-кодов (\')
    text = text.replaceAllMapped(RegExp(r"\\\'([a-fA-F0-9]{2})"), (match) {
      final hexCode = match.group(1)!;
      final code = int.parse(hexCode, radix: 16);
      return String.fromCharCode(code);
    });
    
    // Заменяем специальные символы RTF
    text = text.replaceAll(r'\par', '\n\n');
    text = text.replaceAll(r'\line', '\n');
    text = text.replaceAll(r'\tab', '\t');
    
    // Удаляем все RTF команды и форматирование
    text = text.replaceAll(RegExp(r'\\[a-zA-Z]+\d*\s*'), '');
    text = text.replaceAll(RegExp(r'\\[^a-zA-Z\s]'), '');
    
    // Удаляем фигурные скобки
    text = text.replaceAll(RegExp(r'[{}]'), '');
    
    // Удаляем специфичные RTF артефакты
    text = text.replaceAll(RegExp(r'-\d+;-?\d+'), ''); // -360;360
    text = text.replaceAll(RegExp(r';\d+;'), ''); // ;360;
    text = text.replaceAll(RegExp(r'[a-z]{1,3}\s*[a-z]{1,3}\s*[a-z]{1,3}'), ''); // f vt le
    text = text.replaceAll(RegExp(r'[a-zA-Z]{1,2}\d+[a-zA-Z]*'), ''); // f1, fs48, cf0
    text = text.replaceAll(RegExp(r'\d+[a-zA-Z]+\d*'), ''); // 48cf0
    text = text.replaceAll(RegExp(r'[;,]+'), ''); // множественные ; и ,
    
    // Удаляем артефакты шрифтов
    text = text.replaceAll(RegExp(r'Times New Roman[^;]*;?'), '');
    text = text.replaceAll(RegExp(r'Calibri[^;]*;?'), '');
    text = text.replaceAll(RegExp(r'Symbol[^;]*;?'), '');
    
    // Удаляем остатки команд и цифр
    text = text.replaceAll(RegExp(r'\b[a-zA-Z]{1,3}\d+\b'), '');
    text = text.replaceAll(RegExp(r'\b\d{2,}\b'), '');
    
    // Удаляем одиночные буквы и артефакты
    text = text.replaceAll(RegExp(r'\b[a-zA-Zа-яА-Я]\b'), ''); // одиночные буквы
    text = text.replaceAll(RegExp(r'\s[a-z]\s'), ' '); // одиночные строчные буквы между пробелами
    
    // Структурируем текст
    text = _structureDocument(text);
    
    // Финальная очистка
    text = text.replaceAll(RegExp(r'\s+'), ' ');
    text = text.replaceAll(RegExp(r'\n\s+'), '\n');
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    text = text.trim();
    
    return text;
  }
  
  String _structureDocument(String text) {
    // Разделяем текст на предложения для лучшей обработки
    List<String> sentences = text.split(RegExp(r'[.!?]\s+'));
    StringBuffer result = StringBuffer();
    
    for (int i = 0; i < sentences.length; i++) {
      String sentence = sentences[i].trim();
      if (sentence.isEmpty) continue;
      
      // Проверяем, является ли это заголовком (начинается с цифры и содержит заглавные буквы)
      if (RegExp(r'^\d+\s*[А-ЯЁ]').hasMatch(sentence)) {
        // Основной заголовок
        final match = RegExp(r'^(\d+)\s*(.+)').firstMatch(sentence);
        if (match != null) {
          final number = match.group(1);
          final title = match.group(2)?.trim();
          result.writeln('\n$number. $title\n');
          continue;
        }
      }
      
      // Проверяем подпункты (цифра.цифра)
      if (RegExp(r'^\d+\.\d+').hasMatch(sentence)) {
        final match = RegExp(r'^(\d+\.\d+)\s*(.+)').firstMatch(sentence);
        if (match != null) {
          final number = match.group(1);
          final content = match.group(2)?.trim();
          result.writeln('$number. $content');
          continue;
        }
      }
      
      // Проверяем элементы списка (начинаются с маленькой буквы или содержат тире)
      if (RegExp(r'^[а-яё]|^—|^-').hasMatch(sentence)) {
        result.writeln('• $sentence;');
        continue;
      }
      
      // Проверяем контактную информацию
      if (sentence.contains('ИП ') || sentence.contains('ИНН') || 
          sentence.contains('E-mail') || sentence.contains('Телефон') ||
          sentence.contains('г. ')) {
        result.writeln('$sentence');
        continue;
      }
      
      // Обычные абзацы
      if (sentence.length > 20) {
        result.writeln('\n$sentence.\n');
      } else {
        result.write('$sentence. ');
      }
    }
    
    String finalText = result.toString();
    
    // Дополнительное форматирование
    finalText = _formatSpecialSections(finalText);
    
    return finalText;
  }
  
  String _formatSpecialSections(String text) {
    // Форматируем заголовки документа
    text = text.replaceAllMapped(
      RegExp(r'(ПОЛЬЗОВАТЕЛЬСКОЕ СОГЛАШЕНИЕ|ПОЛИТИКА КОНФИДЕНЦИАЛЬНОСТИ)'),
      (match) => '\n${match.group(1)}\n(ПУБЛИЧНАЯ ОФЕРТА)\n'
    );
    
    // Форматируем информацию о сервисе
    text = text.replaceAllMapped(
      RegExp(r'сервиса «([^»]+)»'),
      (match) => 'сервиса «${match.group(1)}»\n'
    );
    
    // Форматируем контактную информацию
    text = text.replaceAllMapped(
      RegExp(r'(ИП [А-ЯЁ][а-яё\s]+)'),
      (match) => '\nОператор: ${match.group(1)}'
    );
    
    text = text.replaceAllMapped(
      RegExp(r'(ИНН:?\s*\d+)'),
      (match) => '\n${match.group(1)}'
    );
    
    text = text.replaceAllMapped(
      RegExp(r'(г\.\s*[А-ЯЁ][а-яё]+)'),
      (match) => '\n${match.group(1)}'
    );
    
    text = text.replaceAllMapped(
      RegExp(r'(E-mail:\s*[^\s]+)'),
      (match) => '\n${match.group(1)}'
    );
    
    text = text.replaceAllMapped(
      RegExp(r'(Телефон:\s*[+\d\s]+)'),
      (match) => '\n${match.group(1)}'
    );
    
    // Форматируем определения в списках
    text = text.replaceAllMapped(
      RegExp(r'([А-ЯЁ][а-яё-]+)\s*—\s*([а-яё].+?)(?=\n|$)'),
      (match) => '\n• **${match.group(1)}** — ${match.group(2)}\n'
    );
    
    return text;
  }

  String _renderMarkdown(String markdown) {
    String text = markdown;
    
    // Обрабатываем заголовки
    text = text.replaceAllMapped(RegExp(r'^# (.+)$', multiLine: true), (match) {
      return '\n${match.group(1)?.toUpperCase()}\n${'=' * (match.group(1)?.length ?? 0)}\n';
    });
    
    text = text.replaceAllMapped(RegExp(r'^## (.+)$', multiLine: true), (match) {
      return '\n\n${match.group(1)}\n${'-' * (match.group(1)?.length ?? 0)}\n';
    });
    
    text = text.replaceAllMapped(RegExp(r'^### (.+)$', multiLine: true), (match) {
      return '\n${match.group(1)}\n';
    });
    
    // Обрабатываем жирный текст
    text = text.replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (match) {
      return '${match.group(1)?.toUpperCase()}';
    });
    
    // Обрабатываем курсив
    text = text.replaceAllMapped(RegExp(r'\*(.+?)\*'), (match) {
      return '${match.group(1)}';
    });
    
    // Обрабатываем списки
    text = text.replaceAllMapped(RegExp(r'^- (.+)$', multiLine: true), (match) {
      return '• ${match.group(1)}';
    });
    
    // Убираем лишние переносы
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    
    return text.trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: AppTextStyles.heading,
        ),
        backgroundColor: AppColors.white,
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.05),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        color: const Color(0xFFF9FAFB),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFA5C572),
                ),
              )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: AppTextStyles.heading.copyWith(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Divider(color: Color(0xFFE5E7EB)),
                          const SizedBox(height: 16),
                          Text(
                            _documentContent,
                            style: AppTextStyles.body.copyWith(
                              height: 1.6,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }
}
