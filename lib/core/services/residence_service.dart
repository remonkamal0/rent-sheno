import 'dart:async';
import 'package:flutter/foundation.dart';
import '../api/supabase_client.dart';
import 'auth_service.dart';

class Property {
  final String id;
  final String name;
  final String addressLine1;
  final String? addressLine2;
  final String city;
  final String state;
  final String postalCode;
  final String country;
  final String? imageUrl;

  Property({
    required this.id,
    required this.name,
    required this.addressLine1,
    this.addressLine2,
    required this.city,
    required this.state,
    required this.postalCode,
    required this.country,
    this.imageUrl,
  });
}

class Unit {
  final String id;
  final String propertyId;
  final String unitNumber;
  final int floor;
  final String status; // 'vacant' or 'occupied'

  Unit({
    required this.id,
    required this.propertyId,
    required this.unitNumber,
    required this.floor,
    required this.status,
  });

  Unit copyWith({
    String? id,
    String? propertyId,
    String? unitNumber,
    int? floor,
    String? status,
  }) {
    return Unit(
      id: id ?? this.id,
      propertyId: propertyId ?? this.propertyId,
      unitNumber: unitNumber ?? this.unitNumber,
      floor: floor ?? this.floor,
      status: status ?? this.status,
    );
  }
}

class Lease {
  final String id;
  final String unitId;
  final String residentId;
  final DateTime startDate;
  final DateTime endDate;
  final double monthlyRent;
  final double securityDeposit;
  final String status;

  Lease({
    required this.id,
    required this.unitId,
    required this.residentId,
    required this.startDate,
    required this.endDate,
    required this.monthlyRent,
    required this.securityDeposit,
    required this.status,
  });

  int get daysUntilExpiration {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiry = DateTime(endDate.year, endDate.month, endDate.day);
    return expiry.difference(today).inDays;
  }
}

class ResidenceDetails {
  final Property property;
  final Unit unit;
  final Lease lease;

  ResidenceDetails({
    required this.property,
    required this.unit,
    required this.lease,
  });
}

class ResidenceService {
  final AuthService _authService;

  final List<Property> _mockProperties = [];
  final List<Unit> _mockUnits = [];
  final List<Lease> _mockLeases = [];

  ResidenceService(this._authService) {
    _initMockData();
  }

  void _initMockData() {
    final now = DateTime.now();

    // Create 3 default buildings (Properties)
    for (int p = 1; p <= 3; p++) {
      final propId = 'prop-$p';
      _mockProperties.add(
        Property(
          id: propId,
          name: 'Building $p',
          addressLine1: 'Cairo Road, Bldg $p',
          city: 'Cairo',
          state: 'Egypt',
          postalCode: '11511',
          country: 'Egypt',
          imageUrl: p == 1
              ? 'https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?auto=format&fit=crop&q=80&w=600'
              : 'https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?auto=format&fit=crop&q=80&w=600',
        ),
      );

      // Generate 50 units for each building (10 floors, 5 units per floor)
      for (int floor = 1; floor <= 10; floor++) {
        for (int apt = 1; apt <= 5; apt++) {
          final aptNumber = floor * 100 + apt;
          final unitId = 'unit-$p-$floor-$apt';
          final unitNumber = 'Building $p - Floor $floor - Apt $aptNumber';

          // Determine status based on our initial mock tenants
          String status = 'vacant';
          if (p == 1 && floor == 1 && apt == 1) {
            status = 'occupied'; // John Doe
          } else if (p == 1 && floor == 1 && apt == 2) {
            status = 'occupied'; // Sarah Jenkins
          } else if (p == 2 && floor == 2 && apt == 4) {
            status = 'occupied'; // Michael Chang
          }

          _mockUnits.add(
            Unit(
              id: unitId,
              propertyId: propId,
              unitNumber: unitNumber,
              floor: floor,
              status: status,
            ),
          );
        }
      }
    }

    // Add initial leases for occupied units
    _mockLeases.add(
      Lease(
        id: 'lease-101',
        unitId: 'unit-1-1-1', // Bldg 1 Floor 1 Apt 101
        residentId: 'mock-user-123',
        startDate: DateTime(now.year, 1, 1),
        endDate: DateTime(now.year, 12, 31),
        monthlyRent: 2200.0,
        securityDeposit: 1500.0,
        status: 'active',
      ),
    );

    _mockLeases.add(
      Lease(
        id: 'lease-102',
        unitId: 'unit-1-1-2', // Bldg 1 Floor 1 Apt 102
        residentId: 'mock-user-456',
        startDate: DateTime(now.year, 1, 1),
        endDate: DateTime(now.year, 12, 31),
        monthlyRent: 1900.0,
        securityDeposit: 1200.0,
        status: 'active',
      ),
    );

    _mockLeases.add(
      Lease(
        id: 'lease-103',
        unitId: 'unit-2-2-4', // Bldg 2 Floor 2 Apt 204
        residentId: 'mock-user-789',
        startDate: DateTime(now.year, 2, 1),
        endDate: DateTime(now.year + 1, 1, 31),
        monthlyRent: 2500.0,
        securityDeposit: 2000.0,
        status: 'active',
      ),
    );
  }

