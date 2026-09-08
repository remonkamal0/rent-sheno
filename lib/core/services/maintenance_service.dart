import 'dart:async';
import '../api/supabase_client.dart';
import 'auth_service.dart';

class MaintenanceRequest {
  final String id;
  final String residentId;
  final String unitId;
  final String? unitNumber;
  final String? residentName;
  final String requestNumber;
  final String category; // plumbing, electrical, appliance, other
  final String title;
  final String description;
  final DateTime preferredDate;
  final String status; // pending, in_progress, scheduled, closed, cancelled
  final String? assignedTo;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? resolvedAt;
  final DateTime? scheduledFor;
  final String? visitPerson;
  final List<String> attachmentUrls;

  MaintenanceRequest({
    required this.id,
    required this.residentId,
    required this.unitId,
    this.unitNumber,
    this.residentName,
    required this.requestNumber,
    required this.category,
    required this.title,
    required this.description,
    required this.preferredDate,
    required this.status,
    this.assignedTo,
    required this.createdAt,
    required this.updatedAt,
    this.resolvedAt,
    this.scheduledFor,
    this.visitPerson,
    required this.attachmentUrls,
  });

  MaintenanceRequest copyWith({
    String? status,
    DateTime? resolvedAt,
    DateTime? scheduledFor,
    String? visitPerson,
    List<String>? attachmentUrls,
  }) {
    return MaintenanceRequest(
      id: id,
      residentId: residentId,
      unitId: unitId,
      unitNumber: unitNumber,
      residentName: residentName,
      requestNumber: requestNumber,
      category: category,
      title: title,
      description: description,
      preferredDate: preferredDate,
      status: status ?? this.status,
      assignedTo: assignedTo,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      resolvedAt: resolvedAt ?? this.resolvedAt,
      scheduledFor: scheduledFor ?? this.scheduledFor,
      visitPerson: visitPerson ?? this.visitPerson,
      attachmentUrls: attachmentUrls ?? this.attachmentUrls,
    );
  }
}

class MaintenanceService {
  final AuthService _authService;
  List<MaintenanceRequest> _mockRequests = [];

  MaintenanceService(this._authService) {
    _initMockData();
  }

