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
  final DateTime? leaseStartDate;
  final DateTime? leaseEndDate;

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
    this.leaseStartDate,
    this.leaseEndDate,
  });

  int get daysRemaining {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return due.difference(today).inDays;
  }

  String get calculatedStatus {
    if (status == 'paid') return 'paid';
    if (status == 'payment_submitted') return 'payment_submitted';
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
      leaseStartDate: leaseStartDate,
      leaseEndDate: leaseEndDate,
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
  final String? chargeId;
  final bool isChargeClaim;

  Payment({
    required this.id,
    required this.residentId,
    required this.amount,
    required this.paymentMethod,
    this.transactionReference,
    required this.status,
    required this.paymentDate,
    this.receiptUrl,
    this.chargeId,
    this.isChargeClaim = false,
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
            chargeId: p['charge_id'],
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
        status: 'pending',
        paymentDate: now,
        receiptUrl: receiptUrl,
        chargeId: chargeIds.length == 1 ? chargeIds.first : null,
      );

      _mockPayments.insert(0, newPayment);

      // Update charges status
      _mockCharges = _mockCharges.map((c) {
        if (chargeIds.contains(c.id)) {
          return c.copyWith(status: 'payment_submitted');
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
              'status': 'pending',
              'payment_date': now,
              'receipt_url': receiptUrl,
              'charge_id': chargeIds.length == 1 ? chargeIds.first : null,
            })
            .select()
            .single();

        // Update charge statuses
        for (var chargeId in chargeIds) {
          await client
              .from('charges')
              .update({'status': 'payment_submitted'})
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
          chargeId: c.id,
          isChargeClaim: true,
        );
      }).toList();
      return [...paymentsFromCharges, ..._mockPayments];
    } else {
      try {
        final client = SupabaseClientHelper.client;
        final paymentRes = await client
            .from('payments')
            .select()
            .order('payment_date', ascending: false);

        final payments = (paymentRes as List).map((r) {
          return Payment(
            id: r['id'],
            residentId: r['resident_id'],
            amount: (r['amount'] as num).toDouble(),
            paymentMethod: r['payment_method'],
            transactionReference: r['transaction_reference'],
            status: r['status'],
            paymentDate: DateTime.parse(r['payment_date']),
            receiptUrl: r['receipt_url'],
            chargeId: r['charge_id'],
          );
        }).toList();

        final paidOrSubmittedChargeIds = payments
            .map((payment) => payment.chargeId)
            .whereType<String>()
            .toSet();
        final chargeRes = await client
            .from('charges')
            .select()
            .order('due_date', ascending: false);
        final claims = (chargeRes as List)
            .where((charge) => !paidOrSubmittedChargeIds.contains(charge['id']))
            .map(
              (charge) => Payment(
                id: 'claim-${charge['id']}',
                residentId: charge['resident_id'],
                amount: (charge['amount'] as num).toDouble(),
                paymentMethod: 'Waiting for tenant payment',
                transactionReference: charge['title'],
                status: 'claim_due',
                paymentDate: DateTime.parse(charge['due_date']),
                chargeId: charge['id'],
                isChargeClaim: true,
              ),
            )
            .toList();

        return [...payments, ...claims]
          ..sort((a, b) => b.paymentDate.compareTo(a.paymentDate));
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
        final activeLease = await client
            .from('leases')
            .select('id')
            .eq('resident_id', residentId)
            .eq('status', 'active')
            .maybeSingle();
        if (activeLease == null) {
          throw Exception('This tenant does not have an active lease.');
        }
        await client.from('charges').insert({
          'resident_id': residentId,
          'lease_id': activeLease['id'],
          'charge_type': chargeType,
          'title': title,
          'amount': amount,
          'due_date': dueDate.toIso8601String().split('T').first,
          'status': 'due',
          'description': description,
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

  /// Complete rent calendar used by the owner screen. Rent charges are created
  /// for every month of a lease by the database migration, so both the owner
  /// and tenant screens read the same payment status.
  Future<List<Charge>> getAllRentCharges() async {
    if (SupabaseClientHelper.isMockMode) {
      await Future.delayed(const Duration(milliseconds: 400));
      final now = DateTime.now();
      final tenants = <(String, String, double, DateTime, DateTime)>[
        ('mock-user-123', 'lease-101', 2200, DateTime(now.year, 1), DateTime(now.year, 12, 31)),
        ('mock-user-456', 'lease-102', 1900, DateTime(now.year, 1), DateTime(now.year, 12, 31)),
        ('mock-user-789', 'lease-103', 2500, DateTime(now.year, 2), DateTime(now.year + 1, 1, 31)),
      ];
      final result = <Charge>[];
      for (final tenant in tenants) {
        var month = DateTime(tenant.$4.year, tenant.$4.month);
        final last = DateTime(tenant.$5.year, tenant.$5.month);
        while (!month.isAfter(last)) {
          final existing = _mockCharges.where((c) =>
              c.residentId == tenant.$1 && c.chargeType == 'rent' &&
              c.dueDate.year == month.year && c.dueDate.month == month.month).firstOrNull;
          result.add(existing ?? Charge(
            id: 'rent-${tenant.$2}-${month.year}-${month.month}',
            residentId: tenant.$1,
            leaseId: tenant.$2,
            chargeType: 'rent',
            title: 'Rent ${month.month}/${month.year}',
            description: 'Monthly rent',
            amount: tenant.$3,
            dueDate: month,
            status: month.isAfter(DateTime(now.year, now.month)) ? 'upcoming' : 'due',
            createdAt: now,
          ));
          month = DateTime(month.year, month.month + 1);
        }
      }
      return result.map((c) => Charge(
        id: c.id, residentId: c.residentId, leaseId: c.leaseId,
        chargeType: c.chargeType, title: c.title, description: c.description,
        amount: c.amount, dueDate: c.dueDate, status: c.status,
        createdAt: c.createdAt,
        leaseStartDate: tenants.firstWhere((t) => t.$2 == c.leaseId).$4,
        leaseEndDate: tenants.firstWhere((t) => t.$2 == c.leaseId).$5,
      )).toList();
    }

    final rows = await SupabaseClientHelper.client
        .from('charges')
        .select('*, lease:leases!charges_lease_id_fkey(start_date,end_date)')
        .eq('charge_type', 'rent')
        .order('due_date', ascending: false);
    return (rows as List).map((c) {
      final lease = c['lease'] as Map<String, dynamic>?;
      return Charge(
        id: c['id'], residentId: c['resident_id'], leaseId: c['lease_id'],
        chargeType: c['charge_type'], title: c['title'],
        description: c['description'], amount: (c['amount'] as num).toDouble(),
        dueDate: DateTime.parse(c['due_date']), status: c['status'],
        createdAt: DateTime.parse(c['created_at']),
        leaseStartDate: lease == null ? null : DateTime.parse(lease['start_date']),
        leaseEndDate: lease == null ? null : DateTime.parse(lease['end_date']),
      );
    }).toList();
  }

  Future<void> confirmRentMonthPaid(Charge charge) async {
    if (SupabaseClientHelper.isMockMode) {
      final exists = _mockCharges.any((c) => c.id == charge.id);
      if (!exists) _mockCharges.add(charge);
      await updateChargeStatus(charge.id, 'paid');
      return;
    }
    final client = SupabaseClientHelper.client;
    await client.from('charges').update({'status': 'paid'}).eq('id', charge.id);
    await client.from('payments').update({'status': 'paid'}).eq('charge_id', charge.id).eq('status', 'pending');
    await client.from('notifications').insert({
      'resident_id': charge.residentId,
      'type': 'payment',
      'title': 'Rent payment confirmed',
      'message': '${charge.title} was marked as paid by the owner.',
      'related_entity_type': 'charge',
      'related_entity_id': charge.id,
    });
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

  Future<void> approvePayment(Payment payment) async {
    if (SupabaseClientHelper.isMockMode) {
      final index = _mockPayments.indexWhere((item) => item.id == payment.id);
      if (index != -1) {
        final old = _mockPayments[index];
        _mockPayments[index] = Payment(
          id: old.id,
          residentId: old.residentId,
          amount: old.amount,
          paymentMethod: old.paymentMethod,
          transactionReference: old.transactionReference,
          status: 'paid',
          paymentDate: old.paymentDate,
          receiptUrl: old.receiptUrl,
          chargeId: old.chargeId,
          isChargeClaim: old.isChargeClaim,
        );
      }
      if (payment.chargeId != null) {
        await updateChargeStatus(payment.chargeId!, 'paid');
      }
      return;
    }

    final client = SupabaseClientHelper.client;
    await client
        .from('payments')
        .update({'status': 'paid'})
        .eq('id', payment.id);
    if (payment.chargeId != null) {
      await client
          .from('charges')
          .update({'status': 'paid'})
          .eq('id', payment.chargeId!);
    }
    await client.from('notifications').insert({
      'resident_id': payment.residentId,
      'type': 'payment',
      'title': 'Payment approved',
      'message':
          'Your payment of \$${payment.amount.toStringAsFixed(2)} was approved.',
      'related_entity_type': 'payment',
      'related_entity_id': payment.id,
    });
  }
}
