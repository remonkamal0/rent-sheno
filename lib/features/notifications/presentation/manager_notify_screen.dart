import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/services/providers.dart';
import '../../../core/utils/localizations.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/sms_back_button.dart';

class ManagerNotifyScreen extends ConsumerStatefulWidget {
  final String? preSelectedTenantId;

  const ManagerNotifyScreen({
    super.key,
    this.preSelectedTenantId,
  });

  @override
  ConsumerState<ManagerNotifyScreen> createState() => _ManagerNotifyScreenState();
}

class _ManagerNotifyScreenState extends ConsumerState<ManagerNotifyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();

  String? _selectedTenant;
  String _selectedType = 'general'; // general, payment, maintenance
  bool _broadcastToAll = false;
  bool _isSending = false;

  final List<Map<String, String>> _typesList = const [
    {'id': 'general', 'name': 'General Announcement'},
    {'id': 'payment', 'name': 'Payment Alert / Dues Notice'},
    {'id': 'maintenance', 'name': 'Maintenance Visit / Update'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedTenant = widget.preSelectedTenantId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    if (!_formKey.currentState!.validate()) return;

    final tenantsState = ref.read(managerTenantsProvider);
    final List<String> targets = [];

    if (_broadcastToAll) {
      final tenants = tenantsState.value ?? [];
      if (tenants.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No tenants found to broadcast to!'), backgroundColor: AppColors.error),
        );
        return;
      }
      targets.addAll(tenants.map((t) => t.id));
    } else {
      if (_selectedTenant == null || _selectedTenant!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a target tenant!'), backgroundColor: AppColors.error),
        );
        return;
      }
      targets.add(_selectedTenant!);
    }

    setState(() => _isSending = true);
    try {
      final notifService = ref.read(notificationServiceProvider);

      // Send to all targeted tenants individually
      for (var targetId in targets) {
        await notifService.sendNotification(
          residentId: targetId,
          title: _titleController.text,
          message: _messageController.text,
          type: _selectedType,
        );
      }

      if (mounted) {
        ref.invalidate(notificationsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_broadcastToAll
                ? 'Broadcast message sent to ${targets.length} apartments successfully!'
                : 'Notification dispatched successfully!'),
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
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tenantsState = ref.watch(managerTenantsProvider);
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const SmsBackButton(),
        title: Text(localizations.translate('send_alert_to_apartment')),
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
                  'Dispatch Notification',
                  style: AppTextStyles.heading2.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Write a message and target it to a specific resident or broadcast it to everyone in the building. They will receive it in their app dashboard immediately.',
                  style: AppTextStyles.bodyMedium,
                ),
                const SizedBox(height: 24),

                // Broadcast Switch
                Row(
                  children: [
                    Switch(
                      value: _broadcastToAll,
                      activeColor: AppColors.primaryNavy,
                      onChanged: (val) {
                        setState(() => _broadcastToAll = val);
                      },
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Broadcast message to all apartments',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Select Tenant Dropdown (Visible only if not broadcasting)
                if (!_broadcastToAll) ...[
                  Text(
                    'TARGET TENANT / UNIT',
                    style: AppTextStyles.label.copyWith(color: AppColors.secondaryText, fontSize: 10),
                  ),
                  const SizedBox(height: 8),
                  tenantsState.when(
                    data: (tenants) {
                      // Ensure selected value is valid or fallback to first
                      final containsSelected = tenants.any((t) => t.id == _selectedTenant);
                      if (!containsSelected && tenants.isNotEmpty && _selectedTenant == null) {
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
                ],

                // Select Notification Type Dropdown
                Text(
                  'ALERT CATEGORY',
                  style: AppTextStyles.label.copyWith(color: AppColors.secondaryText, fontSize: 10),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedType,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  items: _typesList.map((t) {
                    return DropdownMenuItem<String>(
                      value: t['id'],
                      child: Text(t['name']!, style: AppTextStyles.bodyMedium),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedType = val);
                    }
                  },
                ),
                const SizedBox(height: 20),

                // Notification Title
                AppTextField(
                  label: 'Subject Title',
                  hint: 'e.g. Water Maintenance Tomorrow morning',
                  controller: _titleController,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter a title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Notification Message Body
                Text(
                  'MESSAGE BODY',
                  style: AppTextStyles.label.copyWith(color: AppColors.secondaryText, fontSize: 10),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _messageController,
                  maxLines: 5,
                  style: AppTextStyles.bodyMedium,
                  decoration: const InputDecoration(
                    hintText: 'Enter announcement details here...',
                    contentPadding: EdgeInsets.all(16),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter the message details';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                // Submit CTA
                AppPrimaryButton(
                  text: _broadcastToAll ? 'Broadcast Alert to All' : 'Dispatch Notification Alert',
                  isLoading: _isSending,
                  onTap: _handleSend,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
