import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/services/providers.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/localizations.dart';
import '../../../core/widgets/sms_app_bar.dart';
import '../../../core/widgets/sms_drawer.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/app_text_field.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emergencyController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  File? _avatarFile;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  void _loadProfileData() {
    final user = ref.read(authServiceProvider).currentUser;
    if (user != null) {
      _nameController.text = user.fullName;
      _phoneController.text = user.phone ?? '';
      _avatarUrl = user.avatarUrl;
    }
    // Mock Emergency Contact prefill
    _emergencyController.text = 'Jane Doe (Mother) - +1 (555) 012-9842';
  }

  Future<void> _pickAvatar() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 150,
      );

      if (image != null) {
        setState(() {
          _avatarFile = File(image.path);
        });
        
        // Upload immediately
        _uploadAvatar();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick avatar: $e')),
      );
    }
  }

  Future<void> _uploadAvatar() async {
    if (_avatarFile == null) return;

    try {
      final storage = ref.read(storageServiceProvider);
      final userId = ref.read(authServiceProvider).currentUser?.id ?? 'temp-user';
      
      final publicUrl = await storage.uploadAvatar(
        file: _avatarFile!,
        userId: userId,
      );

      setState(() {
        _avatarUrl = publicUrl;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload avatar: $e')),
      );
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = ref.read(authServiceProvider);
      await authService.updateProfile(
        fullName: _nameController.text,
        phone: _phoneController.text,
        avatarUrl: _avatarUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving updates: $e')),
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
    final authState = ref.watch(authStateProvider);
    final residenceState = ref.watch(residenceDetailsProvider);
    
    final user = authState.value;
    final residence = residenceState.value;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const SmsAppBar(),
      drawer: const SmsDrawer(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Profile Avatar Header
                Center(
                  child: Stack(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.primaryNavy, width: 2),
                          image: DecorationImage(
                            image: _avatarFile != null
                                ? FileImage(_avatarFile!)
                                : NetworkImage(_avatarUrl ??
                                        'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&q=80&w=150')
                                    as ImageProvider,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _pickAvatar,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: AppColors.primaryNavy,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              LucideIcons.camera,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  user?.fullName ?? '',
                  style: AppTextStyles.heading2.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  user?.email ?? '',
                  style: AppTextStyles.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // 1. Contact Info Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(LucideIcons.user, color: AppColors.primaryNavy, size: 20),
                            const SizedBox(width: 10),
                            Text(
                              'Personal Information',
                              style: AppTextStyles.heading3.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Divider(color: AppColors.border),
                        const SizedBox(height: 16),

                        // Full name input
                        AppTextField(
                          label: localizations.translate('full_name'),
                          controller: _nameController,
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Full name is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Phone input
                        AppTextField(
                          label: localizations.translate('phone_number'),
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Phone number is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Emergency Contact
                        AppTextField(
                          label: localizations.translate('emergency_contact'),
                          controller: _emergencyController,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 2. Lease Details Card (Read Only)
                if (residence != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(LucideIcons.home, color: AppColors.primaryNavy, size: 20),
                              const SizedBox(width: 10),
                              Text(
                                'Residence details',
                                style: AppTextStyles.heading3.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Divider(color: AppColors.border),
                          const SizedBox(height: 16),
                          _buildProfileRow('Property', residence.property.name),
                          const Divider(height: 24),
                          _buildProfileRow('Unit Number', residence.unit.unitNumber),
                          const Divider(height: 24),
                          _buildProfileRow('Lease Start Date', DateFormatter.formatShortDate(residence.lease.startDate)),
                          const Divider(height: 24),
                          _buildProfileRow('Lease End Date', DateFormatter.formatShortDate(residence.lease.endDate)),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 32),

                // Save Updates Button
                AppPrimaryButton(
                  text: localizations.translate('save_changes'),
                  isLoading: _isLoading,
                  onTap: _handleSave,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.secondaryText),
        ),
        Text(
          value,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.primaryText,
          ),
        ),
      ],
    );
  }
}
