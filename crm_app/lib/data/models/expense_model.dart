import 'company_model.dart';
import 'user_model.dart';

class Expense {
  final String id;
  final String? companyId;
  final Company? company;
  final DateTime? date;
  final double amount;
  final double? amountReturn;
  final String? fromLocation;
  final String? toLocation;
  final String? purposeId;
  final String? purpose;
  final String? tripType;
  final String status;
  final String? createdByUserId;
  final User? createdByUser;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Expense({
    required this.id,
    this.companyId,
    this.company,
    this.date,
    required this.amount,
    this.amountReturn,
    this.fromLocation,
    this.toLocation,
    this.purposeId,
    this.purpose,
    this.tripType,
    this.status = 'unpaid',
    this.createdByUserId,
    this.createdByUser,
    this.createdAt,
    this.updatedAt,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id']?.toString() ?? '',
      companyId: json['companyId']?.toString(),
      company: json['company'] != null
          ? Company.fromJson(json['company'])
          : null,
      date: json['date'] != null
          ? DateTime.tryParse(json['date'].toString())
          : null,
      amount: json['amount'] != null
          ? double.tryParse(json['amount'].toString()) ?? 0.0
          : 0.0,
      amountReturn: json['amountReturn'] != null
          ? double.tryParse(json['amountReturn'].toString())
          : null,
      fromLocation: json['fromLocation'],
      toLocation: json['toLocation'],
      purposeId: json['purposeId']?.toString(),
      purpose: json['purpose'],
      tripType: json['tripType'],
      status: json['status'] ?? 'unpaid',
      createdByUserId: json['createdByUserId']?.toString(),
      createdByUser: json['createdByUser'] != null
          ? User.fromJson(json['createdByUser'])
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'companyId': companyId,
      'date': date?.toIso8601String().split('T')[0],
      'amount': amount,
      'amountReturn': amountReturn,
      'fromLocation': fromLocation,
      'toLocation': toLocation,
      'purposeId': purposeId,
      'purpose': purpose,
      'tripType': tripType,
      'status': status,
      'createdByUserId': createdByUserId,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  bool get isUnpaid => status == 'unpaid';
  bool get isPaid => status == 'paid';
  bool get isRoundTrip => tripType == 'round_trip';
  bool get isSingleTrip => tripType == 'single_trip';

  double get totalAmount => amount + (amountReturn ?? 0);

  String get formattedAmount => '\$${amount.toStringAsFixed(2)}';
  String get formattedTotalAmount => '\$${totalAmount.toStringAsFixed(2)}';
}

class ExpensePurpose {
  final String id;
  final String name;
  final int? sortOrder;
  final bool isActive;

  ExpensePurpose({
    required this.id,
    required this.name,
    this.sortOrder,
    this.isActive = true,
  });

  factory ExpensePurpose.fromJson(Map<String, dynamic> json) {
    return ExpensePurpose(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      sortOrder: json['sortOrder'],
      isActive: json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'sortOrder': sortOrder,
      'isActive': isActive,
    };
  }
}
