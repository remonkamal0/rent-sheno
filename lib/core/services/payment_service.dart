import 'dart:async';
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
  final double lateFee;
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
    this.lateFee = 0.0,
    required this.dueDate,
    required this.status,
    required this.createdAt,
    this.leaseStartDate,
    this.leaseEndDate,
  });

  double get totalAmount => amount + lateFee;

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

  Charge copyWith({
    String? status,
    double? amount,
    double? lateFee,
    String? title,
    String? description,
    DateTime? dueDate,
  }) {
    return Charge(
      id: id,
      residentId: residentId,
      leaseId: leaseId,
      chargeType: chargeType,
      title: title ?? this.title,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      lateFee: lateFee ?? this.lateFee,
      dueDate: dueDate ?? this.dueDate,
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
        final residentId = _authService.currentUser?.id ?? '';

        final activeLeaseRes = await client
            .from('leases')
            .select('monthly_rent, start_date, end_date')
            .eq('resident_id', residentId)
            .eq('status', 'active')
            .maybeSingle();
        final activeRent = (activeLeaseRes?['monthly_rent'] as num?)?.toDouble();

        final res = await client
            .from('charges')
            .select('*, lease:leases!charges_lease_id_fkey(status,monthly_rent)')
            .eq('resident_id', residentId);

        final rawList = (res as List).map((c) {
          final lease = c['lease'] as Map<String, dynamic>?;
          final leaseStatus = lease?['status'] as String?;
          final leaseRent = (lease?['monthly_rent'] as num?)?.toDouble();
          final resolvedAmount = c['charge_type'] == 'rent'
              ? (activeRent ?? leaseRent ?? (c['amount'] as num).toDouble())
              : (c['amount'] as num).toDouble();
          final lateFee = (c['late_fee'] as num?)?.toDouble() ?? 0.0;

          return (
            charge: Charge(
              id: c['id'],
              residentId: c['resident_id'],
              leaseId: c['lease_id'] ?? '',
              chargeType: c['charge_type'],
              title: c['title'],
              description: c['description'],
              amount: resolvedAmount,
              lateFee: lateFee,
              dueDate: DateTime.parse(c['due_date']),
              status: c['status'],
              createdAt: DateTime.parse(c['created_at']),
            ),
            isActiveLease: leaseStatus == null || leaseStatus == 'active',
          );
        }).toList();

        final Map<String, Charge> uniqueMap = {};
        for (final item in rawList) {
          if (!item.isActiveLease && item.charge.status != 'paid') continue;
          final key =
              '${item.charge.chargeType}-${item.charge.dueDate.year}-${item.charge.dueDate.month}-${item.charge.title}';
          final normalizedCharge = item.charge.chargeType == 'rent' && activeRent != null
              ? item.charge.copyWith(amount: activeRent)
              : item.charge;

          if (!uniqueMap.containsKey(key)) {
            uniqueMap[key] = normalizedCharge;
          } else if (item.charge.status == 'paid') {
            uniqueMap[key] = normalizedCharge;
          }
        }

        return uniqueMap.values.toList();
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
        await client
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
            });

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
            .select('*, lease:leases!charges_lease_id_fkey(status,monthly_rent)')
            .eq('resident_id', residentId)
            .order('due_date', ascending: true);

        final activeLeaseRes = await client
            .from('leases')
            .select('monthly_rent, start_date, end_date')
            .eq('resident_id', residentId)
            .eq('status', 'active')
            .maybeSingle();
        final activeRent = (activeLeaseRes?['monthly_rent'] as num?)?.toDouble();

        final rawList = (res as List).map((c) {
          final lease = c['lease'] as Map<String, dynamic>?;
          final leaseStatus = lease?['status'] as String?;
          final leaseRent = (lease?['monthly_rent'] as num?)?.toDouble();
          final resolvedAmount = c['charge_type'] == 'rent'
              ? (activeRent ?? leaseRent ?? (c['amount'] as num).toDouble())
              : (c['amount'] as num).toDouble();
          final lateFee = (c['late_fee'] as num?)?.toDouble() ?? 0.0;

          return (
            charge: Charge(
              id: c['id'],
              residentId: c['resident_id'],
              leaseId: c['lease_id'] ?? '',
              chargeType: c['charge_type'],
              title: c['title'],
              description: c['description'],
              amount: resolvedAmount,
              lateFee: lateFee,
              dueDate: DateTime.parse(c['due_date']),
              status: c['status'],
              createdAt: DateTime.parse(c['created_at']),
            ),
            isActiveLease: leaseStatus == null || leaseStatus == 'active',
          );
        }).toList();

        final Map<String, Charge> uniqueMap = {};
        for (final item in rawList) {
          if (!item.isActiveLease && item.charge.status != 'paid') continue;
          final key =
              '${item.charge.chargeType}-${item.charge.dueDate.year}-${item.charge.dueDate.month}';

          if (!uniqueMap.containsKey(key)) {
            uniqueMap[key] = item.charge;
          } else {
            // If one is paid, ALWAYS keep the paid one
            if (item.charge.status == 'paid') {
              uniqueMap[key] = item.charge;
            }
          }
        }

        final result = uniqueMap.values.toList()
          ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
        return result;
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

    final client = SupabaseClientHelper.client;

    // Pre-fetch active leases for all residents to get the authoritative monthly_rent & lease dates
    final activeLeasesRes = await client
        .from('leases')
        .select('resident_id, monthly_rent, start_date, end_date')
        .eq('status', 'active');

    final Map<String, double> activeRentByResident = {};
    final Map<String, DateTime> leaseStartByResident = {};
    final Map<String, DateTime> leaseEndByResident = {};
    for (final l in (activeLeasesRes as List)) {
      final rId = l['resident_id'] as String?;
      if (rId != null) {
        if (l['monthly_rent'] != null) {
          activeRentByResident[rId] = (l['monthly_rent'] as num).toDouble();
        }
        if (l['start_date'] != null) {
          leaseStartByResident[rId] = DateTime.parse(l['start_date']);
        }
        if (l['end_date'] != null) {
          leaseEndByResident[rId] = DateTime.parse(l['end_date']);
        }
      }
    }

    final rows = await client
        .from('charges')
        .select('*, lease:leases!charges_lease_id_fkey(start_date,end_date,status,monthly_rent)')
        .eq('charge_type', 'rent')
        .order('due_date', ascending: false);

    final rawList = (rows as List).map((c) {
      final rId = c['resident_id'] as String;
      final lease = c['lease'] as Map<String, dynamic>?;
      final leaseStatus = lease?['status'] as String?;
      final leaseRent = (lease?['monthly_rent'] as num?)?.toDouble();
      final resolvedAmount = activeRentByResident[rId] ?? leaseRent ?? (c['amount'] as num).toDouble();
      final lateFee = (c['late_fee'] as num?)?.toDouble() ?? 0.0;

      final sDate = leaseStartByResident[rId] ?? (lease != null && lease['start_date'] != null ? DateTime.parse(lease['start_date']) : null);
      final eDate = leaseEndByResident[rId] ?? (lease != null && lease['end_date'] != null ? DateTime.parse(lease['end_date']) : null);

      return (
        charge: Charge(
          id: c['id'],
          residentId: rId,
          leaseId: c['lease_id'] ?? '',
          chargeType: c['charge_type'],
          title: c['title'],
          description: c['description'],
          amount: resolvedAmount,
          lateFee: lateFee,
          dueDate: DateTime.parse(c['due_date']),
          status: c['status'],
          createdAt: DateTime.parse(c['created_at']),
          leaseStartDate: sDate,
          leaseEndDate: eDate,
        ),
        isActiveLease: leaseStatus == null || leaseStatus == 'active',
      );
    }).toList();

    // Deduplicate charges per tenant and month:
    // Only keep active lease charges and avoid duplicate entries for the same month
    final Map<String, Charge> uniqueMap = {};
    for (final item in rawList) {
      if (!item.isActiveLease && item.charge.status != 'paid') continue;
      final key =
          '${item.charge.residentId}-${item.charge.dueDate.year}-${item.charge.dueDate.month}';
      
      final activeRent = activeRentByResident[item.charge.residentId];
      final normalizedCharge = activeRent != null
          ? item.charge.copyWith(amount: activeRent, lateFee: item.charge.lateFee)
          : item.charge;

      if (!uniqueMap.containsKey(key)) {
        uniqueMap[key] = normalizedCharge;
      } else {
        // If one is paid, keep the paid one (with the correct active rent amount and late fee)
        if (item.charge.status == 'paid') {
          uniqueMap[key] = normalizedCharge;
        }
      }
    }

    final result = uniqueMap.values.toList()
      ..sort((a, b) => b.dueDate.compareTo(a.dueDate));
    return result;
  }

  Future<void> confirmRentMonthPaid(Charge charge) async {
    final monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final monthTitle = '${monthNames[charge.dueDate.month - 1]} ${charge.dueDate.year} Rent';
    final rentAmount = charge.amount.toStringAsFixed(2);

    if (SupabaseClientHelper.isMockMode) {
      final exists = _mockCharges.any((c) => c.id == charge.id);
      if (!exists) _mockCharges.add(charge);
      await updateChargeStatus(charge.id, 'paid');
      return;
    }
    final client = SupabaseClientHelper.client;
    await client.from('charges').update({'status': 'paid', 'title': monthTitle}).eq('id', charge.id);
    await client.from('payments').update({'status': 'paid'}).eq('charge_id', charge.id).eq('status', 'pending');
    await client.from('notifications').insert({
      'resident_id': charge.residentId,
      'type': 'payment',
      'title': 'Rent payment confirmed',
      'message': 'Payment for $monthTitle (\$$rentAmount) was confirmed and approved by the owner.',
      'related_entity_type': 'charge',
      'related_entity_id': charge.id,
    });
  }

  Future<void> cancelRentMonthPaid(Charge charge) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(charge.dueDate.year, charge.dueDate.month, charge.dueDate.day);
    final revertedStatus = due.isBefore(today) ? 'past_due' : 'upcoming';

    if (SupabaseClientHelper.isMockMode) {
      _mockCharges = _mockCharges.map((c) {
        if (c.id == charge.id) {
          return c.copyWith(status: revertedStatus);
        }
        return c;
      }).toList();
      _mockPayments.removeWhere((p) => p.chargeId == charge.id);
      return;
    }

    final client = SupabaseClientHelper.client;
    await client.from('charges').update({'status': revertedStatus}).eq('id', charge.id);
    await client.from('payments').update({'status': 'refunded'}).eq('charge_id', charge.id);
    try {
      await client
          .from('notifications')
          .delete()
          .eq('related_entity_id', charge.id)
          .eq('related_entity_type', 'charge');
    } catch (_) {}
  }

  Future<void> updateLateFee(
    String chargeId,
    double lateFee, {
    String? residentId,
    String? monthTitle,
    double? baseAmount,
    bool notifyResident = true,
  }) async {
    final fee = lateFee < 0 ? 0.0 : lateFee;
    if (SupabaseClientHelper.isMockMode) {
      _mockCharges = _mockCharges.map((c) {
        if (c.id == chargeId) {
          return c.copyWith(lateFee: fee);
        }
        return c;
      }).toList();
      return;
    }
    final client = SupabaseClientHelper.client;
    await client.from('charges').update({'late_fee': fee}).eq('id', chargeId);

    if (fee > 0 && notifyResident && residentId != null && residentId.isNotEmpty) {
      final total = (baseAmount ?? 0) + fee;
      final titleStr = monthTitle != null && monthTitle.isNotEmpty ? monthTitle : 'Rent';
      final totalStr = total > fee ? ' New total due: \$${total.toStringAsFixed(2)}.' : '';
      try {
        await client.from('notifications').insert({
          'resident_id': residentId,
          'type': 'payment',
          'title': 'Late payment fee notice',
          'message': 'A late fee of \$${fee.toStringAsFixed(2)} was applied for $titleStr.$totalStr',
          'related_entity_type': 'charge',
          'related_entity_id': chargeId,
        });
      } catch (_) {}
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

  Future<void> extendLease({
    required String leaseId,
    required DateTime newEndDate,
    double? newMonthlyRent,
  }) async {
    if (SupabaseClientHelper.isMockMode) {
      return;
    }
    final client = SupabaseClientHelper.client;
    final updateData = <String, dynamic>{
      'end_date': newEndDate.toIso8601String().split('T')[0],
    };
    if (newMonthlyRent != null && newMonthlyRent > 0) {
      updateData['monthly_rent'] = newMonthlyRent;
    }
    await client.from('leases').update(updateData).eq('id', leaseId);
  }
}
