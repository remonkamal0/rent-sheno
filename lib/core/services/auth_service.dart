import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../api/supabase_client.dart';
import '../../app/constants/app_constants.dart';
import '../database/secure_storage.dart';

class UserProfile {
  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final String? avatarUrl;
  final String preferredLanguage;
  final String role; // 'tenant' or 'manager'
  final String? unitNumber;

  UserProfile({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    this.avatarUrl,
    required this.preferredLanguage,
    required this.role,
    this.unitNumber,
  });

  UserProfile copyWith({
    String? fullName,
    String? phone,
    String? avatarUrl,
    String? preferredLanguage,
    String? role,
    String? unitNumber,
  }) {
    return UserProfile(
      id: id,
      fullName: fullName ?? this.fullName,
      email: email,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      role: role ?? this.role,
      unitNumber: unitNumber ?? this.unitNumber,
    );
  }
}

class AuthService {
  final SecureStorageService _secureStorage;
  final _authStateController = StreamController<UserProfile?>.broadcast();
  UserProfile? _currentUser;

  AuthService(this._secureStorage) {
    _initializeAuth();
  }

  Stream<UserProfile?> get authStateChanges => _authStateController.stream;
  UserProfile? get currentUser => _currentUser;

  Future<void> _initializeAuth() async {
    final token = await _secureStorage.getToken();
    if (token != null && token.startsWith('mock-session-token')) {
      final isManager = token.contains('manager');
      if (token.contains('mock-session-token-tenant-')) {
        final userId = token.replaceFirst('mock-session-token-tenant-', '');
        final idx = _mockTenants.indexWhere((t) => t.id == userId);
        _currentUser = idx != -1 ? _mockTenants[idx] : null;
      } else {
        _currentUser = UserProfile(
          id: isManager ? 'mock-manager-999' : 'mock-user-123',
          fullName: isManager ? 'William Harrison (Landlord)' : AppConstants.demoFullName,
          email: isManager ? 'landlord@example.com' : AppConstants.demoEmail,
          phone: isManager ? '+1 (555) 019-9999' : AppConstants.demoPhone,
          preferredLanguage: 'en',
          role: isManager ? 'manager' : 'tenant',
          unitNumber: isManager ? null : 'Bldg 1 - Apt 101',
        );
      }
      _authStateController.add(_currentUser);
      return;
    }

    if (SupabaseClientHelper.isMockMode) {
      _authStateController.add(null);
    } else {
      final client = SupabaseClientHelper.client;
      final session = client.auth.currentSession;
      if (session != null) {
        await _fetchProfile(session.user.id);
      } else {
        _authStateController.add(null);
      }

      client.auth.onAuthStateChange.listen((data) async {
        final session = data.session;
        if (session != null) {
          await _fetchProfile(session.user.id);
        } else {
          if (_currentUser == null || !_currentUser!.id.startsWith('mock-')) {
            _currentUser = null;
            _authStateController.add(null);
          }
        }
      });
    }
  }

  Future<void> _fetchProfile(String authUserId) async {
    try {
      final client = SupabaseClientHelper.client;
      final data = await client
          .from('profiles')
          .select()
          .eq('auth_user_id', authUserId)
          .maybeSingle();

      if (data != null) {
        _currentUser = UserProfile(
          id: data['id'],
          fullName: data['full_name'],
          email: data['email'],
          phone: data['phone'],
          avatarUrl: data['avatar_url'],
          preferredLanguage: data['preferred_language'] ?? 'en',
          role: data['role'] ?? 'tenant',
        );
        _authStateController.add(_currentUser);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching user profile: $e');
      }
    }
  }

  Future<bool> signIn(String email, String password, bool rememberMe) async {
    final inputEmail = email.trim().toLowerCase();
    
    if (SupabaseClientHelper.isMockMode) {
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (inputEmail == 'landlord@example.com') {
        _currentUser = UserProfile(
          id: 'mock-manager-999',
          fullName: 'William Harrison (Landlord)',
          email: 'landlord@example.com',
          phone: '+1 (555) 019-9999',
          preferredLanguage: 'en',
          role: 'manager',
        );
        await _secureStorage.saveToken('mock-session-token-manager');
        if (rememberMe) await _secureStorage.saveRememberedEmail(email);
        _authStateController.add(_currentUser);
        return true;
      }

      final tenantIdx = _mockTenants.indexWhere((t) => t.email.toLowerCase() == inputEmail);
      if (tenantIdx != -1) {
        _currentUser = _mockTenants[tenantIdx];
        await _secureStorage.saveToken('mock-session-token-tenant-${_currentUser!.id}');
        if (rememberMe) await _secureStorage.saveRememberedEmail(email);
        _authStateController.add(_currentUser);
        return true;
      }

      if (inputEmail == AppConstants.demoEmail.toLowerCase()) {
        _currentUser = UserProfile(
          id: 'mock-user-123',
          fullName: AppConstants.demoFullName,
          email: AppConstants.demoEmail,
          phone: AppConstants.demoPhone,
          preferredLanguage: 'en',
          role: 'tenant',
          unitNumber: 'Bldg 1 - Apt 101',
        );
        await _secureStorage.saveToken('mock-session-token-tenant');
        if (rememberMe) await _secureStorage.saveRememberedEmail(email);
        _authStateController.add(_currentUser);
        return true;
      }

      throw Exception('Invalid email or password');
    } else {
      try {
        final client = SupabaseClientHelper.client;
        final response = await client.auth.signInWithPassword(
          email: email,
          password: password,
        );

        if (response.session != null) {
          await _fetchProfile(response.user!.id);
          if (rememberMe) {
            await _secureStorage.saveRememberedEmail(email);
          } else {
            await _secureStorage.deleteRememberedEmail();
          }
          return true;
        }
        return false;
      } catch (e) {
        throw Exception(e.toString());
      }
    }
  }

