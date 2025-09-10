import 'package:flutter/material.dart';
import 'package:mama_taxi/utils/constants.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

class DriverChatDialog extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> driverInfo;
  final Function onClose;

  const DriverChatDialog({
    required this.orderId,
    required this.driverInfo,
    required this.onClose,
    Key? key,
  }) : super(key: key);

  @override
  _DriverChatDialogState createState() => _DriverChatDialogState();
}

class _DriverChatDialogState extends State<DriverChatDialog> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final Stream<List<Map<String, dynamic>>> _messagesStream;
  String? _errorMessage;
  bool _isLoading = false;

  // Для звонков
  late String _userId;

  @override
  void initState() {
    super.initState();
    _userId = Supabase.instance.client.auth.currentUser?.id ?? 'user_${DateTime.now().millisecondsSinceEpoch}';
    _messagesStream = Supabase.instance.client
        .from('messages:chat_id=eq.${widget.orderId}')
        .stream(primaryKey: ['id'])
        .order('created_at')
        .limit(100);
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    try {
      await Supabase.instance.client.from('messages').insert({
        'chat_id': widget.orderId,
        'sender_id': _userId,
        'content': text,
      });
      _messageController.clear();
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка отправки сообщения: $e';
      });
    }
  }

  // Regular phone call logic
  Future<void> _makePhoneCall() async {
    final phoneNumber = widget.driverInfo['phoneNumber'] ?? widget.driverInfo['phone'];
    if (phoneNumber != null && phoneNumber.isNotEmpty) {
      final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
      try {
        if (await canLaunchUrl(phoneUri)) {
          await launchUrl(phoneUri);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Не удалось совершить звонок'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка при звонке: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Номер телефона водителя недоступен'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      elevation: 8,
      child: Container(
        width: double.maxFinite,
        height: 500,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => widget.onClose(),
                  icon: const Icon(Icons.arrow_back),
                ),
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey[300],
                  child: widget.driverInfo['avatarUrl'] != null && 
                        widget.driverInfo['avatarUrl'].isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.network(
                            widget.driverInfo['avatarUrl'],
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(Icons.person, color: Colors.grey);
                            },
                          ),
                        )
                      : const Icon(Icons.person, color: Colors.grey),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.driverInfo['name'] ?? 'Водитель',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Rubik',
                      ),
                    ),
                    Text(
                      'В пути',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.success,
                        fontFamily: 'Manrope',
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  onPressed: _makePhoneCall,
                  icon: Icon(Icons.call, color: AppColors.primary),
                ),
                IconButton(
                  onPressed: () => widget.onClose(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Divider(),
            if (_isLoading)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Подключение к чату...'),
                    ],
                  ),
                ),
              )
            else if (_errorMessage != null)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => setState(() => _errorMessage = null),
                        child: const Text('Попробовать снова'),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _messagesStream,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
                    final messages = snapshot.data!;
                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        final isDriver = msg['sender_id'] == widget.driverInfo['id'];
                        final time = DateTime.tryParse(msg['created_at'] ?? '') ?? DateTime.now();
                        return Align(
                          alignment: isDriver ? Alignment.centerLeft : Alignment.centerRight,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            decoration: BoxDecoration(
                              color: isDriver ? Colors.grey[200] : AppColors.primary.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.7,
                            ),
                            child: Column(
                              crossAxisAlignment: isDriver ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                              children: [
                                Text(
                                  msg['content'] ?? '',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.black87,
                                    fontFamily: 'Manrope',
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatTime(time),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontFamily: 'Manrope',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Введите сообщение...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: AppColors.primary,
                  child: IconButton(
                    onPressed: _sendMessage,
                    icon: const Icon(Icons.send, color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
} 