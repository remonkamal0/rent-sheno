import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/services/providers.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/app_text_field.dart';

class ManagerCreateChargeScreen extends ConsumerStatefulWidget {
  const ManagerCreateChargeScreen({super.key});

  @override
  ConsumerState<ManagerCreateChargeScreen> createState() => _ManagerCreateChargeScreenState();
}

class _ManagerCreateChargeScreenState extends ConsumerState<ManagerCreateChargeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController(text: 'Monthly Rent Invoice');
  final _amountController = TextEditingController(text: '1500.0');
  final _descController = TextEditingController(text: 'Standard monthly apartment unit rent.');

  String? _selectedTenant;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 10));
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _selectDueDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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
    if (picked != null && picked != _dueDate) {
      setState(() {
        _dueDate = picked;
      });
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTenant == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a target apartment resident!'), backgroundColor: AppColors.error),
      );
      return;
    }

    final double? amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount!'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final chargesNotifier = ref.read(chargesProvider.notifier);
      await chargesNotifier.createTenantCharge(
        residentId: _selectedTenant!,
        leaseId: 'mock-lease-123', // Demo fallback lease relation
        title: _titleController.text.trim(),
        amount: amount,
        dueDate: _dueDate,
        description: _descController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rent claim issued and sent to tenant successfully!'),
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
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
        title: const Text('Issue Rent Claim'),
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
                  'Create Rent Claim Bill',
                  style: AppTextStyles.heading2.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Define the monthly rent bill for an apartment unit. The tenant will receive a bill alert in their dashboard to submit proof of payment.',
                  style: AppTextStyles.bodyMedium,
                ),
                const SizedBox(height: 28),

                // Select Tenant Dropdown
                Text(
                  'TARGET APARTMENT / RESIDENT',
                  style: AppTextStyles.label.copyWith(color: AppColors.secondaryText, fontSize: 10),
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
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      items: tenants.map((t) {
                        return DropdownMenuItem<String>(
                          value: t.id,
                          child: Text('${t.fullName} (${t.unitNumber ?? "Unit"})', style: AppTextStyles.bodyMedium),
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
                  error: (e, _) => const Text('Error loading tenants directory'),
                ),
                const SizedBox(height: 20),

                // Title
                AppTextField(
                  label: 'Rent Claim Title',
                  controller: _titleController,
                  hint: 'e.g. September 2026 Rent Bill',
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Required';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Amount
                AppTextField(
                  label: 'Rent Amount (\$)',
                  controller: _amountController,
                  hint: 'e.g. 1500.00',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Required';
                    if (double.tryParse(val.trim()) == null) return 'Enter valid amount';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Description
                AppTextField(
                  label: 'Payment Description',
                  controller: _descController,
                  hint: 'e.g. Monthly rent due by first of month.',
                  maxLines: 2,
                ),
                const SizedBox(height: 20),

                // Due Date Picker Trigger
                Text(
                  'PAYMENT DUE DATE',
                  style: AppTextStyles.label.copyWith(color: AppColors.secondaryText, fontSize: 10),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => _selectDueDate(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormatter.formatShortDate(_dueDate),
                          style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                        ),
                        const Icon(Icons.calendar_today_rounded, color: AppColors.primaryNavy, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 36),

                // Submit CTA
                AppPrimaryButton(
                  text: 'Issue Rent Claim & Send Bill',
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