  Future<void> signUp({
    required String fullName,
    required String email,
    required String password,
    required String phone,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty || fullName.isEmpty || password.isEmpty) {
      throw Exception('All registration fields are required.');
    }

    if (SupabaseClientHelper.isMockMode) {
      await Future.delayed(const Duration(milliseconds: 500));
      final newPendingUser = UserProfile(
        id: 'mock-pending-${DateTime.now().millisecondsSinceEpoch}',
        fullName: fullName,
        email: cleanEmail,
        phone: phone,
        preferredLanguage: 'en',
        role: 'pending',
      );
      _mockTenants.add(newPendingUser);
    } else {
      try {
        final client = SupabaseClientHelper.client;
        final response = await client.auth.signUp(
          email: cleanEmail,
          password: password,
        );

        if (response.user != null) {
          await client.from('profiles').insert({
            'auth_user_id': response.user!.id,
            'full_name': fullName,
            'email': cleanEmail,
            'phone': phone,
            'role': 'pending',
          });
        }
      } catch (e) {
        throw Exception(e.toString());
      }
    }
  }

  Future<void> approveTenant({
    required String tenantId,
  }) async {
    if (SupabaseClientHelper.isMockMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      for (int i = 0; i < _mockTenants.length; i++) {
        if (_mockTenants[i].id == tenantId) {
          _mockTenants[i] = _mockTenants[i].copyWith(role: 'tenant');
          break;
        }
      }
    } else {
      try {
        final client = SupabaseClientHelper.client;
        await client.from('profiles').update({'role': 'tenant'}).eq('id', tenantId);
      } catch (e) {
        throw Exception(e.toString());
      }
    }
  }

  Future<void> rejectTenant({
    required String tenantId,
  }) async {
    if (SupabaseClientHelper.isMockMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      _mockTenants.removeWhere((t) => t.id == tenantId);
    } else {
      try {
        final client = SupabaseClientHelper.client;
        await client.from('profiles').delete().eq('id', tenantId);
      } catch (e) {
        throw Exception(e.toString());
      }
    }
  }

  Future<void> signOut() async {
    if (SupabaseClientHelper.isMockMode) {
      await _secureStorage.deleteToken();
      _currentUser = null;
      _authStateController.add(null);
    } else {
      final client = SupabaseClientHelper.client;
      await client.auth.signOut();
      _currentUser = null;
      _authStateController.add(null);
    }
  }

  Future<void> deleteAccount() async {
    final user = _currentUser;
    if (user == null) return;

    if (SupabaseClientHelper.isMockMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      _mockTenants.removeWhere((t) => t.id == user.id);
    } else {
      try {
        final client = SupabaseClientHelper.client;
        await client.from('profiles').delete().eq('id', user.id);
      } catch (e) {
        throw Exception(e.toString());
      }
    }
    await signOut();
  }

