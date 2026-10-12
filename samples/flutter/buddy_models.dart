import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/platform/platform_data.dart';

/// The cat artwork contains seven major states. The happiest state approves
/// 90% of requests, with each lower state reducing the chance by 10 points.
double catApprovalChance(double health) {
  final state = (health.clamp(0.0, 1.0) * 6).floor();
  return 0.9 - (6 - state) * 0.1;
}

bool decideCatRequest(double health, [math.Random? random]) =>
    (random ?? math.Random.secure()).nextDouble() < catApprovalChance(health);

class BuddyProfile {
  const BuddyProfile({required this.id, required this.name});

  final String id;
  final String name;

  factory BuddyProfile.fromDocument(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return BuddyProfile(
      id: doc.id,
      name: data.text('name', 'Buddy'),
    );
  }
}

class BuddyUsageRequest {
  const BuddyUsageRequest({
    required this.id,
    required this.requesterId,
    required this.requesterName,
    required this.createdAt,
    required this.expiresAt,
  });

  final String id;
  final String requesterId;
  final String requesterName;
  final DateTime? createdAt;
  final DateTime? expiresAt;

  factory BuddyUsageRequest.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const {};
    return BuddyUsageRequest(
      id: doc.id,
      requesterId: data.text('requesterId'),
      requesterName: data.text('requesterName', 'Your buddy'),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// Removes expired requests and keeps only the newest request from each buddy.
///
/// Older app versions could create several pending documents for the same
/// requester. Keeping this rule in the client makes those legacy duplicates
/// disappear immediately while the backend prevents new ones.
List<BuddyUsageRequest> activeBuddyRequests(
  Iterable<BuddyUsageRequest> requests,
  DateTime now,
) {
  final newestByRequester = <String, BuddyUsageRequest>{};
  for (final request in requests) {
    if (request.expiresAt?.isAfter(now) == false) continue;
    final key = request.requesterId.isEmpty ? request.id : request.requesterId;
    final existing = newestByRequester[key];
    final createdAt = request.createdAt ?? DateTime(0);
    final existingCreatedAt = existing?.createdAt ?? DateTime(0);
    if (existing == null || createdAt.isAfter(existingCreatedAt)) {
      newestByRequester[key] = request;
    }
  }
  return newestByRequester.values.toList()
    ..sort((a, b) =>
        (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
}
