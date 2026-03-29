import 'user_model.dart';

class TodayAttendance {
  final String status; // 'pending', 'checked_in', 'checked_out', 'completed'
  final String date; // '2025-01-20'
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final bool isLate;
  final int? lateMinutes;
  final double? totalHours;
  final String? locationIn;
  final String? locationOut;

  TodayAttendance({
    required this.status,
    required this.date,
    this.checkInTime,
    this.checkOutTime,
    required this.isLate,
    this.lateMinutes,
    this.totalHours,
    this.locationIn,
    this.locationOut,
  });

  factory TodayAttendance.fromJson(Map<String, dynamic> json) {
    return TodayAttendance(
      status: json['status'] ?? 'pending',
      date: json['date'] ?? '',
      checkInTime: json['checkInTime'] != null
          ? DateTime.tryParse(json['checkInTime'].toString())
          : null,
      checkOutTime: json['checkOutTime'] != null
          ? DateTime.tryParse(json['checkOutTime'].toString())
          : null,
      isLate: json['isLate'] ?? false,
      lateMinutes: json['lateMinutes'],
      totalHours: json['totalHours']?.toDouble(),
      locationIn: json['locationIn'],
      locationOut: json['locationOut'],
    );
  }

  bool get isPending => status == 'pending';
  bool get isCheckedIn => status == 'checked_in';
  bool get isCheckedOut => status == 'checked_out' || status == 'completed';
}

class AttendanceRecord {
  final String id;
  final String date; // '2025-01-20'
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final double? durationHours;
  final String status; // 'present', 'late', 'early_leave', 'absent', 'half_day'
  final String? locationIn;
  final String? locationOut;
  final DateTime createdAt;
  final User? user; // for admin all-users view

  AttendanceRecord({
    required this.id,
    required this.date,
    this.checkInTime,
    this.checkOutTime,
    this.durationHours,
    required this.status,
    this.locationIn,
    this.locationOut,
    required this.createdAt,
    this.user,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id']?.toString() ?? '',
      date: json['date'] ?? '',
      checkInTime: json['checkInTime'] != null
          ? DateTime.tryParse(json['checkInTime'].toString())
          : null,
      checkOutTime: json['checkOutTime'] != null
          ? DateTime.tryParse(json['checkOutTime'].toString())
          : null,
      durationHours: json['durationHours']?.toDouble(),
      status: json['status'] ?? 'absent',
      locationIn: json['locationIn'],
      locationOut: json['locationOut'],
      createdAt:
          DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now(),
      user: json['user'] != null ? User.fromJson(json['user']) : null,
    );
  }
}
