import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/services/maintenance_service.dart';
import '../../../core/services/providers.dart';
import '../../../core/utils/localizations.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/sms_back_button.dart';
import '../../../core/widgets/skeleton_loading.dart';
import '../../../core/widgets/empty_state.dart';

class ManagerMaintenanceScreen extends ConsumerStatefulWidget {
  const ManagerMaintenanceScreen({super.key});

  @override
  ConsumerState<ManagerMaintenanceScreen> createState() =>
      _ManagerMaintenanceScreenState();
}

class _ManagerMaintenanceScreenState
    extends ConsumerState<ManagerMaintenanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedUnit = 'All';
  String _selectedResident = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  bool get _hasActiveFilters =>
      _searchQuery.isNotEmpty ||
      _selectedUnit != 'All' ||
      _selectedResident != 'All';

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedUnit = 'All';
      _selectedResident = 'All';
    });
  }

  bool _matchesFilter(MaintenanceRequest req) {
    final unit = req.unitNumber ?? req.unitId;
    final resident = req.residentName ?? '';

    // Unit filter
    if (_selectedUnit != 'All' && unit != _selectedUnit) {
      return false;
    }

    // Resident filter
    if (_selectedResident != 'All' && resident != _selectedResident) {
      return false;
    }

    // Search query
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      final title = req.title.toLowerCase();
      final description = req.description.toLowerCase();
      final reqNum = req.requestNumber.toLowerCase();
      final unitLower = unit.toLowerCase();
      final residentLower = resident.toLowerCase();

      final matches = unitLower.contains(q) ||
          residentLower.contains(q) ||
          title.contains(q) ||
          description.contains(q) ||
          reqNum.contains(q);

      if (!matches) return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final requestsState = ref.watch(managerMaintenanceProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const SmsBackButton(),
        title: Text(localizations.translate('maintenance_management')),
        actions: [
          if (_hasActiveFilters)
            IconButton(
              icon: const Icon(LucideIcons.filterX, size: 20),
              tooltip: localizations.translate('clear_filters'),
              onPressed: _clearFilters,
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryNavy,
          unselectedLabelColor: AppColors.secondaryText,
          indicatorColor: AppColors.primaryNavy,
          indicatorSize: TabBarIndicatorSize.tab,
          tabs: [
            Tab(text: localizations.text('Active Issues')),
            Tab(text: localizations.text('Closed / History')),
          ],
        ),
      ),
      body: SafeArea(
        child: requestsState.when(
          data: (requests) {
            // Extract distinct units and resident names from the loaded requests
            final units = requests
                .map((r) => r.unitNumber ?? r.unitId)
                .where((u) => u.isNotEmpty)
                .toSet()
                .toList()
              ..sort();

            final residents = requests
                .map((r) => r.residentName)
                .whereType<String>()
                .where((name) => name.trim().isNotEmpty)
                .toSet()
                .toList()
              ..sort();

            final activeAll = requests
                .where((r) => r.status != 'closed' && r.status != 'cancelled')
                .toList();
            final closedAll = requests
                .where((r) => r.status == 'closed' || r.status == 'cancelled')
                .toList();

            final filteredActive = activeAll.where(_matchesFilter).toList();
            final filteredClosed = closedAll.where(_matchesFilter).toList();

            return Column(
              children: [
                // Filter and Search Header
                Container(
                  color: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    children: [
                      // Search Input
                      TextField(
                        controller: _searchController,
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val.trim();
                          });
                        },
                        decoration: InputDecoration(
                          hintText: localizations
                              .translate('search_maintenance_hint'),
                          hintStyle: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.secondaryText,
                          ),
                          prefixIcon: const Icon(
                            LucideIcons.search,
                            size: 18,
                            color: AppColors.secondaryText,
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    LucideIcons.x,
                                    size: 18,
                                    color: AppColors.secondaryText,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _searchController.clear();
                                      _searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: AppColors.border,
                              width: 0.8,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: AppColors.primaryNavy,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Dropdown Filters Row
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            // Unit Filter Dropdown
                            _buildDropdown(
                              icon: LucideIcons.home,
                              label: localizations.translate('unit'),
                              value: _selectedUnit,
                              items: ['All', ...units],
                              itemLabel: (val) => val == 'All'
                                  ? localizations.translate('all_units')
                                  : val,
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedUnit = val);
                                }
                              },
                            ),
                            const SizedBox(width: 10),

                            // Resident Filter Dropdown
                            _buildDropdown(
                              icon: LucideIcons.user,
                              label: localizations.translate('resident'),
                              value: _selectedResident,
                              items: ['All', ...residents],
                              itemLabel: (val) => val == 'All'
                                  ? localizations.translate('all_residents')
                                  : val,
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedResident = val);
                                }
                              },
                            ),

                            // Reset filter button if active
                            if (_hasActiveFilters) ...[
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: _clearFilters,
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.lightBlue,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: AppColors.primaryNavy
                                          .withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        LucideIcons.x,
                                        size: 14,
                                        color: AppColors.primaryNavy,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        localizations
                                            .translate('clear_filters'),
                                        style:
                                            AppTextStyles.bodySmall.copyWith(
                                          color: AppColors.primaryNavy,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.border),

                // Tab Content
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async =>
                        ref.invalidate(managerMaintenanceProvider),
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildRequestsList(
                          context,
                          list: filteredActive,
                          totalCount: activeAll.length,
                          emptyMsg: localizations.text(
                            'No active maintenance issues! All systems running smoothly.',
                          ),
                        ),
                        _buildRequestsList(
                          context,
                          list: filteredClosed,
                          totalCount: closedAll.length,
                          emptyMsg: localizations.text(
                            'No maintenance history records found.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
          loading: () => ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: 4,
            itemBuilder: (context, index) => const SkeletonCard(),
          ),
          error: (err, _) =>
              Center(child: Text(localizations.translate('error_loading'))),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required IconData icon,
    required String label,
    required String value,
    required List<String> items,
    required String Function(String) itemLabel,
    required ValueChanged<String?> onChanged,
  }) {
    // If the selected value isn't in items, fallback to 'All'
    final safeValue = items.contains(value) ? value : 'All';
    final isFiltered = safeValue != 'All';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isFiltered ? AppColors.lightBlue : AppColors.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isFiltered ? AppColors.primaryNavy : AppColors.border,
          width: isFiltered ? 1.2 : 0.8,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: safeValue,
          icon: const Icon(
            LucideIcons.chevronDown,
            size: 14,
            color: AppColors.primaryNavy,
          ),
          isDense: true,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.primaryNavy,
            fontWeight: isFiltered ? FontWeight.bold : FontWeight.w500,
          ),
          onChanged: onChanged,
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 13,
                    color: isFiltered
                        ? AppColors.primaryNavy
                        : AppColors.secondaryText,
                  ),
                  const SizedBox(width: 6),
                  Text(itemLabel(item)),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildRequestsList(
    BuildContext context, {
    required List<MaintenanceRequest> list,
    required int totalCount,
    required String emptyMsg,
  }) {
    final localizations = AppLocalizations.of(context);

    if (list.isEmpty) {
      if (totalCount > 0 && _hasActiveFilters) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: EmptyState(
              icon: LucideIcons.searchX,
              title: localizations.translate('no_matching_requests'),
              description: localizations.translate('try_adjusting_filters'),
              actionText: localizations.translate('clear_filters'),
              onActionTap: _clearFilters,
            ),
          ),
        );
      }
      return EmptyState(
        icon: LucideIcons.wrench,
        title: localizations.text('All Clear'),
        description: emptyMsg,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final req = list[index];
        IconData categoryIcon;
        switch (req.category) {
          case 'plumbing':
            categoryIcon = LucideIcons.droplet;
            break;
          case 'electrical':
            categoryIcon = LucideIcons.zap;
            break;
          case 'appliance':
            categoryIcon = LucideIcons.tv;
            break;
          default:
            categoryIcon = LucideIcons.helpCircle;
        }

        final unitText = req.unitNumber ?? 'Unit ${req.unitId.toUpperCase()}';
        final residentText = req.residentName;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.border, width: 0.5),
          ),
          child: InkWell(
            onTap: () async {
              await context.push('/manager/maintenance/${req.id}');
              ref.invalidate(managerMaintenanceProvider);
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: AppColors.lightBlue,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      categoryIcon,
                      color: AppColors.primaryNavy,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          req.title,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryNavy,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            // Unit Badge / Label
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  LucideIcons.home,
                                  size: 13,
                                  color: AppColors.secondaryText,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  unitText,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryNavy,
                                  ),
                                ),
                              ],
                            ),

                            // Resident Badge / Label
                            if (residentText != null &&
                                residentText.trim().isNotEmpty) ...[
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    LucideIcons.user,
                                    size: 13,
                                    color: AppColors.secondaryText,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    residentText,
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.secondaryText,
                                    ),
                                  ),
                                ],
                              ),
                            ],

                            // Request Number
                            Text(
                              '• ${req.requestNumber}',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusBadge(status: req.status),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

