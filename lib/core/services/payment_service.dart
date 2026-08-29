import 'dart:async';
import 'package:flutter/foundation.dart';
import '../api/supabase_client.dart';
import 'auth_service.dart';

class Charge {
  final String id;
  final String residentId;
  final String leaseId;
  final String chargeType;
  final String title;
  final String? description;
  final double amount;
  final DateTime dueDate;
  final String status; // paid, upcoming, due, past_due
  final DateTime createdAt;

  Charge({
    required this.id,
    required this.residentId,
    required this.leaseId,
    required this.chargeType,
    required this.title,
    this.description,
    required this.amount,
    required this.dueDate,
    required this.status,
    required this.createdAt,
  });

  int get daysRemaining {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return due.difference(today).inDays;
  }

  String get calculatedStatus {
    if (status == 'paid') return 'paid';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);

    if (due.isBefore(today)) {
      return 'past_due';
    } else if (due.isAtSameMomentAs(today)) {
      return 'due';
    } else {
      return 'upcoming';
    }
  }

  Charge copyWith({String? status}) {
    return Charge(
      id: id,
      residentId: residentId,
      leaseId: leaseId,
      chargeType: chargeType,
      title: title,
      description: description,
      amount: amount,
      dueDate: dueDate,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }
}

class Payment {
  final String id;
  final String residentId;
  final double amount;
  final String paymentMethod;
  final String? transactionReference;
  final String status; // paid, pending, failed, refunded
  final DateTime paymentDate;
  final String? receiptUrl;

  Payment({
    required this.id,
    required this.residentId,
    required this.amount,
    required this.paymentMethod,
    this.transactionReference,
    required this.status,
    required this.paymentDate,
    this.receiptUrl,
  });
}

class PaymentService {
  final AuthService _authService;
  List<Charge> _mockCharges = [];
  List<Payment> _mockPayments = [];

  PaymentService(this._authService) {
    _initMockData();
  }

  void _initMockData() {
    final now = DateTime.now();
    _mockCharges = [
      Charge(
        id: 'charge-paid-1',
        residentId: 'mock-user-123',
        leaseId: 'lease-101',
        chargeType: 'rent',
        title: 'September Rent',
        description: 'Base lease amount',
        amount: 2200.0,
        dueDate: now.subtract(const Duration(days: 25)),
        status: 'paid',
        createdAt: now.subtract(const Duration(days: 40)),
      ),
      Charge(
        id: 'charge-1',
        residentId: 'mock-user-123',
        leaseId: 'lease-101',
        chargeType: 'rent',
        title: 'October Rent',
        description: 'Base lease amount',
        amount: 2200.0,
        dueDate: now.add(const Duration(days: 5)),
        status: 'upcoming',
        createdAt: now.subtract(const Duration(days: 10)),
      ),
      Charge(
        id: 'charge-2',
        residentId: 'mock-user-123',
        leaseId: 'lease-101',
        chargeType: 'parking',
        title: 'Reserved Parking',
        description: 'Spot #42',
        amount: 150.0,
        dueDate: now.add(const Duration(days: 5)),
        status: 'upcoming',
        createdAt: now.subtract(const Duration(days: 10)),
      ),
      Charge(
        id: 'charge-3',
        residentId: 'mock-user-123',
        leaseId: 'lease-101',
        chargeType: 'fee',
        title: 'Late Fee',
        description: 'Applied Oct 6, 2023',
        amount: 100.0,
        dueDate: now.subtract(const Duration(days: 3)),
        status: 'past_due',
        createdAt: now.subtract(const Duration(days: 4)),
      ),
    ];

    _mockPayments = [
      Payment(
        id: 'TXN-98234-01',
        residentId: 'mock-user-123',
        amount: 2350.0,
        paymentMethod: 'Credit Card (**** 4242)',
        transactionReference: 'ch_3Mv8sRLkdIwHu7ix',
        status: 'paid',
        paymentDate: now.subtract(const Duration(days: 30)),
      ),
    ];
  }

