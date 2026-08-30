import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'payment_service.dart';
import 'storage_service.dart';
import 'notification_service.dart';
import 'residence_service.dart';
import 'parking_service.dart';
import 'maintenance_service.dart';
import 'insurance_service.dart';
import '../database/secure_storage.dart';
import '../database/shared_prefs.dart';

// 1. Storage & Prefs Providers
final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

// SharedPreferences is initialized in main() and overriden in ProviderScope
final sharedPrefsProvider = Provider<SharedPrefsService>((ref) {
  throw UnimplementedError(
    'sharedPrefsProvider must be overridden in main.dart',
  );
});

// 2. Services Providers
final authServiceProvider = Provider<AuthService>((ref) {
  final secureStorage = ref.watch(secureStorageProvider);
  return AuthService(secureStorage);
});

final paymentServiceProvider = Provider<PaymentService>((ref) {
  final authService = ref.watch(authServiceProvider);
  return PaymentService(authService);
});

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final authService = ref.watch(authServiceProvider);
  return NotificationService(authService);
});

final residenceServiceProvider = Provider<ResidenceService>((ref) {
  final authService = ref.watch(authServiceProvider);
  return ResidenceService(authService);
});

final parkingServiceProvider = Provider<ParkingService>((ref) {
  return ParkingService();
});

final maintenanceServiceProvider = Provider<MaintenanceService>((ref) {
  final authService = ref.watch(authServiceProvider);
  return MaintenanceService(authService);
});

final insuranceServiceProvider = Provider<InsuranceService>((ref) {
  final authService = ref.watch(authServiceProvider);
  return InsuranceService(authService);
});

// 3. Auth State Provider
final authStateProvider = StreamProvider<UserProfile?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

// 4. Feature Async State Providers
final residenceDetailsProvider = FutureProvider<ResidenceDetails?>((ref) async {
  final authState = ref.watch(authStateProvider);
  // Re-run if auth state changes
  if (authState.value == null) return null;
  return ref.watch(residenceServiceProvider).getResidenceDetails();
});

// Maintenance Requests Provider with AsyncNotifier to support adding requests
class MaintenanceRequestsNotifier
    extends AutoDisposeAsyncNotifier<List<MaintenanceRequest>> {
  @override
  Future<List<MaintenanceRequest>> build() async {
    final authState = ref.watch(authStateProvider);
    if (authState.value == null) return [];
    return ref.watch(maintenanceServiceProvider).getRequests();
  }

  Future<void> addRequest({
    required String title,
    required String category,
    required String description,
    required DateTime preferredDate,
    required List<String> attachmentPaths,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(maintenanceServiceProvider)
          .createRequest(
            title: title,
            category: category,
            description: description,
            preferredDate: preferredDate,
            localAttachmentPaths: attachmentPaths,
          );
      return ref.read(maintenanceServiceProvider).getRequests();
    });
  }
}

final maintenanceRequestsProvider =
    AsyncNotifierProvider.autoDispose<
      MaintenanceRequestsNotifier,
      List<MaintenanceRequest>
    >(() {
      return MaintenanceRequestsNotifier();
    });

// Charges Provider
class ChargesNotifier extends AutoDisposeAsyncNotifier<List<Charge>> {
  @override
  Future<List<Charge>> build() async {
    final authState = ref.watch(authStateProvider);
    if (authState.value == null) return [];
    return ref.read(paymentServiceProvider).getCharges();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(paymentServiceProvider).getCharges(),
    );
  }

  Future<void> createTenantCharge({
    required String residentId,
    required String leaseId,
    required String title,
    required double amount,
    required DateTime dueDate,
    String? description,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(paymentServiceProvider)
          .createCharge(
            residentId: residentId,
            leaseId: leaseId,
            chargeType: 'rent',
            title: title,
            amount: amount,
            dueDate: dueDate,
            description: description,
          );
      return ref.read(paymentServiceProvider).getCharges();
    });
  }
}

final chargesProvider =
    AsyncNotifierProvider.autoDispose<ChargesNotifier, List<Charge>>(() {
      return ChargesNotifier();
    });

// Payments History Provider
class PaymentsHistoryNotifier extends AutoDisposeAsyncNotifier<List<Payment>> {
  @override
  Future<List<Payment>> build() async {
    final authState = ref.watch(authStateProvider);
    if (authState.value == null) return [];
    return ref.read(paymentServiceProvider).getPaymentHistory();
  }

  Future<void> payCharges({
    required List<String> chargeIds,
    required double amount,
    required String method,
    String? receiptUrl,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(paymentServiceProvider)
          .makePayment(
            chargeIds: chargeIds,
            totalAmount: amount,
            paymentMethod: method,
            receiptUrl: receiptUrl,
          );
      // Trigger charges refresh as well
      ref.invalidate(chargesProvider);
      return ref.read(paymentServiceProvider).getPaymentHistory();
    });
  }
}

