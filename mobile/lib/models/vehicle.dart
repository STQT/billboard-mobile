class Vehicle {
  final int id;
  final String login;
  final String carNumber;
  final String tariff;
  final String? driverName;
  final String? phone;
  final bool isActive;
  final DateTime createdAt;

  Vehicle({
    required this.id,
    required this.login,
    required this.carNumber,
    required this.tariff,
    this.driverName,
    this.phone,
    required this.isActive,
    required this.createdAt,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'],
      login: json['login'],
      carNumber: json['car_number'],
      tariff: json['tariff'],
      driverName: json['driver_name'],
      phone: json['phone'],
      isActive: json['is_active'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'login': login,
      'car_number': carNumber,
      'tariff': tariff,
      'driver_name': driverName,
      'phone': phone,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