  Future<void> updateProfile({
    required String fullName,
    required String phone,
    String? avatarUrl,
  }) async {
    if (SupabaseClientHelper.isMockMode) {
      if (_currentUser != null) {
        _currentUser = _currentUser!.copyWith(
          fullName: fullName,
          phone: phone,
          avatarUrl: avatarUrl,
        );
        _authStateController.add(_currentUser);
      }
    } else {
      if (_currentUser == null) return;
      final client = SupabaseClientHelper.client;
      await client.from('profiles').update({
        'full_name': fullName,
        'phone': phone,
        'avatar_url': avatarUrl,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', _currentUser!.id);
      
      _currentUser = _currentUser!.copyWith(
        fullName: fullName,
        phone: phone,
        avatarUrl: avatarUrl,
      );
      _authStateController.add(_currentUser);
    }
  }

  Future<void> changePassword(String newPassword) async {
    if (SupabaseClientHelper.isMockMode) {
      await Future.delayed(const Duration(seconds: 1));
      return;
    } else {
      final client = SupabaseClientHelper.client;
      await client.auth.updateUser(
        sb.UserAttributes(password: newPassword),
      );
    }
  }

  Future<void> resetPassword(String email) async {
    if (SupabaseClientHelper.isMockMode) {
      await Future.delayed(const Duration(seconds: 1));
      return;
    } else {
      final client = SupabaseClientHelper.client;
      await client.auth.resetPasswordForEmail(email);
    }
  }

  final List<UserProfile> _mockTenants = [
    UserProfile(
      id: 'mock-user-123',
      fullName: 'John Doe',
      email: 'john.doe@example.com',
      phone: '+1 (555) 019-2834',
      preferredLanguage: 'en',
      role: 'tenant',
      unitNumber: 'Bldg 1 - Apt 101',
    ),
    UserProfile(
      id: 'mock-user-456',
      fullName: 'Sarah Jenkins',
      email: 'sarah.j@example.com',
      phone: '+1 (555) 023-4567',
      preferredLanguage: 'en',
      role: 'tenant',
      unitNumber: 'Bldg 1 - Apt 102',
    ),
    UserProfile(
      id: 'mock-user-789',
      fullName: 'Michael Chang',
      email: 'm.chang@example.com',
      phone: '+1 (555) 045-6789',
      preferredLanguage: 'en',
      role: 'tenant',
      unitNumber: 'Bldg 2 - Apt 204',
    ),
    UserProfile(
      id: 'mock-user-pending',
      fullName: 'David Smith (Pending)',
      email: 'david@example.com',
      phone: '+1 (555) 012-3456',
      preferredLanguage: 'en',
      role: 'pending',
    ),
  ];

  void updateMockTenantUnit(String residentId, String unitNumber) {
    for (int i = 0; i < _mockTenants.length; i++) {
      if (_mockTenants[i].id == residentId) {
        _mockTenants[i] = _mockTenants[i].copyWith(unitNumber: unitNumber);
        break;
      }
    }
  }

  Future<List<UserProfile>> getAllTenants() async {
    if (SupabaseClientHelper.isMockMode) {
      await Future.delayed(const Duration(milliseconds: 400));
      return _mockTenants;
    } else {
      try {
        final client = SupabaseClientHelper.client;
        final res = await client
            .from('profiles')
            .select('*, leases(units(unit_number))')
            .eq('role', 'tenant');

        return (res as List).map((p) {
          String? unitNum;
          if (p['leases'] != null && (p['leases'] as List).isNotEmpty) {
            final firstLease = p['leases'][0];
            if (firstLease['units'] != null) {
              unitNum = firstLease['units']['unit_number'];
            }
          }
          return UserProfile(
            id: p['id'],
            fullName: p['full_name'],
            email: p['email'],
            phone: p['phone'],
            avatarUrl: p['avatar_url'],
            preferredLanguage: p['preferred_language'] ?? 'en',
            role: p['role'] ?? 'tenant',
            unitNumber: unitNum,
          );
        }).toList();
      } catch (e) {
        throw Exception(e.toString());
      }
    }
  }

  Future<List<UserProfile>> getPendingTenants() async {
    if (SupabaseClientHelper.isMockMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      return _mockTenants.where((t) => t.role == 'pending').toList();
    } else {
      try {
        final client = SupabaseClientHelper.client;
        final res = await client
            .from('profiles')
            .select()
            .eq('role', 'pending');

        return (res as List).map((p) {
          return UserProfile(
            id: p['id'],
            fullName: p['full_name'],
            email: p['email'],
            phone: p['phone'],
            avatarUrl: p['avatar_url'],
            preferredLanguage: p['preferred_language'] ?? 'en',
            role: p['role'] ?? 'pending',
          );
        }).toList();
      } catch (e) {
        throw Exception(e.toString());
      }
    }
  }

  Future<UserProfile?> getUserProfileById(String userId) async {
    if (SupabaseClientHelper.isMockMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      final idx = _mockTenants.indexWhere((t) => t.id == userId);
      return idx == -1 ? null : _mockTenants[idx];
    } else {
      try {
        final client = SupabaseClientHelper.client;
        final res = await client
            .from('profiles')
            .select()
            .eq('id', userId)
            .maybeSingle();

        if (res == null) return null;

        return UserProfile(
          id: res['id'],
          fullName: res['full_name'],
          email: res['email'],
          phone: res['phone'],
          preferredLanguage: res['preferred_language'] ?? 'en',
          role: res['role'],
          unitNumber: res['unit_number'],
          avatarUrl: res['avatar_url'],
        );
      } catch (e) {
        throw Exception(e.toString());
      }
    }
  }
}
