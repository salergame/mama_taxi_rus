import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';
import '../models/loyalty_model.dart';

class DriverLoyaltyScreen extends StatefulWidget {
  const DriverLoyaltyScreen({Key? key}) : super(key: key);

  @override
  State<DriverLoyaltyScreen> createState() => _DriverLoyaltyScreenState();
}

class _DriverLoyaltyScreenState extends State<DriverLoyaltyScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  bool _isLoading = true;
  LoyaltyModel? _loyaltyData;

  @override
  void initState() {
    super.initState();
    _loadLoyaltyData();
  }

  Future<void> _loadLoyaltyData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final loyaltyData = await _supabaseService.getUserLoyalty();
      setState(() {
        _loyaltyData = loyaltyData;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Ошибка загрузки данных лояльности: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  children: [
                    _buildHeader(context),
                    _buildPointsCard(),
                    _buildDriverBenefits(),
                    _buildHowToEarnPoints(),
                    _buildPointsHistory(),
                    _buildFooter(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      height: 65,
      decoration: const BoxDecoration(
        color: Color.fromRGBO(255, 255, 255, 0.8),
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFF3F4F6),
            width: 1,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: SvgPicture.asset(
                'assets/icons/loyalty/arrow_back.svg',
                width: 17.5,
                height: 20,
                colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
              ),
            ),
            const SizedBox(width: 15.5),
            const Text(
              'Программа лояльности для водителей',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPointsCard() {
    if (_loyaltyData == null) {
      return const SizedBox.shrink();
    }

    final currentLevel = _loyaltyData!.getCurrentLevel();
    final nextLevel = _loyaltyData!.getNextLevel();
    final progress = _loyaltyData!.getProgressToNextLevel();
    final pointsToNextLevel = _loyaltyData!.getPointsToNextLevel();

    final progressWidth = 310 * progress;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            height: 188,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [Color(0xFFF654AA), Color(0xFFA5C572)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: 0,
                  top: 0,
                  child: Opacity(
                    opacity: 0.1,
                    child: SvgPicture.asset(
                      'assets/icons/loyalty/coin.svg',
                      width: 96,
                      height: 96,
                      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Текущий баланс баллов',
                        style: TextStyle(
                          fontFamily: 'Unbounded',
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        '${_loyaltyData!.points}',
                        style: const TextStyle(
                          fontFamily: 'Unbounded',
                          fontSize: 36,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Stack(
                        children: [
                          Container(
                            width: 310,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(9999),
                            ),
                          ),
                          Container(
                            width: progressWidth,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(9999),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 13),
                      Text(
                        nextLevel.level == currentLevel.level
                            ? 'Вы достигли максимального уровня!'
                            : 'Еще $pointsToNextLevel баллов – и вы получите ${nextLevel.reward} ${nextLevel.rewardDescription}!',
                        style: const TextStyle(
                          fontFamily: 'Unbounded',
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _buildDriverLoyaltyLevelCards(currentLevel),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDriverLoyaltyLevelCards(LoyaltyLevel currentLevel) {
    final driverLevels = [
      {
        'level': 0,
        'points': '0',
        'iconData': Icons.star_border,
        'reward': 'базовая',
        'rewardValue': 'комиссия',
      },
      {
        'level': 1,
        'points': '5000',
        'iconData': Icons.monetization_on,
        'reward': '-5%',
        'rewardValue': 'комиссия',
      },
      {
        'level': 2,
        'points': '10000',
        'iconData': Icons.card_giftcard,
        'reward': '-10%',
        'rewardValue': 'комиссия',
      },
      {
        'level': 3,
        'points': '20000',
        'iconData': Icons.directions_car,
        'reward': 'приоритет',
        'rewardValue': 'заказов',
      },
    ];

    return driverLevels.map((level) {
      final isCurrentLevel = level['level'] == currentLevel.level;
      return _buildLoyaltyLevelCard(
        iconData: level['iconData'] as IconData,
        points: level['points'] as String,
        reward: level['reward'] as String,
        rewardValue: level['rewardValue'] as String,
        isActive: isCurrentLevel,
      );
    }).toList();
  }

  Widget _buildLoyaltyLevelCard({
    required IconData iconData,
    required String points,
    required String reward,
    String? rewardValue,
    bool isActive = false,
  }) {
    return Container(
      width: 111,
      height: 134,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? const Color(0xFFA5C572) : const Color(0xFFF3F4F6),
          width: isActive ? 2 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.05),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            iconData,
            size: 20,
            color: isActive ? const Color(0xFFA5C572) : Colors.black,
          ),
          const SizedBox(height: 2),
          Text(
            points,
            style: TextStyle(
              fontFamily: 'Unbounded',
              fontSize: 12,
              color: isActive ? const Color(0xFFA5C572) : Colors.black,
            ),
          ),
          Text(
            'баллов',
            style: TextStyle(
              fontFamily: 'Unbounded',
              fontSize: 12,
              color: isActive ? const Color(0xFFA5C572) : Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            reward,
            style: TextStyle(
              fontFamily: 'Unbounded',
              fontSize: 12,
              color:
                  isActive ? const Color(0xFFA5C572) : const Color(0xFF4B5563),
            ),
          ),
          if (rewardValue != null)
            Text(
              rewardValue,
              style: TextStyle(
                fontFamily: 'Unbounded',
                fontSize: 12,
                color: isActive
                    ? const Color(0xFFA5C572)
                    : const Color(0xFF4B5563),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDriverBenefits() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Преимущества для водителей',
            style: TextStyle(
              fontFamily: 'Unbounded',
              fontSize: 18,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 16),
          _buildBenefitItem(
            backgroundColor: const Color(0xFFF9D3E2),
            iconData: Icons.percent,
            iconColor: const Color(0xFFF654AA),
            title: 'Снижение комиссии',
            subtitle: 'До 10% меньше комиссии сервиса',
          ),
          const SizedBox(height: 16),
          _buildBenefitItem(
            backgroundColor: const Color(0xFFF9D3E2),
            iconData: Icons.priority_high,
            iconColor: const Color(0xFFF654AA),
            title: 'Приоритет в заказах',
            subtitle: 'Первыми получаете заказы в час пик',
          ),
          const SizedBox(height: 16),
          _buildBenefitItem(
            backgroundColor: const Color(0xFFF9D3E2),
            iconData: Icons.local_offer,
            iconColor: const Color(0xFFA5C572),
            title: 'Эксклюзивные акции',
            subtitle: 'Специальные предложения для водителей',
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitItem({
    required Color backgroundColor,
    required IconData iconData,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(9999),
          ),
          child: Center(
            child: Icon(
              iconData,
              size: 16,
              color: iconColor,
            ),
          ),
        ),
        const SizedBox(width: 15),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Unbounded',
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              subtitle,
              style: const TextStyle(
                fontFamily: 'Unbounded',
                fontSize: 14,
                color: Color(0xFF4B5563),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHowToEarnPoints() {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Как зарабатывать баллы?',
            style: TextStyle(
              fontFamily: 'Unbounded',
              fontSize: 18,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 16),
          _buildEarnPointsItem(
            backgroundColor: const Color(0xFFF9D3E2),
            iconData: Icons.directions_car,
            iconColor: const Color(0xFFF654AA),
            title: '1 поездка = 15 баллов',
            subtitle: 'За каждую завершенную поездку',
          ),
          const SizedBox(height: 16),
          _buildEarnPointsItem(
            backgroundColor: const Color(0xFFF9D3E2),
            iconData: Icons.star,
            iconColor: const Color(0xFFF654AA),
            title: 'Высокий рейтинг = 50 баллов',
            subtitle: 'За рейтинг выше 4.8 каждую неделю',
          ),
          const SizedBox(height: 16),
          _buildEarnPointsItem(
            backgroundColor: const Color(0xFFF9D3E2),
            iconData: Icons.schedule,
            iconColor: const Color(0xFFA5C572),
            title: 'Работа в пиковые часы = 20 баллов',
            subtitle: 'За каждый час работы в пиковое время',
          ),
        ],
      ),
    );
  }

  Widget _buildEarnPointsItem({
    required Color backgroundColor,
    required IconData iconData,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(9999),
          ),
          child: Center(
            child: Icon(
              iconData,
              size: 16,
              color: iconColor,
            ),
          ),
        ),
        const SizedBox(width: 15),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Unbounded',
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              subtitle,
              style: const TextStyle(
                fontFamily: 'Unbounded',
                fontSize: 14,
                color: Color(0xFF4B5563),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPointsHistory() {
    if (_loyaltyData == null || _loyaltyData!.history.isEmpty) {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 27, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'История баллов',
              style: TextStyle(
                fontFamily: 'Unbounded',
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 19),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF3F4F6)),
              ),
              child: const Center(
                child: Text(
                  'История пуста',
                  style: TextStyle(
                    fontFamily: 'Unbounded',
                    fontSize: 16,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 27, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'История баллов',
            style: TextStyle(
              fontFamily: 'Unbounded',
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 19),
          Column(
            children: _loyaltyData!.history.map((historyItem) {
              final dateFormat = DateFormat('dd MMMM, HH:mm', 'ru_RU');
              final formattedDate = dateFormat.format(historyItem.date);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(17),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF3F4F6)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        SvgPicture.asset(
                          historyItem.type == PointsType.earned
                              ? 'assets/icons/loyalty/plus.svg'
                              : 'assets/icons/loyalty/minus.svg',
                          width: 16,
                          height: 16,
                          colorFilter: ColorFilter.mode(
                            historyItem.type == PointsType.earned
                                ? const Color(0xFFA5C572)
                                : const Color(0xFFDC2626),
                            BlendMode.srcIn,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              historyItem.description,
                              style: const TextStyle(
                                fontFamily: 'Unbounded',
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 23),
                            Text(
                              formattedDate,
                              style: const TextStyle(
                                fontFamily: 'Unbounded',
                                fontSize: 14,
                                color: Color(0xFF4B5563),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Text(
                      historyItem.type == PointsType.earned
                          ? '+${historyItem.points}'
                          : '-${historyItem.points}',
                      style: TextStyle(
                        fontFamily: 'Unbounded',
                        fontSize: 16,
                        color: historyItem.type == PointsType.earned
                            ? const Color(0xFFA5C572)
                            : const Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    if (_loyaltyData == null) {
      return const SizedBox.shrink();
    }

    final currentLevel = _loyaltyData!.getCurrentLevel();
    final nextLevel = _loyaltyData!.getNextLevel();
    final pointsToNextLevel = _loyaltyData!.getPointsToNextLevel();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 17, 16, 16),
      child: Column(
        children: [
          Text(
            'Вы накопили ${_loyaltyData!.points} баллов!',
            style: const TextStyle(
              fontFamily: 'Unbounded',
              fontSize: 14,
              color: Color(0xFF4B5563),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            nextLevel.level == currentLevel.level
                ? 'Вы достигли максимального уровня!'
                : 'Еще $pointsToNextLevel баллов, и вы получите ${nextLevel.reward} ${nextLevel.rewardDescription}!',
            style: const TextStyle(
              fontFamily: 'Unbounded',
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 47),
          GestureDetector(
            onTap: () {
              Navigator.of(context).pop(); // Возвращаемся на экран карты
            },
            child: Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  colors: [Color(0xFFF654AA), Color(0xFFA5C572)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Заработать больше баллов',
                    style: TextStyle(
                      fontFamily: 'Unbounded',
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 14),
                  SvgPicture.asset(
                    'assets/icons/loyalty/arrow_forward.svg',
                    width: 18,
                    height: 16,
                    colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
