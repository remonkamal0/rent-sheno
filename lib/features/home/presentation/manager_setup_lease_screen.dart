import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
  ConsumerState<ManagerSetupLeaseScreen> createState() => _ManagerSetupLeaseScreenState();
}

class _ManagerSetupLeaseScreenState extends ConsumerState<ManagerSetupLeaseScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _unitController;
  final _floorController = TextEditingController(text: '1');
  final _rentController = TextEditingController(text: '1500.0');
  final _depositController = TextEditingController(text: '1000.0');

  String? _selectedTenant;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 365));
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _unitController = TextEditingController(text: widget.preSelectedUnitNumber ?? '');
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
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTenant == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a tenant user!'), backgroundColor: AppColors.error),
      );
      return;
    }

    final double? rent = double.tryParse(_rentController.text.trim());
    final double? deposit = double.tryParse(_depositController.text.trim());
    final int? floor = int.tryParse(_floorController.text.trim());

    if (rent == null || rent <= 0 || deposit == null || floor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid numeric details!'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final residenceService = ref.read(residenceServiceProvider);
      await residenceService.createUnitAndLease(
        unitNumber: _unitController.text.trim(),
        floor: floor,
        residentId: _selectedTenant!,
        monthlyRent: rent,
        securityDeposit: deposit,
        startDate: _startDate,
        endDate: _endDate,
      );

      // Invalidate provider so home dashboard apartment list is refreshed
      ref.invalidate(managerTenantsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('New unit created and tenant linked successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tenantsState = ref.watch(managerTenantsProvider);
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: context.cardColor,
        leading: const SmsBackButton(),
        title: Text(localizations.translate('setup_apartment_lease'), style: TextStyle(color: context.primaryTextColor)),
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
                  style: AppTextStyles.heading2.copyWith(fontWeight: FontWeight.bold, color: context.primaryTextColor),
                ),
                const SizedBox(height: 8),
                Text(
                  localizations.translate('create_lease_desc'),
                  style: AppTextStyles.bodyMedium.copyWith(color: context.secondaryTextColor),
                ),
                const SizedBox(height: 28),

                // Select Tenant Dropdown
                Text(
                  localizations.translate('select_registered_user'),
                  style: AppTextStyles.label.copyWith(color: context.secondaryTextColor, fontSize: 10),
                ),
                const SizedBox(height: 8),
                tenantsState.when(
                  data: (tenants) {
                    final containsSelected = tenants.any((t) => t.id == _selectedTenant);
                    if (!containsSelected && tenants.isNotEmpty) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        setState(() => _selectedTenant = tenants.first.id);
                      });
                    }

                    return DropdownButtonFormField<String>(
                      value: containsSelected ? _selectedTenant : (tenants.isNotEmpty ? tenants.first.id : null),
                      dropdownColor: context.cardColor,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      items: tenants.map((t) {
                        return DropdownMenuItem<String>(
                          value: t.id,
                          child: Text(
                            '${t.fullName} (${t.email})',
                            style: AppTextStyles.bodyMedium.copyWith(color: context.primaryTextColor),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedTenant = val);
                        }
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryNavy)),
                  error: (e, _) => Text(localizations.translate('error_loading_users'), style: TextStyle(color: context.primaryTextColor)),
                ),
                const SizedBox(height: 20),

                // Unit Number
                AppTextField(
                  label: localizations.translate('apartment_unit_number'),
                  controller: _unitController,
                  hint: localizations.translate('hint_unit_number'),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Required';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Floor
                AppTextField(
                  label: localizations.translate('floor_number'),
                  controller: _floorController,
                  hint: localizations.translate('hint_floor'),
                  keyboardType: TextInputType.number,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Required';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Monthly Rent
                AppTextField(
                  label: localizations.translate('monthly_rent_label'),
                  controller: _rentController,
                  hint: localizations.translate('hint_rent_amount'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Required';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Security Deposit
                AppTextField(
                  label: localizations.translate('security_deposit_label'),
                  controller: _depositController,
                  hint: localizations.translate('hint_rent_amount'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Required';
                    return null;
                  },
                ),
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
                            style: AppTextStyles.label.copyWith(color: context.secondaryTextColor, fontSize: 10),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () => _selectDate(context, true),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                              decoration: BoxDecoration(
                                color: context.cardColor,
                                border: Border.all(color: context.borderColor),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    DateFormatter.formatShortDate(_startDate),
                                    style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: context.primaryTextColor),
                                  ),
                                  const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.primaryNavy),
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
                            style: AppTextStyles.label.copyWith(color: context.secondaryTextColor, fontSize: 10),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () => _selectDate(context, false),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                              decoration: BoxDecoration(
                                color: context.cardColor,
                                border: Border.all(color: context.borderColor),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    DateFormatter.formatShortDate(_endDate),
                                    style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: context.primaryTextColor),
                                  ),
                                  const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.primaryNavy),
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
                  onTap: _handleSave,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
