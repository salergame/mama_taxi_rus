import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/order_model.dart';
import '../widgets/primary_button.dart';

class OrderDetailsScreen extends StatelessWidget {
  final OrderModel order;

  const OrderDetailsScreen({
    super.key,
    required this.order,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text(
          'Детали заказа',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.05),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusCard(),
            const SizedBox(height: 16),
            _buildRouteCard(),
            const SizedBox(height: 16),
            _buildClientCard(),
            const SizedBox(height: 16),
            _buildPaymentCard(),
            if (order.comment != null && order.comment!.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildCommentCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: order.statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                order.statusIcon,
                color: order.statusColor,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.statusText,
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Заказ №${order.id.length >= 8 ? order.id.substring(0, 8) : order.id}',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Text(
                '${order.price.toStringAsFixed(0)} ₽',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Маршрут',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Container(
                      width: 2,
                      height: 40,
                      color: Colors.grey.shade300,
                    ),
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Откуда',
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        order.startAddress,
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Куда',
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        order.endAddress,
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClientCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Информация о клиенте',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage: order.clientAvatarUrl != null
                      ? NetworkImage(order.clientAvatarUrl!)
                      : null,
                  backgroundColor: Colors.grey.shade300,
                  child: order.clientAvatarUrl == null
                      ? const Icon(Icons.person, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.clientName ?? 'Клиент',
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (order.clientPhone != null)
                        Text(
                          order.clientPhone!,
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
                if (order.clientRating != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star,
                          size: 16,
                          color: Colors.amber.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          order.clientRating!,
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.amber.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            if (order.childCount != null && order.childCount! > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.child_care,
                      size: 16,
                      color: Colors.blue.shade700,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Детей: ${order.childCount}',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 14,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Оплата',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  order.isPaid ? Icons.check_circle : Icons.cancel,
                  color: order.isPaid ? Colors.green : Colors.red,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.isPaid ? 'Оплачено' : 'Не оплачено',
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: order.isPaid ? Colors.green : Colors.red,
                        ),
                      ),
                      if (order.paymentMethod != null)
                        Text(
                          order.paymentMethod!,
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  '${order.price.toStringAsFixed(0)} ₽',
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildCommentCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.comment_outlined,
                  color: Colors.grey.shade700,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Комментарий',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                order.comment!,
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