  Future<List<Charge>> getCharges() async {
    if (SupabaseClientHelper.isMockMode) {
      await Future.delayed(const Duration(milliseconds: 600));
      return _mockCharges;
    } else {
      try {
        final client = SupabaseClientHelper.client;
        final res = await client
            .from('charges')
            .select()
            .eq('resident_id', _authService.currentUser?.id ?? '');

        return (res as List).map((c) {
          return Charge(
            id: c['id'],
            residentId: c['resident_id'],
            leaseId: c['lease_id'],
            chargeType: c['charge_type'],
            title: c['title'],
            description: c['description'],
            amount: (c['amount'] as num).toDouble(),
            dueDate: DateTime.parse(c['due_date']),
            status: c['status'],
            createdAt: DateTime.parse(c['created_at']),
          );
        }).toList();
      } catch (e) {
        throw Exception(e.toString());
      }
    }
  }

  Future<List<Payment>> getPaymentHistory() async {
    if (SupabaseClientHelper.isMockMode) {
      await Future.delayed(const Duration(milliseconds: 500));
      return _mockPayments;
    } else {
      try {
        final client = SupabaseClientHelper.client;
        final res = await client
            .from('payments')
            .select()
            .eq('resident_id', _authService.currentUser?.id ?? '')
            .order('payment_date', ascending: false);

        return (res as List).map((p) {
          return Payment(
            id: p['id'],
            residentId: p['resident_id'],
            amount: (p['amount'] as num).toDouble(),
            paymentMethod: p['payment_method'],
            transactionReference: p['transaction_reference'],
            status: p['status'],
            paymentDate: DateTime.parse(p['payment_date']),
            receiptUrl: p['receipt_url'],
          );
        }).toList();
      } catch (e) {
        throw Exception(e.toString());
      }
    }
  }

  Future<bool> makePayment({
    required List<String> chargeIds,
    required double totalAmount,
    required String paymentMethod,
    String? receiptUrl,
  }) async {
    await Future.delayed(const Duration(seconds: 2)); // Simulate processing

    if (SupabaseClientHelper.isMockMode) {
      // Create new payment record
      final now = DateTime.now();
      final newPayment = Payment(
        id: 'TXN-${now.millisecondsSinceEpoch ~/ 1000}',
        residentId: 'mock-user-123',
        amount: totalAmount,
        paymentMethod: paymentMethod,
        transactionReference: 'mock_ref_${now.millisecondsSinceEpoch}',
        status: 'paid',
        paymentDate: now,
        receiptUrl: receiptUrl,
      );

      _mockPayments.insert(0, newPayment);

      // Update charges status
      _mockCharges = _mockCharges.map((c) {
        if (chargeIds.contains(c.id)) {
          return c.copyWith(status: 'paid');
        }
        return c;
      }).toList();

      return true;
    } else {
      try {
        final client = SupabaseClientHelper.client;
        final now = DateTime.now().toUtc().toIso8601String();
        final residentId = _authService.currentUser?.id;

        if (residentId == null) return false;

        // Insert payment details
        final paymentRes = await client
            .from('payments')
            .insert({
              'resident_id': residentId,
              'amount': totalAmount,
              'payment_method': paymentMethod,
              'transaction_reference':
                  'ref_${DateTime.now().millisecondsSinceEpoch}',
              'status': 'paid',
              'payment_date': now,
              'receipt_url': receiptUrl,
            })
            .select()
            .single();

        // Update charge statuses
        for (var chargeId in chargeIds) {
          await client
              .from('charges')
              .update({'status': 'paid'})
              .eq('id', chargeId);
        }

        return true;
      } catch (e) {
        throw Exception(e.toString());
      }
    }
  }