final paymentsHistoryProvider =
    AsyncNotifierProvider.autoDispose<PaymentsHistoryNotifier, List<Payment>>(
      () {
        return PaymentsHistoryNotifier();
      },
    );

// Insurance Policy Provider
class InsurancePolicyNotifier
    extends AutoDisposeAsyncNotifier<InsurancePolicy?> {
  @override
  Future<InsurancePolicy?> build() async {
    final authState = ref.watch(authStateProvider);
    if (authState.value == null) return null;
    return ref.read(insuranceServiceProvider).getPolicy();
  }

  Future<void> updatePolicyInfo({
    required String provider,
    required String policyNumber,
    required double coverageAmount,
    required DateTime expirationDate,
    String? localDocPath,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(insuranceServiceProvider)
          .updatePolicy(
            provider: provider,
            policyNumber: policyNumber,
            coverageAmount: coverageAmount,
            expirationDate: expirationDate,
            localDocumentPath: localDocPath,
          );
      return ref.read(insuranceServiceProvider).getPolicy();
    });
  }
}

final insurancePolicyProvider =
    AsyncNotifierProvider.autoDispose<
      InsurancePolicyNotifier,
      InsurancePolicy?
    >(() {
      return InsurancePolicyNotifier();
    });

// Notifications List Provider
class NotificationsNotifier
    extends AutoDisposeAsyncNotifier<List<AppNotification>> {
  @override
  Future<List<AppNotification>> build() async {
    final authState = ref.watch(authStateProvider);
    if (authState.value == null) return [];

    // Listen to real-time changes if applicable, otherwise fetch
    final notificationService = ref.watch(notificationServiceProvider);

    // Auto-update state when stream fires in mock mode
    final sub = notificationService.notificationsStream.listen((data) {
      state = AsyncValue.data(data);
    });
    ref.onDispose(() => sub.cancel());

    return notificationService.getNotifications();
  }

  Future<void> readAll() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(notificationServiceProvider).markAllAsRead();
      return ref.read(notificationServiceProvider).getNotifications();
    });
  }

  Future<void> readSingle(String id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(notificationServiceProvider).markAsRead(id);
      return ref.read(notificationServiceProvider).getNotifications();
    });
  }
}

final notificationsProvider =
    AsyncNotifierProvider.autoDispose<
      NotificationsNotifier,
      List<AppNotification>
    >(() {
      return NotificationsNotifier();
    });

// Locale State Provider for Language support (EN | ES)
final localeProvider = StateProvider<Locale>((ref) {
  try {
    final sharedPrefs = ref.watch(sharedPrefsProvider);
    var code = sharedPrefs.getLanguage();
    if (code == 'ar') {
      code = 'es';
    }
    return Locale(code);
  } catch (_) {
    return const Locale('en');
  }
});

// Manager Providers
final managerMaintenanceProvider =
    FutureProvider.autoDispose<List<MaintenanceRequest>>((ref) async {
      return ref.watch(maintenanceServiceProvider).getAllRequests();
    });

final managerPaymentsProvider = FutureProvider.autoDispose<List<Payment>>((
  ref,
) async {
  return ref.watch(paymentServiceProvider).getAllPayments();
});

final managerTenantsProvider = FutureProvider.autoDispose<List<UserProfile>>((
  ref,
) async {
  return ref.watch(authServiceProvider).getAllTenants();
});

final managerPendingTenantsProvider =
    FutureProvider.autoDispose<List<UserProfile>>((ref) async {
      return ref.watch(authServiceProvider).getPendingTenants();
    });

final managerPropertiesProvider = FutureProvider.autoDispose<List<Property>>((
  ref,
) async {
  return ref.watch(residenceServiceProvider).getAllProperties();
});

final managerUnitsProvider = FutureProvider.autoDispose<List<Unit>>((
  ref,
) async {
  return ref.watch(residenceServiceProvider).getAllUnits();
});

final managerParkingSpacesProvider =
    FutureProvider.autoDispose<List<ParkingSpace>>((ref) async {
      return ref.watch(parkingServiceProvider).getAllSpaces();
    });

// Theme Mode Provider for Dark Mode toggling and persistence
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final Ref _ref;
  ThemeModeNotifier(this._ref) : super(ThemeMode.light) {
    try {
      final sharedPrefs = _ref.read(sharedPrefsProvider);
      final isDark = sharedPrefs.getDarkMode();
      state = isDark ? ThemeMode.dark : ThemeMode.light;
    } catch (_) {
      state = ThemeMode.light;
    }
  }

  void toggleTheme(bool isDark) {
    try {
      final sharedPrefs = _ref.read(sharedPrefsProvider);
      sharedPrefs.setDarkMode(isDark);
    } catch (_) {}
    state = isDark ? ThemeMode.dark : ThemeMode.light;
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((
  ref,
) {
  return ThemeModeNotifier(ref);
});
