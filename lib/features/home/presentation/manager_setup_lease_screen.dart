import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/services/providers.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/localizations.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/sms_back_button.dart';

class ManagerSetupLeaseScreen extends ConsumerStatefulWidget {
  final String? preSelectedUnitNumber;
  const ManagerSetupLeaseScreen({super.key, this.preSelectedUnitNumber});

  @override
  ConsumerState<ManagerSetupLeaseScreen> createState() =>
      _ManagerSetupLeaseScreenState();
}

class _ManagerSetupLeaseScreenState
    extends ConsumerState<ManagerSetupLeaseScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _unitController;
  final _floorController = TextEditingController(text: '1');
  final _rentController = TextEditingController(text: '1500.0');
  final _depositController = TextEditingController(text: '1000.0');

  String? _selectedTenant;
  String? _selectedUnitId;
  int _parkingCount = 0;
  final Set<String> _selectedParkingSpaceIds = {};
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 365));
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _unitController = TextEditingController(
      text: widget.preSelectedUnitNumber ?? '',
    );
  }

  @override
  void dispose() {
    _unitController.dispose();
    _floorController.dispose();
    _rentController.dispose();
    _depositController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryNavy,
              onPrimary: Colors.white,
              onSurface: AppColors.primaryText,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate.add(const Duration(days: 365));
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _handleSave() async {
    final localizations = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTenant == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localizations.text('Please select a tenant user!'),
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    final selectedTenantMatches = ref
        .read(managerTenantsProvider)
        .value
        ?.where((tenant) => tenant.id == _selectedTenant);
    if (selectedTenantMatches == null || selectedTenantMatches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The selected tenant could not be found.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    if (_selectedParkingSpaceIds.length != _parkingCount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please select exactly $_parkingCount parking space${_parkingCount == 1 ? '' : 's'}.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final selectedTenant = selectedTenantMatches.first;
    if (selectedTenant.unitNumber != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localizations.translate(
              'tenant_already_linked_error',
              selectedTenant.unitNumber,
            ),
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    final double? rent = double.tryParse(_rentController.text.trim());
    final double? deposit = double.tryParse(_depositController.text.trim());
    final int? floor = int.tryParse(_floorController.text.trim());

    if (rent == null || rent <= 0 || deposit == null || floor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            ).text('Please enter valid numeric details!'),
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final residenceService = ref.read(residenceServiceProvider);
      final unitId = await residenceService.createUnitAndLease(
        unitNumber: _unitController.text.trim(),
        floor: floor,
        residentId: _selectedTenant!,
        monthlyRent: rent,
        securityDeposit: deposit,
        startDate: _startDate,
        endDate: _endDate,
      );
      await ref.read(parkingServiceProvider).assignSpaces(
        parkingSpaceIds: _selectedParkingSpaceIds.toList(),
        unitId: unitId,
        residentId: _selectedTenant!,
        replaceExisting: true,
      );

      // Invalidate provider so home dashboard apartment list is refreshed
      ref.invalidate(managerTenantsProvider);
      ref.invalidate(managerUnitsProvider);
      ref.invalidate(managerParkingSpacesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(
                context,
              ).text('New unit created and tenant linked successfully!'),
            ),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        String displayError = e.toString();
        if (displayError.contains('two active parking spaces') ||
            displayError.contains('P0001')) {
          displayError = localizations.translate('parking_limit_exceeded');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              displayError.startsWith('Exception:')
                  ? displayError
                  : AppLocalizations.of(context).text('Error: {}', displayError),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tenantsState = ref.watch(managerTenantsProvider);
    final parkingState = ref.watch(managerParkingSpacesProvider);
    final unitsState = ref.watch(managerUnitsProvider);
    final localizations = AppLocalizations.of(context);
    final hasTenants = tenantsState.value?.isNotEmpty ?? false;
    final selectedTenantRows = tenantsState.value?.where(
      (tenant) => tenant.id == _selectedTenant,
    );
    final selectedTenantUnitNumber =
        selectedTenantRows != null && selectedTenantRows.isNotEmpty
        ? selectedTenantRows.first.unitNumber
        : null;

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: context.cardColor,
        leading: const SmsBackButton(),
        title: Text(
          localizations.translate('setup_apartment_lease'),
          style: TextStyle(color: context.primaryTextColor),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  localizations.translate('add_unit_assign_tenant'),
                  style: AppTextStyles.heading2.copyWith(
                    fontWeight: FontWeight.bold,
                    color: context.primaryTextColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  localizations.translate('create_lease_desc'),
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: context.secondaryTextColor,
                  ),
                ),
                const SizedBox(height: 28),

                // Select Tenant Dropdown
                Text(
                  localizations.translate('select_registered_user'),
                  style: AppTextStyles.label.copyWith(
                    color: context.secondaryTextColor,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 8),
                tenantsState.when(
                  data: (tenants) {
                    if (tenants.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.warningBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('No registered tenants found.'),
                      );
                    }

                    // Sort unassigned tenants to the top
                    final sortedTenants = [...tenants]..sort((a, b) {
                        if (a.unitNumber == null && b.unitNumber != null) return -1;
                        if (a.unitNumber != null && b.unitNumber == null) return 1;
                        return a.fullName.compareTo(b.fullName);
                      });

                    final containsSelected = sortedTenants.any(
                      (t) => t.id == _selectedTenant,
                    );
                    if (!containsSelected) {
                      final firstUnassigned = sortedTenants.where(
                        (t) => t.unitNumber == null,
                      );
                      final initialId = firstUnassigned.isNotEmpty
                          ? firstUnassigned.first.id
                          : sortedTenants.first.id;

                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          setState(
                            () => _selectedTenant = initialId,
                          );
                        }
                      });
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: containsSelected
                              ? _selectedTenant
                              : sortedTenants.first.id,
                          dropdownColor: context.cardColor,
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          items: sortedTenants.map((t) {
                            final isAssigned = t.unitNumber != null;
                            final tag = isAssigned
                                ? '[${localizations.translate('status_occupying', t.unitNumber)}]'
                                : '[${localizations.translate('status_unassigned')}]';

                            return DropdownMenuItem<String>(
                              value: t.id,
                              child: Row(
                                children: [
                                  Icon(
                                    isAssigned
                                        ? LucideIcons.lock
                                        : LucideIcons.userCheck,
                                    size: 14,
                                    color: isAssigned
                                        ? AppColors.warning
                                        : AppColors.success,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '${t.fullName} (${t.email}) • $tag',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        color: context.primaryTextColor,
                                        fontWeight: isAssigned
                                            ? FontWeight.normal
                                            : FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedTenant = val;
                                _selectedUnitId = null;
                                _selectedParkingSpaceIds.clear();
                              });
                            }
                          },
                        ),
                        if (selectedTenantUnitNumber != null)
                          Container(
                            margin: const EdgeInsets.only(top: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.warningBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.warning.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  LucideIcons.alertTriangle,
                                  color: AppColors.warning,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        localizations.translate(
                                          'tenant_already_linked_title',
                                        ),
                                        style: AppTextStyles.bodySmall.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.warning,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        localizations.translate(
                                          'tenant_already_linked_desc',
                                          selectedTenantUnitNumber,
                                        ),
                                        style: AppTextStyles.bodySmall.copyWith(
                                          color: AppColors.primaryText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryNavy,
                    ),
                  ),
                  error: (e, _) => Text(
                    localizations.translate('error_loading_users'),
                    style: TextStyle(color: context.primaryTextColor),
                  ),
                ),
                const SizedBox(height: 20),

                Text(
                  localizations.translate('apartment_unit_number'),
                  style: AppTextStyles.label.copyWith(
                    color: context.secondaryTextColor,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 8),
                unitsState.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (error, _) => Text(
                    'Could not load available apartments: $error',
                    style: const TextStyle(color: AppColors.error),
                  ),
                  data: (units) {
                    final availableUnits = units
                        .where(
                          (unit) =>
                              unit.status == 'vacant' ||
                              unit.unitNumber == widget.preSelectedUnitNumber,
                        )
                        .toList();
                    if (availableUnits.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.warningBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('No vacant apartments are available.'),
                      );
                    }

                    var selectedId = _selectedUnitId;
                    final preselectedMatches = availableUnits.where(
                      (unit) =>
                          unit.unitNumber == widget.preSelectedUnitNumber,
                    );
                    if (selectedId == null && preselectedMatches.isNotEmpty) {
                      selectedId = preselectedMatches.first.id;
                    }
                    final selectedExists = availableUnits.any(
                      (unit) => unit.id == selectedId,
                    );
                    final selectedUnit = selectedExists
                        ? availableUnits.firstWhere(
                            (unit) => unit.id == selectedId,
                          )
                        : availableUnits.first;

                    if (_selectedUnitId != selectedUnit.id ||
                        _unitController.text != selectedUnit.unitNumber) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        setState(() {
                          _selectedUnitId = selectedUnit.id;
                          _unitController.text = selectedUnit.unitNumber;
                          _floorController.text = '${selectedUnit.floor}';
                          _selectedParkingSpaceIds.clear();
                        });
                      });
                    }

                    return DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: selectedUnit.id,
                      dropdownColor: context.cardColor,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      items: availableUnits
                          .map(
                            (unit) => DropdownMenuItem(
                              value: unit.id,
                              child: Text(
                                unit.unitNumber,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: _isSaving
                          ? null
                          : (unitId) {
                              if (unitId == null) return;
                              final unit = availableUnits.firstWhere(
                                (item) => item.id == unitId,
                              );
                              setState(() {
                                _selectedUnitId = unit.id;
                                _unitController.text = unit.unitNumber;
                                _floorController.text = '${unit.floor}';
                                _selectedParkingSpaceIds.clear();
                              });
                            },
                    );
                  },
                ),
                const SizedBox(height: 20),

                // Floor
                AppTextField(
                  label: localizations.translate('floor_number'),
                  controller: _floorController,
                  hint: localizations.translate('hint_floor'),
                  keyboardType: TextInputType.number,
                  readOnly: true,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty)
                      return AppLocalizations.of(context).text('Required');
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Monthly Rent
                AppTextField(
                  label: localizations.translate('monthly_rent_label'),
                  controller: _rentController,
                  hint: localizations.translate('hint_rent_amount'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty)
                      return AppLocalizations.of(context).text('Required');
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Security Deposit
                AppTextField(
                  label: localizations.translate('security_deposit_label'),
                  controller: _depositController,
                  hint: localizations.translate('hint_rent_amount'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty)
                      return AppLocalizations.of(context).text('Required');
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                Text(
                  'NUMBER OF PARKING SPACES',
                  style: AppTextStyles.label.copyWith(
                    color: context.secondaryTextColor,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  children: [0, 1, 2].map((count) {
                    return ChoiceChip(
                      label: Text('$count'),
                      selected: _parkingCount == count,
                      onSelected: _isSaving
                          ? null
                          : (_) {
                              setState(() {
                                _parkingCount = count;
                                if (count == 0) {
                                  _selectedParkingSpaceIds.clear();
                                } else {
                                  while (_selectedParkingSpaceIds.length >
                                      count) {
                                    _selectedParkingSpaceIds.remove(
                                      _selectedParkingSpaceIds.last,
                                    );
                                  }
                                }
                              });
                            },
                    );
                  }).toList(),
                ),
                if (_parkingCount == 0) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Select 1 or 2 to show the available parking spaces.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: context.secondaryTextColor,
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 14),
                  Text(
                    'AVAILABLE PARKING SPACES',
                    style: AppTextStyles.label.copyWith(
                      color: context.secondaryTextColor,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 8),
                parkingState.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (error, _) => Text(
                    'Could not load parking spaces: $error',
                    style: const TextStyle(color: AppColors.error),
                  ),
                  data: (spaces) {
                    final selectedUnit = unitsState.value?.where(
                      (unit) => unit.unitNumber == _unitController.text.trim(),
                    );
                    final selectedPropertyId =
                        selectedUnit != null && selectedUnit.isNotEmpty
                        ? selectedUnit.first.propertyId
                        : null;
                    final currentAssigned = spaces
                        .where(
                          (space) =>
                              space.residentId == _selectedTenant ||
                              (selectedTenantUnitNumber != null &&
                                  space.unitNumber ==
                                      selectedTenantUnitNumber),
                        )
                        .toList();
                    final available = spaces
                        .where(
                          (space) =>
                              !space.isOccupied &&
                              (selectedPropertyId == null ||
                                  space.propertyId == selectedPropertyId),
                        )
                        .toList();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (currentAssigned.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.lightBlue,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.primaryNavy
                                    .withValues(alpha: 0.2),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      LucideIcons.info,
                                      size: 16,
                                      color: AppColors.primaryNavy,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      localizations.translate(
                                        'currently_assigned_parking',
                                      ),
                                      style: AppTextStyles.label.copyWith(
                                        color: AppColors.primaryNavy,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  currentAssigned
                                      .map(
                                        (s) =>
                                            '${s.spaceNumber} (Level ${s.level})',
                                      )
                                      .join(', '),
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryNavy,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  localizations.translate(
                                    'parking_replace_notice',
                                  ),
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.secondaryText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (available.isEmpty)
                          Text(
                            'No available parking spaces for this building.',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: context.secondaryTextColor,
                            ),
                          )
                        else
                          Container(
                            decoration: BoxDecoration(
                              color: context.cardColor,
                              border: Border.all(
                                color: context.borderColor,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.stretch,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    10,
                                    12,
                                    6,
                                  ),
                                  child: Text(
                                    '${_selectedParkingSpaceIds.length} of $_parkingCount selected',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.primaryNavy,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                ...available.map((space) {
                                  final selected =
                                      _selectedParkingSpaceIds.contains(
                                        space.id,
                                      );
                                  return CheckboxListTile(
                                    dense: true,
                                    value: selected,
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    secondary: const Icon(
                                      LucideIcons.car,
                                      size: 19,
                                      color: AppColors.primaryNavy,
                                    ),
                                    title: Text(
                                      space.spaceNumber,
                                      style: AppTextStyles.bodyMedium
                                          .copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: context.primaryTextColor,
                                          ),
                                    ),
                                    subtitle: Text(
                                      'Garage level ${space.level}',
                                    ),
                                    onChanged: _isSaving
                                        ? null
                                        : (value) {
                                            final shouldSelect =
                                                value ?? false;
                                            if (shouldSelect &&
                                                _selectedParkingSpaceIds
                                                        .length >=
                                                    _parkingCount) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'You already selected the required number of parking spaces.',
                                                  ),
                                                ),
                                              );
                                              return;
                                            }
                                            setState(() {
                                              if (shouldSelect) {
                                                _selectedParkingSpaceIds
                                                    .add(space.id);
                                              } else {
                                                _selectedParkingSpaceIds
                                                    .remove(space.id);
                                              }
                                            });
                                          },
                                  );
                                }),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
                ],
                const SizedBox(height: 20),

                // Date range pickers
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            localizations.translate('lease_start_date'),
                            style: AppTextStyles.label.copyWith(
                              color: context.secondaryTextColor,
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () => _selectDate(context, true),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: context.cardColor,
                                border: Border.all(color: context.borderColor),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    DateFormatter.formatShortDate(_startDate),
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: context.primaryTextColor,
                                    ),
                                  ),
                                  const Icon(
                                    Icons.calendar_today_rounded,
                                    size: 16,
                                    color: AppColors.primaryNavy,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            localizations.translate('lease_end_date'),
                            style: AppTextStyles.label.copyWith(
                              color: context.secondaryTextColor,
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () => _selectDate(context, false),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: context.cardColor,
                                border: Border.all(color: context.borderColor),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    DateFormatter.formatShortDate(_endDate),
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: context.primaryTextColor,
                                    ),
                                  ),
                                  const Icon(
                                    Icons.calendar_today_rounded,
                                    size: 16,
                                    color: AppColors.primaryNavy,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 36),

                // Submit button
                AppPrimaryButton(
                  text: localizations.translate('create_lease_link_tenant'),
                  isLoading: _isSaving,
                  onTap: hasTenants ? _handleSave : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
