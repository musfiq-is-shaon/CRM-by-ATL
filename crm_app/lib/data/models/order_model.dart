import '../../core/constants/app_constants.dart';
import 'company_model.dart';
import 'user_model.dart';

String _orderIdFromJson(Map<String, dynamic> json) {
  dynamic v = json['id'] ?? json['_id'];
  if (v is Map) {
    final oid = v[r'$oid'] ?? v['oid'];
    if (oid != null) return oid.toString().trim();
    v = v['id'] ?? v['_id'];
  }
  if (v == null) return '';
  final s = v.toString().trim();
  return s == 'null' || s.isEmpty ? '' : s;
}

class Order {
  final String id;
  final String? companyId;
  final Company? company;
  final String? salesId;
  final String? orderDetails;
  final double? revenue;
  final DateTime? orderConfirmationDate;
  final DateTime? deliveryDate;
  final String? assignTo;
  final User? assignToUser;
  final String? status;
  final String? nextAction;
  final DateTime? nextActionDate;
  final String? forwardedTo;
  final User? forwardedToUser;
  /// Present when API includes creator (e.g. `createdBy` / `createdByUser`).
  final User? createdByUser;
  /// Raw attachment list from API (e.g. `{ fileName, url }`); optional.
  final List<dynamic>? attachments;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Order({
    required this.id,
    this.companyId,
    this.company,
    this.salesId,
    this.orderDetails,
    this.revenue,
    this.orderConfirmationDate,
    this.deliveryDate,
    this.assignTo,
    this.assignToUser,
    this.status,
    this.nextAction,
    this.nextActionDate,
    this.forwardedTo,
    this.forwardedToUser,
    this.createdByUser,
    this.attachments,
    this.createdAt,
    this.updatedAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    User? parseUser(dynamic v) {
      if (v == null) return null;
      if (v is Map) {
        return User.fromJson(Map<String, dynamic>.from(v));
      }
      return null;
    }

    return Order(
      id: _orderIdFromJson(json),
      companyId: json['companyId']?.toString() ?? json['company_id']?.toString(),
      company: json['company'] != null
          ? Company.fromJson(Map<String, dynamic>.from(json['company'] as Map))
          : null,
      salesId:
          json['salesId']?.toString() ?? json['sales_id']?.toString(),
      orderDetails: json['orderDetails']?.toString() ??
          json['order_details']?.toString(),
      revenue: json['revenue'] != null
          ? double.tryParse(json['revenue'].toString())
          : null,
      orderConfirmationDate: json['orderConfirmationDate'] != null
          ? DateTime.tryParse(json['orderConfirmationDate'].toString())
          : null,
      deliveryDate: json['deliveryDate'] != null
          ? DateTime.tryParse(json['deliveryDate'].toString())
          : null,
      assignTo: json['assignTo'] is Map
          ? (json['assignTo'] as Map)['id']?.toString()
          : json['assignTo']?.toString(),
      assignToUser: parseUser(json['assignToUser']) ?? parseUser(json['assignTo']),
      status: json['status']?.toString(),
      nextAction: json['nextAction']?.toString(),
      nextActionDate: json['nextActionDate'] != null
          ? DateTime.tryParse(json['nextActionDate'].toString())
          : null,
      forwardedTo: json['forwardedTo'] is Map
          ? (json['forwardedTo'] as Map)['id']?.toString()
          : json['forwardedTo']?.toString(),
      forwardedToUser:
          parseUser(json['forwardedToUser']) ?? parseUser(json['forwardedTo']),
      createdByUser: parseUser(json['createdByUser']) ??
          parseUser(json['createdBy']) ??
          parseUser(json['created_by']),
      attachments: json['attachments'] is List
          ? List<dynamic>.from(json['attachments'] as List)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  String get formattedRevenue {
    if (revenue == null) return '${AppConstants.currencySymbol}0';
    return '${AppConstants.currencySymbol}${revenue!.toStringAsFixed(0)}';
  }

  Order copyWith({
    String? id,
    String? companyId,
    Company? company,
    String? salesId,
    String? orderDetails,
    double? revenue,
    DateTime? orderConfirmationDate,
    DateTime? deliveryDate,
    String? assignTo,
    User? assignToUser,
    String? status,
    String? nextAction,
    DateTime? nextActionDate,
    String? forwardedTo,
    User? forwardedToUser,
    User? createdByUser,
    List<dynamic>? attachments,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearCompany = false,
    bool clearAssignToUser = false,
    bool clearForwardedToUser = false,
    bool clearCreatedByUser = false,
    bool clearAttachments = false,
  }) {
    return Order(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      company: clearCompany ? null : (company ?? this.company),
      salesId: salesId ?? this.salesId,
      orderDetails: orderDetails ?? this.orderDetails,
      revenue: revenue ?? this.revenue,
      orderConfirmationDate:
          orderConfirmationDate ?? this.orderConfirmationDate,
      deliveryDate: deliveryDate ?? this.deliveryDate,
      assignTo: assignTo ?? this.assignTo,
      assignToUser: clearAssignToUser
          ? null
          : (assignToUser ?? this.assignToUser),
      status: status ?? this.status,
      nextAction: nextAction ?? this.nextAction,
      nextActionDate: nextActionDate ?? this.nextActionDate,
      forwardedTo: forwardedTo ?? this.forwardedTo,
      forwardedToUser: clearForwardedToUser
          ? null
          : (forwardedToUser ?? this.forwardedToUser),
      createdByUser: clearCreatedByUser
          ? null
          : (createdByUser ?? this.createdByUser),
      attachments: clearAttachments ? null : (attachments ?? this.attachments),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
