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
  final String status;

  Unit({
    required this.id,
    required this.propertyId,
    required this.unitNumber,
    required this.floor,
    required this.status,
  });
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
  ResidenceDetails? _mockDetails;

  ResidenceService(this._authService) {
    _initMockData();
  }

  void _initMockData() {
    final now = DateTime.now();
    _mockDetails = ResidenceDetails(
      property: Property(
        id: 'prop-1',
        name: 'Maple Heights Apartments',
        addressLine1: '123 Maple St',
        addressLine2: null,
        city: 'Seattle',
        state: 'WA',
        postalCode: '98101',
        country: 'USA',
        imageUrl: 'https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?auto=format&fit=crop&q=80&w=600',
      ),
      unit: Unit(
        id: 'unit-402',
        propertyId: 'prop-1',
        unitNumber: 'Apt 402',
        floor: 4,
        status: 'occupied',
      ),
      lease: Lease(
        id: 'lease-101',
        unitId: 'unit-402',
        residentId: 'mock-user-123',
        startDate: DateTime(now.year, 1, 1),
        endDate: DateTime(now.year, 12, 31),
        monthlyRent: 2200.0,
        securityDeposit: 1500.0,
        status: 'active',
      ),
    );
  }

  Future<ResidenceDetails?> getResidenceDetails() async {
    if (SupabaseClientHelper.isMockMode) {
      await Future.delayed(const Duration(milliseconds: 500));
      return _mockDetails;
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

        return ResidenceDetails(
          property: property,
          unit: unit,
          lease: lease,
        );
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
      _authService.updateMockTenantUnit(residentId, unitNumber);
    } else {
      try {
        final client = SupabaseClientHelper.client;
        
        final unitRes = await client.from('units').insert({
          'property_id': 'prop-1',
          'unit_number': unitNumber,
          'floor': floor,
          'status': 'occupied',
        }).select().single();

        final unitId = unitRes['id'];

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
}
