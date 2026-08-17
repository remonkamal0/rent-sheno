import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/services/providers.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/app_text_field.dart';

class ManagerSetupLeaseScreen extends ConsumerStatefulWidget {
  const ManagerSetupLeaseScreen({super.key});

  @override
  ConsumerState<ManagerSetupLeaseScreen> createState() => _ManagerSetupLeaseScreenState();
}

class _ManagerSetupLeaseScreenState extends ConsumerState<ManagerSetupLeaseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _unitController = TextEditingController();
  final _floorController = TextEditingController(text: '1');
  final _rentController = TextEditingController(text: '1500.0');
  final _depositController = TextEditingController(text: '1000.0');

  String? _selectedTenant;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 365));
  bool _isSaving = false;

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

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: context.cardColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              context.pop();
            }
          },
        ),
        title: Text('Setup Apartment Lease', style: TextStyle(color: context.primaryTextColor)),
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
                  'Add Unit & Assign Tenant',
                  style: AppTextStyles.heading2.copyWith(fontWeight: FontWeight.bold, color: context.primaryTextColor),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create a new apartment unit, define the monthly rent price, and select a registered tenant user to link them.',
                  style: AppTextStyles.bodyMedium.copyWith(color: context.secondaryTextColor),
                ),
                const SizedBox(height: 28),

                // Select Tenant Dropdown
                Text(
                  'SELECT REGISTERED USER',
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
                  error: (e, _) => Text('Error loading users', style: TextStyle(color: context.primaryTextColor)),
                ),
                const SizedBox(height: 20),

                // Unit Number
                AppTextField(
                  label: 'Apartment Unit Number',
                  controller: _unitController,
                  hint: 'e.g. Unit 501 / Apt 304',
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Required';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Floor
                AppTextField(
                  label: 'Floor Number',
                  controller: _floorController,
                  hint: 'e.g. 5',
                  keyboardType: TextInputType.number,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Required';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Monthly Rent
                AppTextField(
                  label: 'Monthly Rent (\$)',
                  controller: _rentController,
                  hint: 'e.g. 1500.00',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Required';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Security Deposit
                AppTextField(
                  label: 'Security Deposit (\$)',
                  controller: _depositController,
                  hint: 'e.g. 1000.00',
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
                            'LEASE START DATE',
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
                            'LEASE END DATE',
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
                  text: 'Create Lease & Link Tenant',
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