  void _initMockData() {
    final now = DateTime.now();
    _mockRequests = [
      MaintenanceRequest(
        id: 'MR-2023-00124',
        residentId: 'mock-user-123',
        unitId: 'unit-402',
        unitNumber: 'Apt 402',
        residentName: 'John Doe',
        requestNumber: 'MR-2023-00124',
        category: 'plumbing',
        title: 'Leaking Kitchen Faucet',
        description:
            'The faucet in the kitchen sink has a constant drip that is getting worse. Need someone to fix it.',
        preferredDate: now.add(const Duration(days: 2)),
        status: 'pending',
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(days: 1)),
        attachmentUrls: [],
      ),
      MaintenanceRequest(
        id: 'MR-2023-00130',
        residentId: 'mock-user-201',
        unitId: 'unit-201',
        unitNumber: 'Apt 201',
        residentName: 'Sarah Connor',
        requestNumber: 'MR-2023-00130',
        category: 'electrical',
        title: 'Living Room Light Flickering',
        description: 'Main chandelier lights flicker intermittently in the evening.',
        preferredDate: now.add(const Duration(days: 1)),
        status: 'in_progress',
        createdAt: now.subtract(const Duration(hours: 12)),
        updatedAt: now.subtract(const Duration(hours: 4)),
        attachmentUrls: [],
      ),
      MaintenanceRequest(
        id: 'MR-2023-00135',
        residentId: 'mock-user-105',
        unitId: 'unit-105',
        unitNumber: 'Apt 105',
        residentName: 'Ahmed Ali',
        requestNumber: 'MR-2023-00135',
        category: 'appliance',
        title: 'Refrigerator Making Loud Noise',
        description: 'Compressor sounds very loud and vibrates constantly.',
        preferredDate: now.add(const Duration(days: 3)),
        status: 'scheduled',
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now.subtract(const Duration(days: 1)),
        attachmentUrls: [],
      ),
      MaintenanceRequest(
        id: 'MR-2023-00085',
        residentId: 'mock-user-123',
        unitId: 'unit-402',
        unitNumber: 'Apt 402',
        residentName: 'John Doe',
        requestNumber: 'MR-2023-00085',
        category: 'other',
        title: 'HVAC Filter Replacement',
        description: 'Standard bi-annual HVAC filter replacement requested.',
        preferredDate: now.subtract(const Duration(days: 15)),
        status: 'closed',
        createdAt: now.subtract(const Duration(days: 16)),
        updatedAt: now.subtract(const Duration(days: 15)),
        resolvedAt: now.subtract(const Duration(days: 15)),
        attachmentUrls: [],
      ),
      MaintenanceRequest(
        id: 'MR-2023-00052',
        residentId: 'mock-user-123',
        unitId: 'unit-402',
        unitNumber: 'Apt 402',
        residentName: 'John Doe',
        requestNumber: 'MR-2023-00052',
        category: 'other',
        title: 'Broken Window Blinds',
        description:
            'The cord on the living room blinds snapped. Cannot raise or lower them.',
        preferredDate: now.subtract(const Duration(days: 40)),
        status: 'closed',
        createdAt: now.subtract(const Duration(days: 43)),
        updatedAt: now.subtract(const Duration(days: 40)),
        resolvedAt: now.subtract(const Duration(days: 40)),
        attachmentUrls: [],
      ),
      MaintenanceRequest(
        id: 'MR-2023-00041',
        residentId: 'mock-user-304',
        unitId: 'unit-304',
        unitNumber: 'Apt 304',
        residentName: 'Michael Scott',
        requestNumber: 'MR-2023-00041',
        category: 'plumbing',
        title: 'Bathroom Drain Blocked',
        description: 'Shower drain unclogging requested.',
        preferredDate: now.subtract(const Duration(days: 60)),
        status: 'closed',
        createdAt: now.subtract(const Duration(days: 62)),
        updatedAt: now.subtract(const Duration(days: 60)),
        resolvedAt: now.subtract(const Duration(days: 60)),
        attachmentUrls: [],
      ),
    ];
  }

  static DateTime? _parseScheduledFor(dynamic val) {
    if (val == null) return null;
    final str = val.toString().trim();
    if (str.isEmpty) return null;

    final match =
        RegExp(r'(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2})').firstMatch(str);
    if (match != null) {
      return DateTime(
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
        int.parse(match.group(4)!),
        int.parse(match.group(5)!),
      );
    }
    return DateTime.tryParse(str);
  }

  Future<List<MaintenanceRequest>> getRequests() async {
    if (SupabaseClientHelper.isMockMode) {
      await Future.delayed(const Duration(milliseconds: 600));
      return _mockRequests;
    } else {
      try {
        final client = SupabaseClientHelper.client;
        final res = await client
            .from('maintenance_requests')
            .select(
              '*, units(unit_number), profiles:resident_id(full_name), maintenance_attachments(file_url)',
            )
            .eq('resident_id', _authService.currentUser?.id ?? '')
            .order('created_at', ascending: false);

        return (res as List).map((r) {
          final attachments =
              (r['maintenance_attachments'] as List?)
                  ?.map((a) => a['file_url'] as String)
                  .toList() ??
              [];
          final unitMap = r['units'] is Map ? r['units'] : null;
          final profileMap = r['profiles'] is Map
              ? r['profiles']
              : (r['resident'] is Map ? r['resident'] : null);

          return MaintenanceRequest(
            id: r['id'],
            residentId: r['resident_id'],
            unitId: r['unit_id'],
            unitNumber: unitMap?['unit_number'],
            residentName: profileMap?['full_name'],
            requestNumber: r['request_number'],
            category: r['category'],
            title: r['title'],
            description: r['description'],
            preferredDate: DateTime.parse(r['preferred_date']).toLocal(),
            status: r['status'],
            assignedTo: r['assigned_to'],
            createdAt: DateTime.parse(r['created_at']).toLocal(),
            updatedAt: DateTime.parse(r['updated_at']).toLocal(),
            resolvedAt: r['resolved_at'] != null
                ? DateTime.parse(r['resolved_at']).toLocal()
                : null,
            scheduledFor: _parseScheduledFor(r['scheduled_for']),
            visitPerson: r['visit_person'],
            attachmentUrls: attachments,
          );
        }).toList();
      } catch (e) {
        throw Exception(e.toString());
      }
    }
  }

  Future<MaintenanceRequest> createRequest({
    required String title,
    required String category,
    required String description,
    required DateTime preferredDate,
    required List<String> localAttachmentPaths,
  }) async {
    await Future.delayed(const Duration(seconds: 2)); // Simulate api upload

    final now = DateTime.now();
    final reqNo =
        'MR-${now.year}-${(now.millisecondsSinceEpoch % 100000).toString().padLeft(5, '0')}';

    if (SupabaseClientHelper.isMockMode) {
      final newReq = MaintenanceRequest(
        id: reqNo,
        residentId: 'mock-user-123',
        unitId: 'unit-402',
        unitNumber: 'Apt 402',
        residentName: _authService.currentUser?.fullName,
        requestNumber: reqNo,
        category: category,
        title: title,
        description: description,
        preferredDate: preferredDate,
        status: 'pending',
        createdAt: now,
        updatedAt: now,
        attachmentUrls:
            localAttachmentPaths, // locally we simulate file path listing
      );

      _mockRequests.insert(0, newReq);
      return newReq;
    } else {
      try {
        final client = SupabaseClientHelper.client;
        final residentId = _authService.currentUser?.id;

        // Fetch active lease to get the unit_id
        final leaseRes = await client
            .from('leases')
            .select('unit_id')
            .eq('resident_id', residentId ?? '')
            .eq('status', 'active')
            .maybeSingle();

        final unitId = leaseRes != null ? leaseRes['unit_id'] : null;
        if (residentId == null || unitId == null) {
          throw Exception('Unable to locate active unit/lease for this user.');
        }

        final insertRes = await client
            .from('maintenance_requests')
            .insert({
              'resident_id': residentId,
              'unit_id': unitId,
              'request_number': reqNo,
              'category': category,
              'title': title,
              'description': description,
              'preferred_date': preferredDate.toIso8601String().split('T')[0],
              'status': 'pending',
              'created_at': DateTime.now().toUtc().toIso8601String(),
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .select()
            .single();

        final requestId = insertRes['id'];

        // Save attachments if any
        for (var fileUrl in localAttachmentPaths) {
          await client.from('maintenance_attachments').insert({
            'maintenance_request_id': requestId,
            'file_url': fileUrl,
            'file_type': fileUrl.endsWith('.pdf')
                ? 'application/pdf'
                : 'image/png',
          });
        }

        return MaintenanceRequest(
          id: requestId,
          residentId: residentId,
          unitId: unitId,
          requestNumber: reqNo,
          category: category,
          title: title,
          description: description,
          preferredDate: preferredDate,
          status: 'pending',
          createdAt: now,
          updatedAt: now,
          attachmentUrls: localAttachmentPaths,
        );
      } catch (e) {
        throw Exception(e.toString());
      }
    }
  }

  Future<List<MaintenanceRequest>> getAllRequests() async {
    if (SupabaseClientHelper.isMockMode) {
      await Future.delayed(const Duration(milliseconds: 600));
      return _mockRequests;
    } else {
      try {
        final client = SupabaseClientHelper.client;
        final res = await client
            .from('maintenance_requests')
            .select(
              '*, units(unit_number), profiles:resident_id(full_name), maintenance_attachments(file_url)',
            )
            .order('created_at', ascending: false);

        return (res as List).map((r) {
          final attachments =
              (r['maintenance_attachments'] as List?)
                  ?.map((a) => a['file_url'] as String)
                  .toList() ??
              [];
          final unitMap = r['units'] is Map ? r['units'] : null;
          final profileMap = r['profiles'] is Map
              ? r['profiles']
              : (r['resident'] is Map ? r['resident'] : null);

          return MaintenanceRequest(
            id: r['id'],
            residentId: r['resident_id'],
            unitId: r['unit_id'],
            unitNumber: unitMap?['unit_number'],
            residentName: profileMap?['full_name'],
            requestNumber: r['request_number'],
            category: r['category'],
            title: r['title'],
            description: r['description'],
            preferredDate: DateTime.parse(r['preferred_date']).toLocal(),
            status: r['status'],
            assignedTo: r['assigned_to'],
            createdAt: DateTime.parse(r['created_at']).toLocal(),
            updatedAt: DateTime.parse(r['updated_at']).toLocal(),
            resolvedAt: r['resolved_at'] != null
                ? DateTime.parse(r['resolved_at']).toLocal()
                : null,
            scheduledFor: _parseScheduledFor(r['scheduled_for']),
            visitPerson: r['visit_person'],
            attachmentUrls: attachments,
          );
        }).toList();
      } catch (e) {
        throw Exception(e.toString());
      }
    }
  }

  Future<void> updateRequestStatus(String requestId, String status) async {
    if (SupabaseClientHelper.isMockMode) {
      await Future.delayed(const Duration(milliseconds: 600));
      final index = _mockRequests.indexWhere((r) => r.id == requestId);
      if (index != -1) {
        final current = _mockRequests[index];
        _mockRequests[index] = current.copyWith(
          status: status,
          resolvedAt: status == 'closed' ? DateTime.now() : null,
        );
      }
    } else {
      try {
        final client = SupabaseClientHelper.client;
        final Map<String, dynamic> updateData = {
          'status': status,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        };
        if (status == 'closed') {
          updateData['resolved_at'] = DateTime.now().toUtc().toIso8601String();
        }
        await client
            .from('maintenance_requests')
            .update(updateData)
            .eq('id', requestId);
      } catch (e) {
        throw Exception(e.toString());
      }
    }
  }

  Future<void> scheduleVisit({
    required String requestId,
    required DateTime scheduledFor,
    required String visitPerson,
  }) async {
    if (visitPerson.trim().isEmpty) {
      throw ArgumentError('Visitor or technician name is required.');
    }
    if (SupabaseClientHelper.isMockMode) {
      final index = _mockRequests.indexWhere((request) => request.id == requestId);
      if (index == -1) throw StateError('Maintenance request not found.');
      _mockRequests[index] = _mockRequests[index].copyWith(
        status: 'scheduled',
        scheduledFor: scheduledFor,
        visitPerson: visitPerson.trim(),
      );
      return;
    }

    // Save exact wall-clock date and time (without UTC shifting):
    final isoString = '${scheduledFor.year.toString().padLeft(4, '0')}-'
        '${scheduledFor.month.toString().padLeft(2, '0')}-'
        '${scheduledFor.day.toString().padLeft(2, '0')}T'
        '${scheduledFor.hour.toString().padLeft(2, '0')}:'
        '${scheduledFor.minute.toString().padLeft(2, '0')}:00';

    await SupabaseClientHelper.client
        .from('maintenance_requests')
        .update({
          'status': 'scheduled',
          'scheduled_for': isoString,
          'visit_person': visitPerson.trim(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', requestId);
  }
}