  Future<List<Payment>> getAllPayments() async {
    if (SupabaseClientHelper.isMockMode) {
      await Future.delayed(const Duration(milliseconds: 600));
      final List<Payment> paymentsFromCharges = _mockCharges.map((c) {
        return Payment(
          id: c.id,
          residentId: c.residentId,
          amount: c.amount,
          paymentMethod: 'Offline Payment (Check/Cash)',
          transactionReference: c.title,
          status: c.status == 'paid' ? 'paid' : 'pending',
          paymentDate: c.dueDate,
        );
      }).toList();
      return [...paymentsFromCharges, ..._mockPayments];
    } else {
      try {
        final client = SupabaseClientHelper.client;
        final res = await client
            .from('payments')
            .select()
            .order('payment_date', ascending: false);

        return (res as List).map((r) {
          return Payment(
            id: r['id'],
            residentId: r['resident_id'],
            amount: (r['amount'] as num).toDouble(),
            paymentMethod: r['payment_method'],
            transactionReference: r['transaction_reference'],
            status: r['status'],
            paymentDate: DateTime.parse(r['payment_date']),
            receiptUrl: r['receipt_url'],
          );
        }).toList();
      } catch (e) {
        throw Exception(e.toString());
      }
    }
  }

  Future<void> createCharge({
    required String residentId,
    required String leaseId,
    required String chargeType,
    required String title,
    required double amount,
    required DateTime dueDate,
    String? description,
  }) async {
    if (SupabaseClientHelper.isMockMode) {
      await Future.delayed(const Duration(milliseconds: 500));
      final newCharge = Charge(
        id: 'CHG-${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
        residentId: residentId,
        leaseId: leaseId,
        chargeType: chargeType,
        title: title,
        amount: amount,
        dueDate: dueDate,
        status: 'due',
        createdAt: DateTime.now(),
        description: description,
      );
      _mockCharges.insert(0, newCharge);
    } else {
      try {
        final client = SupabaseClientHelper.client;
        await client.from('charges').insert({
          'resident_id': residentId,
          'lease_id': leaseId,
          'charge_type': chargeType,
          'title': title,
          'amount': amount,
          'due_date': dueDate.toIso8601String().split('T').first,
          'status': 'due',
        });
      } catch (e) {
        throw Exception(e.toString());
      }
    }
  }

  Future<List<Charge>> getChargesForResident(String residentId) async {
    if (SupabaseClientHelper.isMockMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      return _mockCharges.where((c) => c.residentId == residentId).toList();
    } else {
      try {
        final client = SupabaseClientHelper.client;
        final res = await client
            .from('charges')
            .select()
            .eq('resident_id', residentId);

        return (res as List).map((c) {
          return Charge(
            id: c['id'],
            residentId: c['resident_id'],
            leaseId: c['lease_id'],
            chargeType: c['charge_type'],
            title: c['title'],
            description: c['description'],
            amount: (c['amount'] as num).toDouble(),
            dueDate: DateTime.parse(c['due_date']),
            status: c['status'],
            createdAt: DateTime.parse(c['created_at']),
          );
        }).toList();
      } catch (e) {
        throw Exception(e.toString());
      }
    }
  }

  Future<void> updateChargeStatus(String chargeId, String status) async {
    if (SupabaseClientHelper.isMockMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      _mockCharges = _mockCharges.map((c) {
        if (c.id == chargeId) {
          if (status == 'paid' && c.status != 'paid') {
            final now = DateTime.now();
            final paymentRecord = Payment(
              id: 'TXN-${now.millisecondsSinceEpoch ~/ 1000}',
              residentId: c.residentId,
              amount: c.amount,
              paymentMethod: 'Offline Payment (Check/Cash)',
              transactionReference: 'ch_${c.id}',
              status: 'paid',
              paymentDate: now,
            );
            _mockPayments.insert(0, paymentRecord);
          }
          return c.copyWith(status: status);
        }
        return c;
      }).toList();
    } else {
      try {
        final client = SupabaseClientHelper.client;
        await client
            .from('charges')
            .update({'status': status})
            .eq('id', chargeId);
      } catch (e) {
        throw Exception(e.toString());
      }
    }
  }
}
