import 'dart:async';
import 'package:flutter/foundation.dart';
import '../api/supabase_client.dart';
import 'auth_service.dart';

class InsurancePolicy {
  final String id;
  final String residentId;
  final String provider;
  final String policyNumber;
  final double coverageAmount;
  final double deductible;
  final DateTime effectiveDate;
  final DateTime expirationDate;
  final String? documentUrl;
  final String status; // active, expired, expiring_soon, pending

  InsurancePolicy({
    required this.id,
    required this.residentId,
    required this.provider,
    required this.policyNumber,
    required this.coverageAmount,
    required this.deductible,
    required this.effectiveDate,
    required this.expirationDate,
    this.documentUrl,
    required this.status,
  });

  int get daysUntilExpiration {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiry = DateTime(expirationDate.year, expirationDate.month, expirationDate.day);
    return expiry.difference(today).inDays;
  }

  String get calculatedStatus {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiry = DateTime(expirationDate.year, expirationDate.month, expirationDate.day);

    if (expiry.isBefore(today)) {
      return 'expired';
    } else {
      final diff = expiry.difference(today).inDays;
      if (diff <= 30) {
        return 'expiring_soon';
      }
      return 'active';
    }
  }

  InsurancePolicy copyWith({
    String? provider,
    String? policyNumber,
    double? coverageAmount,
    double? deductible,
    DateTime? effectiveDate,
    DateTime? expirationDate,
    String? documentUrl,
    String? status,
  }) {
    return InsurancePolicy(
      id: id,
      residentId: residentId,
      provider: provider ?? this.provider,
      policyNumber: policyNumber ?? this.policyNumber,
      coverageAmount: coverageAmount ?? this.coverageAmount,
      deductible: deductible ?? this.deductible,
      effectiveDate: effectiveDate ?? this.effectiveDate,
      expirationDate: expirationDate ?? this.expirationDate,
      documentUrl: documentUrl ?? this.documentUrl,
      status: status ?? this.status,
    );
  }
}

class InsuranceService {
  final AuthService _authService;
  InsurancePolicy? _mockPolicy;

  InsuranceService(this._authService) {
    _initMockData();
  }

  void _initMockData() {
    final now = DateTime.now();
    _mockPolicy = InsurancePolicy(
      id: 'policy-101',
      residentId: 'mock-user-123',
      provider: 'SafeGuard Home Insurance',
      policyNumber: 'SG-9842-1049-XZ',
      coverageAmount: 50000.0,
      deductible: 500.0,
      effectiveDate: DateTime(now.year, 1, 1),
      expirationDate: DateTime(now.year, 12, 31),
      documentUrl: 'https://example.com/insurance/policy-doc.pdf',
      status: 'active',
    );
  }

  Future<InsurancePolicy?> getPolicy() async {
    if (SupabaseClientHelper.isMockMode) {
      await Future.delayed(const Duration(milliseconds: 500));
      return _mockPolicy;
    } else {
      try {
        final client = SupabaseClientHelper.client;
        final res = await client
            .from('insurance_policies')
            .select()
            .eq('resident_id', _authService.currentUser?.id ?? '')
            .maybeSingle();

        if (res == null) return null;

        return InsurancePolicy(
          id: res['id'],
          residentId: res['resident_id'],
          provider: res['provider'],
          policyNumber: res['policy_number'],
          coverageAmount: (res['coverage_amount'] as num).toDouble(),
          deductible: (res['deductible'] as num).toDouble(),
          effectiveDate: DateTime.parse(res['effective_date']),
          expirationDate: DateTime.parse(res['expiration_date']),
          documentUrl: res['document_url'],
          status: res['status'],
        );
      } catch (e) {
        throw Exception(e.toString());
      }
    }
  }