  Future<ResidenceDetails?> getResidenceDetails() async {
    if (SupabaseClientHelper.isMockMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      final residentId = _authService.currentUser?.id;
      if (residentId == null) return null;

      // Find active lease for current user
      final leaseIndex = _mockLeases.indexWhere(
        (l) => l.residentId == residentId && l.status == 'active',
      );
      if (leaseIndex == -1) return null;
      final lease = _mockLeases[leaseIndex];

      final unitIndex = _mockUnits.indexWhere((u) => u.id == lease.unitId);
      if (unitIndex == -1) return null;
      final unit = _mockUnits[unitIndex];

      final propIndex = _mockProperties.indexWhere(
        (p) => p.id == unit.propertyId,
      );
      if (propIndex == -1) return null;
      final property = _mockProperties[propIndex];

      return ResidenceDetails(property: property, unit: unit, lease: lease);
    } else {
      try {
        final client = SupabaseClientHelper.client;
        final residentId = _authService.currentUser?.id;

        if (residentId == null) return null;

        // Fetch lease details
        final leaseRes = await client
            .from('leases')
            .select()
            .eq('resident_id', residentId)
            .eq('status', 'active')
            .maybeSingle();

        if (leaseRes == null) return null;

        final lease = Lease(
          id: leaseRes['id'],
          unitId: leaseRes['unit_id'],
          residentId: leaseRes['resident_id'],
          startDate: DateTime.parse(leaseRes['start_date']),
          endDate: DateTime.parse(leaseRes['end_date']),
          monthlyRent: (leaseRes['monthly_rent'] as num).toDouble(),
          securityDeposit: (leaseRes['security_deposit'] as num).toDouble(),
          status: leaseRes['status'],
        );

        // Fetch unit details
        final unitRes = await client
            .from('units')
            .select()
            .eq('id', lease.unitId)
            .single();

        final unit = Unit(
          id: unitRes['id'],
          propertyId: unitRes['property_id'],
          unitNumber: unitRes['unit_number'],
          floor: unitRes['floor'],
          status: unitRes['status'],
        );

        // Fetch property details
        final propRes = await client
            .from('properties')
            .select()
            .eq('id', unit.propertyId)
            .single();

        final property = Property(
          id: propRes['id'],
          name: propRes['name'],
          addressLine1: propRes['address_line_1'],
          addressLine2: propRes['address_line_2'],
          city: propRes['city'],
          state: propRes['state'],
          postalCode: propRes['postal_code'],
          country: propRes['country'],
          imageUrl: propRes['image_url'],
        );

        return ResidenceDetails(property: property, unit: unit, lease: lease);
      } catch (e) {
        throw Exception(e.toString());
      }
    }
  }

  Future<List<Unit>> getAllUnits() async {
    if (SupabaseClientHelper.isMockMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      return _mockUnits;
    } else {
      try {
        final client = SupabaseClientHelper.client;
        final res = await client.from('units').select();
        return (res as List)
            .map(
              (u) => Unit(
                id: u['id'],
                propertyId: u['property_id'],
                unitNumber: u['unit_number'],
                floor: u['floor'] ?? 1,
                status: u['status'] ?? 'vacant',
              ),
            )
            .toList();
      } catch (e) {
        throw Exception(e.toString());
      }
    }
  }

  Future<List<Property>> getAllProperties() async {
    if (SupabaseClientHelper.isMockMode) {
      await Future.delayed(const Duration(milliseconds: 200));
      return _mockProperties;
    } else {
      try {
        final client = SupabaseClientHelper.client;
        final res = await client.from('properties').select();
        return (res as List)
            .map(
              (p) => Property(
                id: p['id'],
                name: p['name'],
                addressLine1: p['address_line_1'],
                addressLine2: p['address_line_2'],
                city: p['city'],
                state: p['state'],
                postalCode: p['postal_code'],
                country: p['country'],
                imageUrl: p['image_url'],
              ),
            )
            .toList();
      } catch (e) {
        throw Exception(e.toString());
      }
    }
  }

