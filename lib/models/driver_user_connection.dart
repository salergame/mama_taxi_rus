class DriverUserConnection {
  final String id;
  final String userId;
  final String driverId;
  final String userFullName;
  final String driverFullName;
  final String? userAvatarUrl;
  final String? driverAvatarUrl;
  final String? userPhone;
  final String? driverPhone;
  final ConnectionStatus status;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? rejectedAt;
  final String? rejectionReason;

  DriverUserConnection({
    required this.id,
    required this.userId,
    required this.driverId,
    required this.userFullName,
    required this.driverFullName,
    this.userAvatarUrl,
    this.driverAvatarUrl,
    this.userPhone,
    this.driverPhone,
    required this.status,
    required this.createdAt,
    this.acceptedAt,
    this.rejectedAt,
    this.rejectionReason,
  });

  factory DriverUserConnection.fromJson(Map<String, dynamic> json) {
    return DriverUserConnection(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      driverId: json['driver_id'] as String,
      userFullName: json['user_full_name'] as String? ?? '',
      driverFullName: json['driver_full_name'] as String? ?? '',
      userAvatarUrl: json['user_avatar_url'] as String?,
      driverAvatarUrl: json['driver_avatar_url'] as String?,
      userPhone: json['user_phone'] as String?,
      driverPhone: json['driver_phone'] as String?,
      status: ConnectionStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ConnectionStatus.pending,
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
      acceptedAt: json['accepted_at'] != null 
          ? DateTime.parse(json['accepted_at'] as String) 
          : null,
      rejectedAt: json['rejected_at'] != null 
          ? DateTime.parse(json['rejected_at'] as String) 
          : null,
      rejectionReason: json['rejection_reason'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'driver_id': driverId,
      'user_full_name': userFullName,
      'driver_full_name': driverFullName,
      'user_avatar_url': userAvatarUrl,
      'driver_avatar_url': driverAvatarUrl,
      'user_phone': userPhone,
      'driver_phone': driverPhone,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      'accepted_at': acceptedAt?.toIso8601String(),
      'rejected_at': rejectedAt?.toIso8601String(),
      'rejection_reason': rejectionReason,
    };
  }

  DriverUserConnection copyWith({
    String? id,
    String? userId,
    String? driverId,
    String? userFullName,
    String? driverFullName,
    String? userAvatarUrl,
    String? driverAvatarUrl,
    String? userPhone,
    String? driverPhone,
    ConnectionStatus? status,
    DateTime? createdAt,
    DateTime? acceptedAt,
    DateTime? rejectedAt,
    String? rejectionReason,
  }) {
    return DriverUserConnection(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      driverId: driverId ?? this.driverId,
      userFullName: userFullName ?? this.userFullName,
      driverFullName: driverFullName ?? this.driverFullName,
      userAvatarUrl: userAvatarUrl ?? this.userAvatarUrl,
      driverAvatarUrl: driverAvatarUrl ?? this.driverAvatarUrl,
      userPhone: userPhone ?? this.userPhone,
      driverPhone: driverPhone ?? this.driverPhone,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }
}

enum ConnectionStatus {
  pending,    // Ожидает ответа водителя
  accepted,   // Принято водителем
  rejected,   // Отклонено водителем
}

extension ConnectionStatusExtension on ConnectionStatus {
  String get displayName {
    switch (this) {
      case ConnectionStatus.pending:
        return 'Ожидает ответа';
      case ConnectionStatus.accepted:
        return 'Принято';
      case ConnectionStatus.rejected:
        return 'Отклонено';
    }
  }

  String get description {
    switch (this) {
      case ConnectionStatus.pending:
        return 'Водитель еще не ответил на предложение';
      case ConnectionStatus.accepted:
        return 'Водитель согласился стать вашим постоянным водителем';
      case ConnectionStatus.rejected:
        return 'Водитель отклонил предложение';
    }
  }
}
