import 'package:flutter/material.dart';

import '../models/store.dart';
import '../service/store_service.dart';
import 'add_store_screen.dart';

class AdminStoresScreen extends StatefulWidget {
  const AdminStoresScreen({super.key});

  @override
  State<AdminStoresScreen> createState() => _AdminStoresScreenState();
}

class _AdminStoresScreenState extends State<AdminStoresScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<Store> _stores = [];

  bool _isLoading = true;
  bool _showInactive = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadStores();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStores() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final stores = await StoreService.getStores(includeInactive: true);

      if (!mounted) {
        return;
      }

      setState(() {
        _stores = stores;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to load stores: $error';
      });
    }
  }

  List<Store> get _filteredStores {
    final query = _searchController.text.trim().toLowerCase();

    final stores = _stores.where((store) {
      if (!_showInactive && !store.isActive) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      final searchableText = [
        store.name,
        store.chainName,
        store.storeName,
        store.address,
        store.city,
        store.province,
        store.postalCode,
        store.phone,
      ].join(' ').toLowerCase();

      return searchableText.contains(query);
    }).toList();

    stores.sort((first, second) {
      if (first.isActive != second.isActive) {
        return first.isActive ? -1 : 1;
      }

      final chainComparison = first.chainName.toLowerCase().compareTo(
        second.chainName.toLowerCase(),
      );

      if (chainComparison != 0) {
        return chainComparison;
      }

      final cityComparison = first.city.toLowerCase().compareTo(
        second.city.toLowerCase(),
      );

      if (cityComparison != 0) {
        return cityComparison;
      }

      return first.storeName.toLowerCase().compareTo(
        second.storeName.toLowerCase(),
      );
    });

    return stores;
  }

  Future<void> _openAddStore() async {
    final savedStore = await Navigator.push<Store>(
      context,
      MaterialPageRoute(builder: (_) => const AddStoreScreen()),
    );

    if (savedStore == null || !mounted) {
      return;
    }

    await _loadStores();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${savedStore.displayName} was added successfully.'),
      ),
    );
  }

  Future<void> _openEditStore(Store store) async {
    final updatedStore = await showDialog<Store>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EditStoreDialog(store: store),
    );

    if (updatedStore == null || !mounted) {
      return;
    }

    await _loadStores();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${updatedStore.displayName} was updated successfully.'),
      ),
    );
  }

  Future<void> _changeStoreStatus(Store store) async {
    final action = store.isActive ? 'deactivate' : 'activate';
    final actionTitle = store.isActive ? 'Deactivate Store' : 'Activate Store';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(actionTitle),
          content: Text(
            'Are you sure you want to $action '
            '${store.displayName}?\n\n'
            '${store.locationLabel}',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: Text(store.isActive ? 'Deactivate' : 'Activate'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await StoreService.setStoreActive(
        storeId: store.id,
        isActive: !store.isActive,
      );

      if (!mounted) {
        return;
      }

      await _loadStores();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${store.displayName} was '
            '${store.isActive ? 'deactivated' : 'activated'}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to change store status: $error'),
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  Widget _buildLoadingState() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Stores Could Not Be Loaded',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              _errorMessage ?? 'An unknown error occurred.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _loadStores,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final hasSearch = _searchController.text.trim().isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasSearch
                  ? Icons.search_off_outlined
                  : Icons.store_mall_directory_outlined,
              size: 72,
            ),
            const SizedBox(height: 16),
            Text(
              hasSearch ? 'No Matching Stores' : 'No Stores Yet',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              hasSearch
                  ? 'Try another store name, city, address, or postal code.'
                  : 'Add your first grocery store location.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (!hasSearch)
              FilledButton.icon(
                onPressed: _openAddStore,
                icon: const Icon(Icons.add_business_outlined),
                label: const Text('Add Store'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreCard(Store store) {
    final secondaryDetails = [
      store.address,
      store.locationLabel,
      store.postalCode,
    ].where((value) => value.trim().isNotEmpty).toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Opacity(
        opacity: store.isActive ? 1 : 0.65,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                child: Icon(
                  store.isActive ? Icons.storefront_outlined : Icons.storefront,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            store.displayName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StoreStatusChip(isActive: store.isActive),
                      ],
                    ),
                    if (store.chainName.trim().isNotEmpty &&
                        store.chainName.trim() != store.displayName.trim()) ...[
                      const SizedBox(height: 3),
                      Text(
                        store.chainName,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                    if (secondaryDetails.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(secondaryDetails.join('\n')),
                    ],
                    if (store.phone.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.phone_outlined, size: 17),
                          const SizedBox(width: 6),
                          Expanded(child: Text(store.phone)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Store actions',
                onSelected: (value) {
                  if (value == 'edit') {
                    _openEditStore(store);
                  } else if (value == 'status') {
                    _changeStoreStatus(store);
                  }
                },
                itemBuilder: (_) {
                  return [
                    const PopupMenuItem<String>(
                      value: 'edit',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Edit Store'),
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'status',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          store.isActive
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        title: Text(
                          store.isActive
                              ? 'Deactivate Store'
                              : 'Activate Store',
                        ),
                      ),
                    ),
                  ];
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStoreList() {
    final stores = _filteredStores;

    if (stores.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadStores,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: stores.length,
        itemBuilder: (_, index) {
          return _buildStoreCard(stores[index]);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _stores.where((store) => store.isActive).length;
    final inactiveCount = _stores.length - activeCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Store Management'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadStores,
            tooltip: 'Refresh stores',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddStore,
        icon: const Icon(Icons.add),
        label: const Text('Add Store'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (_) {
                setState(() {});
              },
              decoration: InputDecoration(
                labelText: 'Search stores',
                hintText: 'Name, city, address, or postal code',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.clear),
                      ),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '$activeCount active'
                    '${inactiveCount > 0 ? ' • $inactiveCount inactive' : ''}',
                  ),
                ),
                const Text('Show inactive'),
                Switch(
                  value: _showInactive,
                  onChanged: (value) {
                    setState(() {
                      _showInactive = value;
                    });
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _errorMessage != null
                ? _buildErrorState()
                : _buildStoreList(),
          ),
        ],
      ),
    );
  }
}

class _StoreStatusChip extends StatelessWidget {
  final bool isActive;

  const _StoreStatusChip({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(
        isActive ? Icons.check_circle_outline : Icons.pause_circle_outline,
        size: 17,
      ),
      label: Text(isActive ? 'Active' : 'Inactive'),
    );
  }
}

class _EditStoreDialog extends StatefulWidget {
  final Store store;

  const _EditStoreDialog({required this.store});

  @override
  State<_EditStoreDialog> createState() => _EditStoreDialogState();
}

class _EditStoreDialogState extends State<_EditStoreDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _chainNameController;
  late final TextEditingController _storeNameController;
  late final TextEditingController _addressController;
  late final TextEditingController _cityController;
  late final TextEditingController _postalCodeController;
  late final TextEditingController _phoneController;

  late String _selectedProvince;
  bool _isSaving = false;

  static const List<String> _provinces = [
    'AB',
    'BC',
    'MB',
    'NB',
    'NL',
    'NS',
    'NT',
    'NU',
    'ON',
    'PE',
    'QC',
    'SK',
    'YT',
  ];

  @override
  void initState() {
    super.initState();

    _chainNameController = TextEditingController(text: widget.store.chainName);

    _storeNameController = TextEditingController(text: widget.store.storeName);

    _addressController = TextEditingController(text: widget.store.address);

    _cityController = TextEditingController(text: widget.store.city);

    _postalCodeController = TextEditingController(
      text: widget.store.postalCode,
    );

    _phoneController = TextEditingController(text: widget.store.phone);

    _selectedProvince = _provinces.contains(widget.store.province)
        ? widget.store.province
        : 'ON';
  }

  @override
  void dispose() {
    _chainNameController.dispose();
    _storeNameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String? _requiredValidator(String? value, String message) {
    if (value == null || value.trim().isEmpty) {
      return message;
    }

    return null;
  }

  String? _postalCodeValidator(String? value) {
    final postalCode = value?.trim() ?? '';

    if (postalCode.isEmpty) {
      return null;
    }

    final normalized = postalCode.toUpperCase().replaceAll(
      RegExp(r'[^A-Z0-9]'),
      '',
    );

    final pattern = RegExp(
      r'^[ABCEGHJ-NPRSTVXY]\d[ABCEGHJ-NPRSTVWXYZ]\d'
      r'[ABCEGHJ-NPRSTVWXYZ]\d$',
    );

    if (!pattern.hasMatch(normalized)) {
      return 'Enter a valid Canadian postal code.';
    }

    return null;
  }

  String _normalizePostalCode(String value) {
    final normalized = value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

    if (normalized.length <= 3) {
      return normalized;
    }

    final limited = normalized.length > 6
        ? normalized.substring(0, 6)
        : normalized;

    return '${limited.substring(0, 3)} ${limited.substring(3)}';
  }

  Future<void> _saveChanges() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final chainName = _chainNameController.text.trim();
      final storeName = _storeNameController.text.trim();

      final updatedStore = Store(
        id: widget.store.id,
        name: chainName,
        chainName: chainName,
        storeName: storeName,
        address: _addressController.text.trim(),
        city: _cityController.text.trim(),
        province: _selectedProvince,
        postalCode: _normalizePostalCode(_postalCodeController.text),
        phone: _phoneController.text.trim(),
        latitude: widget.store.latitude,
        longitude: widget.store.longitude,
        isActive: widget.store.isActive,
        createdAt: widget.store.createdAt,
      );

      final savedStore = await StoreService.updateStore(updatedStore);

      if (!mounted) {
        return;
      }

      Navigator.pop(context, savedStore);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to update store: $error'),
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Store'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _chainNameController,
                  enabled: !_isSaving,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Chain Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    return _requiredValidator(value, 'Enter the chain name.');
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _storeNameController,
                  enabled: !_isSaving,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Store or Location Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    return _requiredValidator(
                      value,
                      'Enter the store or location name.',
                    );
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _addressController,
                  enabled: !_isSaving,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Street Address',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    return _requiredValidator(
                      value,
                      'Enter the street address.',
                    );
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _cityController,
                  enabled: !_isSaving,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'City',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    return _requiredValidator(value, 'Enter the city.');
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _selectedProvince,
                  decoration: const InputDecoration(
                    labelText: 'Province or Territory',
                    border: OutlineInputBorder(),
                  ),
                  items: _provinces.map((province) {
                    return DropdownMenuItem<String>(
                      value: province,
                      child: Text(province),
                    );
                  }).toList(),
                  onChanged: _isSaving
                      ? null
                      : (value) {
                          if (value == null) {
                            return;
                          }

                          setState(() {
                            _selectedProvince = value;
                          });
                        },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _postalCodeController,
                  enabled: !_isSaving,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Postal Code',
                    border: OutlineInputBorder(),
                  ),
                  validator: _postalCodeValidator,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phoneController,
                  enabled: !_isSaving,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    helperText: 'Optional',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving
              ? null
              : () {
                  Navigator.pop(context);
                },
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _isSaving ? null : _saveChanges,
          icon: _isSaving
              ? const SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
        ),
      ],
    );
  }
}