  Future<void> createBuildingAndUnits({
    required String buildingName,
    required String address,
    required int floorsCount,
    required int apartmentsPerFloor,
  }) async {
    if (SupabaseClientHelper.isMockMode) {
      await Future.delayed(const Duration(milliseconds: 500));
      final propId = 'prop-${DateTime.now().millisecondsSinceEpoch}';

      _mockProperties.add(
        Property(
          id: propId,
          name: buildingName,
          addressLine1: address,
          city: 'Cairo',
          state: 'Egypt',
          postalCode: '11511',
          country: 'Egypt',
        ),
      );

      // Generate unit listings automatically
      for (int floor = 1; floor <= floorsCount; floor++) {
        for (int apt = 1; apt <= apartmentsPerFloor; apt++) {
          final aptNumber = floor * 100 + apt;
          final unitId = 'unit-$propId-$floor-$apt';
          final unitNumber = '$buildingName - Floor $floor - Apt $aptNumber';

          _mockUnits.add(
            Unit(
              id: unitId,
              propertyId: propId,
              unitNumber: unitNumber,
              floor: floor,
              status: 'vacant',
            ),
          );
        }
      }
    } else {
      try {
        final client = SupabaseClientHelper.client;

        final propRes = await client
            .from('properties')
            .insert({
              'name': buildingName,
              'address_line_1': address,
              'city': 'Cairo',
              'state': 'Egypt',
              'postal_code': '11511',
              'country': 'Egypt',
            })
            .select()
            .single();

        final propId = propRes['id'];

        // Batch insert units
        final List<Map<String, dynamic>> unitsToInsert = [];
        for (int floor = 1; floor <= floorsCount; floor++) {
          for (int apt = 1; apt <= apartmentsPerFloor; apt++) {
            final aptNumber = floor * 100 + apt;
            final unitNumber = '$buildingName - Floor $floor - Apt $aptNumber';
            unitsToInsert.add({
              'property_id': propId,
              'unit_number': unitNumber,
              'floor': floor,
              'status': 'vacant',
            });
          }
        }
        await client.from('units').insert(unitsToInsert);
      } catch (e) {
        throw Exception(e.toString());
      }
    }
  }

  Future<void> createUnitAndLease({
    required String unitNumber,
    required int floor,
    required String residentId,
    required double monthlyRent,
    required double securityDeposit,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (SupabaseClientHelper.isMockMode) {
      await Future.delayed(const Duration(milliseconds: 500));

      // 1. Check if unit exists in mock units list, update status to occupied
      final unitIdx = _mockUnits.indexWhere((u) => u.unitNumber == unitNumber);
      String unitId = 'unit-new-${DateTime.now().millisecondsSinceEpoch}';

      if (unitIdx != -1) {
        unitId = _mockUnits[unitIdx].id;
        _mockUnits[unitIdx] = _mockUnits[unitIdx].copyWith(status: 'occupied');
      } else {
        // Create dynamic new unit
        _mockUnits.add(
          Unit(
            id: unitId,
            propertyId: 'prop-1',
            unitNumber: unitNumber,
            floor: floor,
            status: 'occupied',
          ),
        );
      }

      // 2. Add lease
      _mockLeases.add(
        Lease(
          id: 'lease-${DateTime.now().millisecondsSinceEpoch}',
          unitId: unitId,
          residentId: residentId,
          startDate: startDate,
          endDate: endDate,
          monthlyRent: monthlyRent,
          securityDeposit: securityDeposit,
          status: 'active',
        ),
      );

      _authService.updateMockTenantUnit(residentId, unitNumber);
    } else {
      try {
        final client = SupabaseClientHelper.client;

        // Find unit ID by name first or insert new
        final existingUnit = await client
            .from('units')
            .select()
            .eq('unit_number', unitNumber)
            .maybeSingle();

        String unitId;
        if (existingUnit != null) {
          unitId = existingUnit['id'];
          // Update status to occupied
          await client
              .from('units')
              .update({'status': 'occupied'})
              .eq('id', unitId);
        } else {
          final unitRes = await client
              .from('units')
              .insert({
                'property_id': 'prop-1',
                'unit_number': unitNumber,
                'floor': floor,
                'status': 'occupied',
              })
              .select()
              .single();
          unitId = unitRes['id'];
        }

        await client.from('leases').insert({
          'unit_id': unitId,
          'resident_id': residentId,
          'start_date': startDate.toIso8601String(),
          'end_date': endDate.toIso8601String(),
          'monthly_rent': monthlyRent,
          'security_deposit': securityDeposit,
          'status': 'active',
        });
      } catch (e) {
        throw Exception(e.toString());
      }
    }
  }

  Future<Lease?> getActiveLeaseForUnit(String unitId) async {
    if (SupabaseClientHelper.isMockMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      final idx = _mockLeases.indexWhere(
        (l) => l.unitId == unitId && l.status == 'active',
      );
      return idx == -1 ? null : _mockLeases[idx];
    } else {
      try {
        final client = SupabaseClientHelper.client;
        final res = await client
            .from('leases')
            .select()
            .eq('unit_id', unitId)
            .eq('status', 'active')
            .maybeSingle();

        if (res == null) return null;

        return Lease(
          id: res['id'],
          unitId: res['unit_id'],
          residentId: res['resident_id'],
          startDate: DateTime.parse(res['start_date']),
          endDate: DateTime.parse(res['end_date']),
          monthlyRent: (res['monthly_rent'] as num).toDouble(),
          securityDeposit: (res['security_deposit'] as num).toDouble(),
          status: res['status'],
        );
      } catch (e) {
        throw Exception(e.toString());
      }
    }
  }
}
