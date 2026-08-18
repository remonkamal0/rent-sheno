import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/services/providers.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/localizations.dart';
import '../../../core/widgets/sms_app_bar.dart';
import '../../../core/widgets/sms_drawer.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/skeleton_loading.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/app_text_field.dart';

class InsuranceScreen extends ConsumerStatefulWidget {
  const InsuranceScreen({super.key});

  @override
  ConsumerState<InsuranceScreen> createState() => _InsuranceScreenState();
}

class _InsuranceScreenState extends ConsumerState<InsuranceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _providerController = TextEditingController();
  final _policyNumberController = TextEditingController();
  final _coverageController = TextEditingController();
  final _expirationDateController = TextEditingController();

  DateTime? _selectedExpirationDate;
  File? _selectedProofFile;
  String? _selectedProofFileName;
  bool _isLoading = false;

  @override
  void dispose() {
    _providerController.dispose();
    _policyNumberController.dispose();
    _coverageController.dispose();
    _expirationDateController.dispose();
    super.dispose();
  }

  Future<void> _selectExpirationDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedExpirationDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
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
        _selectedExpirationDate = picked;
        _expirationDateController.text = DateFormat('MM/dd/yyyy').format(picked);
      });
    }
  }

  Future<void> _pickProofFile() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final sizeInMb = await file.length() / (1024 * 1024);

        if (sizeInMb > 5.0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File size must be less than 5MB')),
          );
          return;
        }

        setState(() {
          _selectedProofFile = file;
          _selectedProofFileName = result.files.single.name;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick document: $e')),
      );
    }
  }

  void _removeProofFile() {
    setState(() {
      _selectedProofFile = null;
      _selectedProofFileName = null;
    });
  }

  Future<void> _handleSavePolicy() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedExpirationDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an expiration date')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final notifier = ref.read(insurancePolicyProvider.notifier);
      final storage = ref.read(storageServiceProvider);

      String? docUrl;
      if (_selectedProofFile != null) {
        docUrl = await storage.uploadInsuranceDocument(
          file: _selectedProofFile!,
          userId: ref.read(authStateProvider).value?.id ?? 'temp-user',
        );
      }

      final amount = double.tryParse(_coverageController.text) ?? 50000.0;

      await notifier.updatePolicyInfo(
        provider: _providerController.text,
        policyNumber: _policyNumberController.text,
        coverageAmount: amount,
        expirationDate: _selectedExpirationDate!,
        localDocPath: docUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Policy information updated successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        // Clear form
        setState(() {
          _providerController.clear();
          _policyNumberController.clear();
          _coverageController.clear();
          _expirationDateController.clear();
          _selectedExpirationDate = null;
          _selectedProofFile = null;
          _selectedProofFileName = null;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating policy: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final policyState = ref.watch(insurancePolicyProvider);

    return Scaffold(
      appBar: const SmsAppBar(),
      drawer: const SmsDrawer(),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(insurancePolicyProvider),
        child: ListView(
          padding: const EdgeInsets.all(24.0),
          children: [
            // Page Header
            Text(
              localizations.translate('insurance_coverage'),
              style: AppTextStyles.heading1.copyWith(fontSize: 28),
            ),
            const SizedBox(height: 6),
            Text(
              localizations.translate('insurance_desc'),
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 24),

            // 1. Current Insurance Policy Card
            policyState.when(
              data: (policy) {
                if (policy == null) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          const Icon(LucideIcons.shieldAlert, color: AppColors.warning, size: 40),
                          const SizedBox(height: 12),
                          const Text(
                            'No Active Policy Registered',
                            style: AppTextStyles.heading3,
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Please upload your renter\'s insurance policy to comply with your lease agreement.',
                            style: AppTextStyles.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final bool isWarning = policy.calculatedStatus == 'expiring_soon';

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title header & status
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: const BoxDecoration(
                                color: AppColors.lightBlue,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                LucideIcons.shield,
                                color: AppColors.primaryNavy,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    policy.provider,
                                    style: AppTextStyles.heading3.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${localizations.translate('policy_no')}: ${policy.policyNumber}',
                                    style: AppTextStyles.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            StatusBadge(status: policy.status),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Sub-metrics Grid (2x2 Grid using columns/rows for responsiveness)
                        Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildPolicyDetailPill(
                                    label: localizations.translate('coverage_amount'),
                                    value: '\$${NumberFormat('#,###').format(policy.coverageAmount)}',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildPolicyDetailPill(
                                    label: localizations.translate('deductible'),
                                    value: '\$${NumberFormat('#,###').format(policy.deductible)}',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildPolicyDetailPill(
                                    label: localizations.translate('effective_date'),
                                    value: DateFormatter.formatShortDate(policy.effectiveDate),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildPolicyDetailPill(
                                    label: localizations.translate('expiration_date'),
                                    value: DateFormatter.formatShortDate(policy.expirationDate),
                                    isWarning: isWarning,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // View Full PDF button
                        if (policy.documentUrl != null)
                          AppSecondaryButton(
                            text: localizations.translate('view_pdf'),
                            icon: LucideIcons.fileText,
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Mock PDF Viewer: Policy loaded successfully.')),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                );
              },
              loading: () => const SkeletonContainer(width: double.infinity, height: 260),
              error: (err, stack) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 24),

            // 2. Update Policy Info Form Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(LucideIcons.fileEdit, color: AppColors.primaryNavy, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            localizations.translate('update_policy'),
                            style: AppTextStyles.heading3.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Divider(color: AppColors.border),
                      const SizedBox(height: 16),

                      Text(
                        'If you have recently renewed or changed your provider, please update your details below.',
                        style: AppTextStyles.bodySmall,
                      ),
                      const SizedBox(height: 20),

                      // Provider Name
                      AppTextField(
                        label: localizations.translate('provider'),
                        hint: 'e.g. StateFarm, Lemonade',
                        controller: _providerController,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Provider is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Policy Number
                      AppTextField(
                        label: localizations.translate('policy_number'),
                        hint: 'Policy ID',
                        controller: _policyNumberController,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Policy number is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Coverage Amount
                      AppTextField(
                        label: 'Coverage Amount (\$)',
                        hint: '100000',
                        controller: _coverageController,
                        keyboardType: TextInputType.number,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Coverage amount is required';
                          }
                          final amt = double.tryParse(val);
                          if (amt == null || amt <= 0) {
                            return 'Enter a valid amount';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Expiration Date
                      AppTextField(
                        label: localizations.translate('expiration_date'),
                        controller: _expirationDateController,
                        readOnly: true,
                        hint: 'mm/dd/yyyy',
                        suffixIcon: const Icon(LucideIcons.calendar, color: AppColors.secondaryText),
                        onTap: () => _selectExpirationDate(context),
                      ),
                      const SizedBox(height: 20),

                      // UploadProof Box
                      Text(
                        localizations.translate('upload_proof').toUpperCase(),
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.secondaryText,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 8),

                      if (_selectedProofFileName != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(LucideIcons.fileText, color: AppColors.primaryNavy, size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _selectedProofFileName!,
                                  style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(LucideIcons.trash2, color: AppColors.error, size: 18),
                                onPressed: _removeProofFile,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ] else
                        InkWell(
                          onTap: _pickProofFile,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                            decoration: BoxDecoration(
                              color: AppColors.lightBlue.withOpacity(0.15),
                              border: Border.all(
                                color: AppColors.primaryNavy.withOpacity(0.3),
                                style: BorderStyle.values[0], // dashed/dotted border would be custom painter, standard border is solid
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                const Icon(LucideIcons.uploadCloud, color: AppColors.primaryNavy, size: 36),
                                const SizedBox(height: 12),
                                Text(
                                  'Click to upload or drag and drop',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryNavy,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'SVG, PNG, JPG or PDF (max. 5MB)',
                                  style: AppTextStyles.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),

                      // Save Button
                      AppPrimaryButton(
                        text: localizations.translate('save_updates'),
                        isLoading: _isLoading,
                        onTap: _handleSavePolicy,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPolicyDetailPill({
    required String label,
    required String value,
    bool isWarning = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.lightBlue.withOpacity(0.4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: AppTextStyles.label.copyWith(
              color: AppColors.secondaryText,
              fontSize: 9,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                value,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isWarning ? AppColors.error : AppColors.primaryNavy,
                ),
              ),
              if (isWarning) ...[
                const SizedBox(width: 6),
                const Icon(LucideIcons.alertCircle, color: AppColors.error, size: 14),
              ],
            ],
          ),
        ],
      ),
    );
  }

}
