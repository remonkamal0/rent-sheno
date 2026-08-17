import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/services/providers.dart';
import '../../../core/utils/localizations.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/app_text_field.dart';

class NewRequestScreen extends ConsumerStatefulWidget {
  const NewRequestScreen({super.key});

  @override
  ConsumerState<NewRequestScreen> createState() => _NewRequestScreenState();
}

class _NewRequestScreenState extends ConsumerState<NewRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dateController = TextEditingController();
  final _infoController = TextEditingController();

  String _selectedCategory = 'other'; // plumbing, electrical, appliance, other
  DateTime? _selectedDate;
  final List<File> _attachedPhotos = [];
  final ImagePicker _picker = ImagePicker();
  
  bool _isLoading = false;
  String? _successRequestNo;

  @override
  void initState() {
    super.initState();
    _prefillResidentName();
  }

  void _prefillResidentName() {
    final user = ref.read(authStateProvider).value;
    if (user != null) {
      _nameController.text = user.fullName;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dateController.dispose();
    _infoController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
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
        _selectedDate = picked;
        _dateController.text = DateFormat('MM/dd/yyyy').format(picked);
      });
    }
  }

  Future<void> _pickImage() async {
    if (_attachedPhotos.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 3 photos allowed')),
      );
      return;
    }

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _attachedPhotos.add(File(image.path));
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $e')),
      );
    }
  }

  void _removeImage(int index) {
    setState(() {
      _attachedPhotos.removeAt(index);
    });
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a preferred repair date')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final notifier = ref.read(maintenanceRequestsProvider.notifier);
      final storage = ref.read(storageServiceProvider);

      // 1. Upload photos if any
      final List<String> uploadedUrls = [];
      for (var i = 0; i < _attachedPhotos.length; i++) {
        final file = _attachedPhotos[i];
        final url = await storage.uploadMaintenanceAttachment(
          file: file,
          requestId: 'temp-req-${DateTime.now().millisecondsSinceEpoch}-$i',
        );
        uploadedUrls.add(url);
      }

      // 2. Submit request
      // We generate temporary title from first words of info or category name
      final title = '${_selectedCategory.toUpperCase()} request';
      
      await notifier.addRequest(
        title: title,
        category: _selectedCategory,
        description: _infoController.text,
        preferredDate: _selectedDate!,
        attachmentPaths: uploadedUrls,
      );

      // Find the last request we just added to fetch request number
      final updatedList = ref.read(maintenanceRequestsProvider).value ?? [];
      final lastReq = updatedList.isNotEmpty ? updatedList.first.requestNumber : 'MR-2026-00000';

      setState(() {
        _successRequestNo = lastReq;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting request: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    if (_successRequestNo != null) {
      return _buildSuccessView();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(localizations.translate('new_request')),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back navigation link
                GestureDetector(
                  onTap: () => context.pop(),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.arrowLeft, size: 14, color: AppColors.primaryNavy),
                      const SizedBox(width: 4),
                      Text(
                        'Back to Dashboard',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.primaryNavy,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  localizations.translate('new_request'),
                  style: AppTextStyles.heading1,
                ),
                const SizedBox(height: 6),
                Text(
                  'Please provide details about the issue.',
                  style: AppTextStyles.bodyMedium,
                ),
                const SizedBox(height: 24),

                // Form Container
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AppColors.border, width: 1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Issue Category Grid
                      Text(
                        localizations.translate('category').toUpperCase(),
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.secondaryText,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 10),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.6,
                        children: [
                          _buildCategoryCard(
                            id: 'plumbing',
                            label: localizations.translate('plumbing'),
                            icon: LucideIcons.droplet,
                          ),
                          _buildCategoryCard(
                            id: 'electrical',
                            label: localizations.translate('electrical'),
                            icon: LucideIcons.zap,
                          ),
                          _buildCategoryCard(
                            id: 'appliance',
                            label: localizations.translate('appliance'),
                            icon: LucideIcons.refrigerator,
                          ),
                          _buildCategoryCard(
                            id: 'other',
                            label: localizations.translate('other'),
                            icon: LucideIcons.wrench,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Full Name
                      AppTextField(
                        label: localizations.translate('full_name'),
                        controller: _nameController,
                        readOnly: true,
                      ),
                      const SizedBox(height: 20),

                      // Preferred Date
                      AppTextField(
                        label: localizations.translate('preferred_date'),
                        controller: _dateController,
                        readOnly: true,
                        hint: 'mm/dd/yyyy',
                        suffixIcon: const Icon(LucideIcons.calendar, color: AppColors.secondaryText),
                        onTap: () => _selectDate(context),
                      ),
                      const SizedBox(height: 20),

                      // Request Information
                      AppTextField(
                        label: localizations.translate('req_info'),
                        controller: _infoController,
                        maxLines: 4,
                        hint: localizations.translate('describe_issue'),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Details are required';
                          }
                          if (val.trim().length < 10) {
                            return 'Please describe the issue in at least 10 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Attach Photos Section
                      Text(
                        localizations.translate('attach_photos').toUpperCase(),
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.secondaryText,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      // Photos previews or Pick Area
                      if (_attachedPhotos.isNotEmpty) ...[
                        Row(
                          children: List.generate(_attachedPhotos.length, (index) {
                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 72,
                                  height: 72,
                                  margin: const EdgeInsets.only(right: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: AppColors.border),
                                    borderRadius: BorderRadius.circular(8),
                                    image: DecorationImage(
                                      image: FileImage(_attachedPhotos[index]),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: -8,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () => _removeImage(index),
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        color: AppColors.error,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Upload Area Button
                      if (_attachedPhotos.length < 3)
                        InkWell(
                          onTap: _pickImage,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: AppColors.lightBlue.withOpacity(0.3),
                              border: Border.all(color: AppColors.primaryNavy.withOpacity(0.3), width: 1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(LucideIcons.uploadCloud, color: AppColors.primaryNavy, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  localizations.translate('upload_photos'),
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.primaryNavy,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        localizations.translate('max_photos'),
                        style: AppTextStyles.bodySmall.copyWith(
                          fontSize: 11,
                          color: AppColors.secondaryText,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Submit Request Button
                      AppPrimaryButton(
                        text: localizations.translate('submit_request'),
                        isLoading: _isLoading,
                        onTap: _handleSubmit,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCard({
    required String id,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _selectedCategory == id;
    
    return InkWell(
      onTap: () {
        setState(() {
          _selectedCategory = id;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? AppColors.lightBlue.withOpacity(0.3) : Colors.white,
          border: Border.all(
            color: isSelected ? AppColors.primaryNavy : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected ? AppColors.primaryNavy : AppColors.secondaryText,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: AppTextStyles.label.copyWith(
                color: isSelected ? AppColors.primaryNavy : AppColors.primaryText,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessView() {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: AppColors.successBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline_rounded,
                  size: 80,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                localizations.translate('req_success'),
                style: AppTextStyles.heading2.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Request #${_successRequestNo!}',
                style: AppTextStyles.heading3.copyWith(
                  color: AppColors.primaryNavy,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              AppPrimaryButton(
                text: localizations.translate('view_request'),
                onTap: () {
                  context.replace('/maintenance/${_successRequestNo!}');
                },
              ),
              const SizedBox(height: 16),
              AppSecondaryButton(
                text: localizations.translate('back_to_home'),
                onTap: () {
                  context.go('/home');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
