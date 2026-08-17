import 'package:flutter_test/flutter_test.dart';
import 'package:sms_services/core/services/payment_service.dart';
import 'package:sms_services/core/services/insurance_service.dart';
import 'package:sms_services/core/services/maintenance_service.dart';
import 'package:sms_services/core/services/auth_service.dart';
import 'package:sms_services/core/services/notification_service.dart';

void main() {
  group('Login Validator Tests', () {
    test('Empty email validation', () {
      final String? Function(String?) validator = (val) {
        if (val == null || val.trim().isEmpty) return 'Required';
        return null;
      };
      expect(validator(''), 'Required');
      expect(validator(null), 'Required');
      expect(validator('test@domain.com'), null);
    });

    test('Email format validation', () {
      final bool Function(String) isEmailValid = (val) {
        return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val.trim());
      };
      expect(isEmailValid('john.doe'), false);
      expect(isEmailValid('john.doe@'), false);
      expect(isEmailValid('john.doe@example'), false);
      expect(isEmailValid('john.doe@example.com'), true);
    });

    test('Password length validation', () {
      final bool Function(String) isPasswordValid = (val) {
        return val.length >= 6;
      };
      expect(isPasswordValid('123'), false);
      expect(isPasswordValid('12345'), false);
      expect(isPasswordValid('123456'), true);
    });
  });

  group('Payment & Outstanding Calculations Tests', () {
    test('Days remaining calculation', () {
      final now = DateTime.now();
      final dueDate = now.add(const Duration(days: 5));
      final charge = Charge(
        id: 'c1',
        residentId: 'r1',
        leaseId: 'l1',
        chargeType: 'rent',
        title: 'Rent',
        amount: 2200.0,
        dueDate: dueDate,
        status: 'upcoming',
        createdAt: now,
      );

      // Should be roughly 5 days
      expect(charge.daysRemaining, 5);
    });

    test('Calculated status overdue check', () {
      final now = DateTime.now();
      final pastDate = now.subtract(const Duration(days: 2));
      final charge = Charge(
        id: 'c2',
        residentId: 'r1',
        leaseId: 'l1',
        chargeType: 'fee',
        title: 'Late Fee',
        amount: 100.0,
        dueDate: pastDate,
        status: 'due',
        createdAt: now,
      );

      expect(charge.calculatedStatus, 'past_due');
    });
  });

  group('Insurance Policy Calculations Tests', () {
    test('Insurance active status', () {
      final now = DateTime.now();
      final policy = InsurancePolicy(
        id: 'p1',
        residentId: 'r1',
        provider: 'SafeGuard',
        policyNumber: 'SG-123',
        coverageAmount: 50000.0,
        deductible: 500.0,
        effectiveDate: now.subtract(const Duration(days: 10)),
        expirationDate: now.add(const Duration(days: 45)),
        status: 'active',
      );

      expect(policy.calculatedStatus, 'active');
    });

    test('Insurance expiring soon warning', () {
      final now = DateTime.now();
      final policy = InsurancePolicy(
        id: 'p2',
        residentId: 'r1',
        provider: 'SafeGuard',
        policyNumber: 'SG-123',
        coverageAmount: 50000.0,
        deductible: 500.0,
        effectiveDate: now.subtract(const Duration(days: 10)),
        // Less than 30 days remaining
        expirationDate: now.add(const Duration(days: 12)),
        status: 'active',
      );

      expect(policy.calculatedStatus, 'expiring_soon');
      expect(policy.daysUntilExpiration, 12);
    });
  });

  group('Maintenance Request Models Tests', () {
    test('Maintenance details mapping', () {
      final now = DateTime.now();
      final req = MaintenanceRequest(
        id: 'MR-1',
        residentId: 'r1',
        unitId: 'u1',
        requestNumber: 'MR-1',
        category: 'plumbing',
        title: 'Leaky faucet',
        description: 'Drip drip',
        preferredDate: now,
        status: 'pending',
        createdAt: now,
        updatedAt: now,
        attachmentUrls: ['url1', 'url2'],
      );

      expect(req.category, 'plumbing');
      expect(req.status, 'pending');
      expect(req.attachmentUrls.length, 2);
    });
  });

  group('Landlord & Roles Feature Tests', () {
    test('UserProfile role property mapping', () {
      final user = UserProfile(
        id: 'u1',
        fullName: 'Tenant 1',
        email: 'tenant@example.com',
        preferredLanguage: 'en',
        role: 'tenant',
      );
      final manager = UserProfile(
        id: 'm1',
        fullName: 'Manager 1',
        email: 'manager@example.com',
        preferredLanguage: 'en',
        role: 'manager',
      );

      expect(user.role, 'tenant');
      expect(manager.role, 'manager');
    });

    test('Maintenance status copyWith transition', () {
      final now = DateTime.now();
      final req = MaintenanceRequest(
        id: 'MR-2',
        residentId: 'r1',
        unitId: 'u1',
        requestNumber: 'MR-2',
        category: 'electrical',
        title: 'Light sparks',
        description: 'Light sparks on toggle',
        preferredDate: now,
        status: 'pending',
        createdAt: now,
        updatedAt: now,
        attachmentUrls: [],
      );

      final inProgressReq = req.copyWith(status: 'in_progress');
      expect(inProgressReq.status, 'in_progress');

      final closedReq = inProgressReq.copyWith(status: 'closed', resolvedAt: now);
      expect(closedReq.status, 'closed');
      expect(closedReq.resolvedAt, now);
    });

    test('AppNotification details and roles mapping', () {
      final notif = AppNotification(
        id: 'n1',
        residentId: 'r1',
        type: 'general',
        title: 'Announcement',
        message: 'Water maintenance alert',
        isRead: false,
        createdAt: DateTime.now(),
      );

      expect(notif.type, 'general');
      expect(notif.isRead, false);
      
      final readNotif = notif.copyWith(isRead: true);
      expect(readNotif.isRead, true);
    });
  });
}
