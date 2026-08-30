import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/providers.dart';
import '../../features/authentication/presentation/login_screen.dart';
import '../../features/authentication/presentation/signup_screen.dart';
import '../../features/authentication/presentation/pending_approval_screen.dart';
import '../../features/authentication/presentation/inactive_resident_screen.dart';
import '../../features/authentication/presentation/forgot_password_screen.dart';
import '../../features/authentication/presentation/reset_password_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/home/presentation/manager_home_screen.dart';
import '../../features/home/presentation/manager_setup_lease_screen.dart';
import '../../features/home/presentation/manager_properties_screen.dart';
import '../../features/home/presentation/manager_parking_screen.dart';
import '../../features/home/presentation/manager_approvals_screen.dart';
import '../../features/maintenance/presentation/maintenance_list_screen.dart';
import '../../features/maintenance/presentation/manager_maintenance_screen.dart';
import '../../features/maintenance/presentation/new_request_screen.dart';
import '../../features/maintenance/presentation/request_details_screen.dart';
import '../../features/maintenance/presentation/manager_detail_screen.dart';
import '../../features/payments/presentation/payments_screen.dart';
import '../../features/payments/presentation/payment_details_screen.dart';
import '../../features/payments/presentation/manager_payments_screen.dart';
import '../../features/payments/presentation/manager_create_charge_screen.dart';
import '../../features/insurance/presentation/insurance_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/notifications/presentation/manager_notify_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/settings/presentation/change_password_screen.dart';
import '../../core/widgets/sms_bottom_navigation.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey =
    GlobalKey<NavigatorState>();

class _AuthRouterRefresh extends ChangeNotifier {
  _AuthRouterRefresh(Stream<Object?> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<Object?> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final authService = ref.watch(authServiceProvider);
  final refresh = _AuthRouterRefresh(authService.authStateChanges);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/home',
    refreshListenable: refresh,
    redirect: (context, state) {
      final user = authService.currentUser;
      final isLoggedIn = user != null;
      final isAuthRoute =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup' ||
          state.matchedLocation == '/forgot-password' ||
          state.matchedLocation == '/reset-password';

      if (!isLoggedIn && !isAuthRoute) {
        return '/login';
      }

      if (isLoggedIn) {
        final isInactive = user.role == 'inactive';
        if (isInactive) {
          if (state.matchedLocation != '/inactive-resident') {
            return '/inactive-resident';
          }
          return null;
        }
        final isPending = user.role == 'pending';
        if (isPending) {
          if (state.matchedLocation != '/pending-approval') {
            return '/pending-approval';
          }
          return null;
        }

        final isManager = user.role == 'manager';

        if (isAuthRoute || state.matchedLocation == '/pending-approval') {
          return isManager ? '/manager/home' : '/home';
        }

        final location = state.matchedLocation;
        // If manager attempts to visit standard tenant home, redirect to manager home
        if (isManager && location == '/home') {
          return '/manager/home';
        }
        // If tenant attempts to visit manager routes, redirect to tenant home
        if (!isManager && location.startsWith('/manager')) {
          return '/home';
        }
      }

      return null;
    },
    routes: [
      // Authentication Routes
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/pending-approval',
        builder: (context, state) => const PendingApprovalScreen(),
      ),
      GoRoute(
        path: '/inactive-resident',
        builder: (context, state) => const InactiveResidentScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => const ResetPasswordScreen(),
      ),

      // Shell Route for bottom navigation (Tenants Only)
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return SmsBottomNavigationLayout(child: child);
        },
        routes: [
          GoRoute(
            path: '/home',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: HomeScreen()),
          ),
          GoRoute(
            path: '/maintenance',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: MaintenanceListScreen()),
          ),
          GoRoute(
            path: '/payments',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: PaymentsScreen()),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ProfileScreen()),
          ),
        ],
      ),

      // Landlord/Manager Routes
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/manager/home',
        builder: (context, state) => const ManagerHomeScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/manager/maintenance',
        builder: (context, state) => const ManagerMaintenanceScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/manager/maintenance/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ManagerDetailScreen(requestId: id);
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/manager/payments',
        builder: (context, state) => const ManagerPaymentsScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/manager/payments/create',
        builder: (context, state) => const ManagerCreateChargeScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/manager/leases/create',
        builder: (context, state) {
          final unitNumber = state.uri.queryParameters['unitNumber'];
          return ManagerSetupLeaseScreen(preSelectedUnitNumber: unitNumber);
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/manager/properties',
        builder: (context, state) => const ManagerPropertiesScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/manager/parking',
        builder: (context, state) => const ManagerParkingScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/manager/approvals',
        builder: (context, state) => const ManagerApprovalsScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/manager/notify',
        builder: (context, state) {
          final tenantId = state.uri.queryParameters['tenantId'];
          return ManagerNotifyScreen(preSelectedTenantId: tenantId);
        },
      ),

      // Standalone nested routes (Shared/Tenant)
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/maintenance/new',
        builder: (context, state) => const NewRequestScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/maintenance/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return RequestDetailsScreen(requestId: id);
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/payments/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return PaymentDetailsScreen(paymentId: id);
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/insurance',
        builder: (context, state) => const InsuranceScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/change-password',
        builder: (context, state) => const ChangePasswordScreen(),
      ),
    ],
  );
});
