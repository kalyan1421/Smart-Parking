// lib/models/partner_request.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum PartnerRequestStatus { pending, approved, rejected }

class PartnerRequest {
  final String id;
  final String userId;
  final String userEmail;
  final String userName;
  final String? businessName;
  final String? businessAddress;
  final String? phoneNumber;
  final String? reason; // Why they want to become a partner
  final PartnerRequestStatus status;
  final String? adminNotes; // Admin's notes on approval/rejection
  final DateTime createdAt;
  final DateTime? reviewedAt;
  final String? reviewedBy; // Admin user ID who reviewed

  PartnerRequest({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.userName,
    this.businessName,
    this.businessAddress,
    this.phoneNumber,
    this.reason,
    this.status = PartnerRequestStatus.pending,
    this.adminNotes,
    required this.createdAt,
    this.reviewedAt,
    this.reviewedBy,
  });

  // Factory constructor from Firestore document
  factory PartnerRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return PartnerRequest(
      id: doc.id,
      userId: data['userId'] ?? '',
      userEmail: data['userEmail'] ?? '',
      userName: data['userName'] ?? '',
      businessName: data['businessName'],
      businessAddress: data['businessAddress'],
      phoneNumber: data['phoneNumber'],
      reason: data['reason'],
      status: _parseStatus(data['status']),
      adminNotes: data['adminNotes'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
      reviewedBy: data['reviewedBy'],
    );
  }

  // Factory constructor from Map
  factory PartnerRequest.fromMap(Map<String, dynamic> data, String id) {
    return PartnerRequest(
      id: id,
      userId: data['userId'] ?? '',
      userEmail: data['userEmail'] ?? '',
      userName: data['userName'] ?? '',
      businessName: data['businessName'],
      businessAddress: data['businessAddress'],
      phoneNumber: data['phoneNumber'],
      reason: data['reason'],
      status: _parseStatus(data['status']),
      adminNotes: data['adminNotes'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
      reviewedBy: data['reviewedBy'],
    );
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userEmail': userEmail,
      'userName': userName,
      'businessName': businessName,
      'businessAddress': businessAddress,
      'phoneNumber': phoneNumber,
      'reason': reason,
      'status': status.name,
      'adminNotes': adminNotes,
      'createdAt': Timestamp.fromDate(createdAt),
      'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
      'reviewedBy': reviewedBy,
    };
  }

  // Helper method to parse status from string
  static PartnerRequestStatus _parseStatus(String? statusString) {
    switch (statusString) {
      case 'approved':
        return PartnerRequestStatus.approved;
      case 'rejected':
        return PartnerRequestStatus.rejected;
      default:
        return PartnerRequestStatus.pending;
    }
  }

  // Copy with method for updates
  PartnerRequest copyWith({
    String? userId,
    String? userEmail,
    String? userName,
    String? businessName,
    String? businessAddress,
    String? phoneNumber,
    String? reason,
    PartnerRequestStatus? status,
    String? adminNotes,
    DateTime? createdAt,
    DateTime? reviewedAt,
    String? reviewedBy,
  }) {
    return PartnerRequest(
      id: id,
      userId: userId ?? this.userId,
      userEmail: userEmail ?? this.userEmail,
      userName: userName ?? this.userName,
      businessName: businessName ?? this.businessName,
      businessAddress: businessAddress ?? this.businessAddress,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      adminNotes: adminNotes ?? this.adminNotes,
      createdAt: createdAt ?? this.createdAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
    );
  }

  @override
  String toString() {
    return 'PartnerRequest{id: $id, userId: $userId, status: ${status.name}}';
  }
}