  Future<InsurancePolicy?> getPolicyForResident(String residentId) async {
    if (SupabaseClientHelper.isMockMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      return _mockPolicy;
    } else {
      try {
        final client = SupabaseClientHelper.client;
        final res = await client
            .from('insurance_policies')
            .select()
            .eq('resident_id', residentId)
            .maybeSingle();

        if (res == null) return null;

        return InsurancePolicy(
          id: res['id'],
          residentId: res['resident_id'],
          provider: res['provider'],
          policyNumber: res['policy_number'],
          coverageAmount: (res['coverage_amount'] as num).toDouble(),
          deductible: (res['deductible'] as num).toDouble(),
          effectiveDate: DateTime.parse(res['effective_date']),
          expirationDate: DateTime.parse(res['expiration_date']),
          documentUrl: res['document_url'],
          status: res['status'],
        );
      } catch (e) {
        throw Exception(e.toString());
      }
    }
  }

  Future<InsurancePolicy> updatePolicy({
    required String provider,
    required String policyNumber,
    required double coverageAmount,
    required DateTime expirationDate,
    String? localDocumentPath,
  }) async {
    await Future.delayed(const Duration(seconds: 2)); // Simulate api call

    final now = DateTime.now();
    final effectiveDate = DateTime(now.year, now.month, now.day);
    
    if (SupabaseClientHelper.isMockMode) {
      _mockPolicy = InsurancePolicy(
        id: _mockPolicy?.id ?? 'policy-101',
        residentId: 'mock-user-123',
        provider: provider,
        policyNumber: policyNumber,
        coverageAmount: coverageAmount,
        deductible: _mockPolicy?.deductible ?? 500.0,
        effectiveDate: effectiveDate,
        expirationDate: expirationDate,
        documentUrl: localDocumentPath ?? _mockPolicy?.documentUrl,
        status: 'active',
      );
      
      // Force status update based on expiration date
      final status = _mockPolicy!.calculatedStatus;
      _mockPolicy = _mockPolicy!.copyWith(status: status);

      return _mockPolicy!;
    } else {
      try {
        final client = SupabaseClientHelper.client;
        final residentId = _authService.currentUser?.id;
        if (residentId == null) {
          throw Exception('User session missing.');
        }

        final payload = {
          'resident_id': residentId,
          'provider': provider,
          'policy_number': policyNumber,
          'coverage_amount': coverageAmount,
          'deductible': 500.0,
          'effective_date': effectiveDate.toIso8601String().split('T')[0],
          'expiration_date': expirationDate.toIso8601String().split('T')[0],
          'document_url': localDocumentPath,
          'status': 'active',
          'updated_at': now.toUtc().toIso8601String(),
        };

        InsurancePolicy? current = await getPolicy();
        late Map<String, dynamic> res;

        if (current == null) {
          // insert new
          payload['created_at'] = now.toUtc().toIso8601String();
          res = await client.from('insurance_policies').insert(payload).select().single();
        } else {
          // update existing
          res = await client
              .from('insurance_policies')
              .update(payload)
              .eq('id', current.id)
              .select()
              .single();
        }

        final updatedPolicy = InsurancePolicy(
          id: res['id'],
          residentId: res['resident_id'],
          provider: res['provider'],
          policyNumber: res['policy_number'],
          coverageAmount: (res['coverage_amount'] as num).toDouble(),
          deductible: (res['deductible'] as num).toDouble(),
          effectiveDate: DateTime.parse(res['effective_date']),
          expirationDate: DateTime.parse(res['expiration_date']),
          documentUrl: res['document_url'],
          status: res['status'],
        );

        // Update correct status based on date calculations
        final finalStatus = updatedPolicy.calculatedStatus;
        if (finalStatus != updatedPolicy.status) {
          await client
              .from('insurance_policies')
              .update({'status': finalStatus})
              .eq('id', updatedPolicy.id);
          return updatedPolicy.copyWith(status: finalStatus);
        }

        return updatedPolicy;
      } catch (e) {
        throw Exception(e.toString());
      }
    }
  }
}
