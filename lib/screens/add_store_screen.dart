import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/store.dart';
import '../service/store_service.dart';

class AddStoreScreen extends StatefulWidget {
  const AddStoreScreen({super.key});

  @override
  State<AddStoreScreen> createState() => _AddStoreScreenState();
}

class _AddStoreScreenState extends State<AddStoreScreen> {
  final _formKey = GlobalKey<FormState>();

  final _chainNameController = TextEditingController();
  final _storeNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _phoneController = TextEditingController();

  String? _selectedProvince;
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
  void dispose() {
    _chainNameController.dispose();
    _storeNameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String _normalizePostalCode(String value) {
    final characters = value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

    if (characters.length <= 3) {
      return characters;
    }

    return '${characters.substring(0, 3)} '
        '${characters.substring(3, characters.length.clamp(3, 6))}';
  }

  String? _validatePostalCode(String? value) {
    final postalCode = value?.trim() ?? '';

    if (postalCode.isEmpty) {
      return null;
    }

    final normalized = postalCode.toUpperCase().replaceAll(RegExp(r'\s+'), '');

    final postalCodePattern = RegExp(
      r'^[ABCEGHJ-NPRSTVXY]\d[ABCEGHJ-NPRSTVWXYZ]\d'
      r'[ABCEGHJ-NPRSTVWXYZ]\d$',
    );

    if (!postalCodePattern.hasMatch(normalized)) {
      return 'Enter a valid Canadian postal code.';
    }

    return null;
  }

  String? _validatePhone(String? value) {
    final phone = value?.trim() ?? '';

    if (phone.isEmpty) {
      return null;
    }

    final digits = phone.replaceAll(RegExp(r'\D'), '');

    if (digits.length != 10 && digits.length != 11) {
      return 'Enter a valid phone number.';
    }

    return null;
  }

  void _copyChainNameToStoreName() {
    if (_storeNameController.text.trim().isEmpty) {
      _storeNameController.text = _chainNameController.text.trim();
    }
  }

  Future<void> _saveStore() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final chainName = _chainNameController.text.trim();
      final locationName = _storeNameController.text.trim();
      final address = _addressController.text.trim();
      final city = _cityController.text.trim();
      final province = _selectedProvince!;
      final postalCode = _normalizePostalCode(_postalCodeController.text);
      final phone = _phoneController.text.trim();

      final store = Store(
        id: '',
        name: chainName,
        chainName: chainName,
        storeName: locationName,
        address: address,
        city: city,
        province: province,
        postalCode: postalCode,
        phone: phone,
        latitude: null,
        longitude: null,
        isActive: true,
        createdAt: null,
      );

      final savedStore = await StoreService.saveStore(store);

      if (!mounted) {
        return;
      }

      Navigator.pop(context, savedStore);
    } on StateError catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message.toString()),
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to add store: $error'),
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Store')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              const Icon(Icons.add_business_outlined, size: 72),
              const SizedBox(height: 16),
              const Text(
                'Add a Grocery Store',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter the store and location details so receipts can be '
                'linked to the correct branch.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              TextFormField(
                controller: _chainNameController,
                enabled: !_isSaving,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Chain Name',
                  hintText: 'Example: Walmart',
                  helperText: 'The main company or grocery banner.',
                  prefixIcon: Icon(Icons.storefront_outlined),
                  border: OutlineInputBorder(),
                ),
                onEditingComplete: () {
                  _copyChainNameToStoreName();
                  FocusScope.of(context).nextFocus();
                },
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter the chain name.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _storeNameController,
                enabled: !_isSaving,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Store or Location Name',
                  hintText: 'Example: Walmart Supercentre',
                  helperText:
                      'Use the branch name shown on the receipt or storefront.',
                  prefixIcon: Icon(Icons.business_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter the store or location name.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                enabled: !_isSaving,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.streetAddressLine1],
                decoration: const InputDecoration(
                  labelText: 'Street Address',
                  hintText: 'Example: 330 Clarke Road',
                  prefixIcon: Icon(Icons.location_on_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter the street address.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _cityController,
                enabled: !_isSaving,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.addressCity],
                decoration: const InputDecoration(
                  labelText: 'City',
                  hintText: 'Example: London',
                  prefixIcon: Icon(Icons.location_city_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter the city.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedProvince,
                decoration: const InputDecoration(
                  labelText: 'Province or Territory',
                  prefixIcon: Icon(Icons.map_outlined),
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
                        setState(() {
                          _selectedProvince = value;
                        });
                      },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Select a province or territory.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _postalCodeController,
                enabled: !_isSaving,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.postalCode],
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9 ]')),
                  LengthLimitingTextInputFormatter(7),
                  _CanadianPostalCodeFormatter(),
                ],
                decoration: const InputDecoration(
                  labelText: 'Postal Code',
                  hintText: 'Example: N5W 6G4',
                  prefixIcon: Icon(Icons.markunread_mailbox_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: _validatePostalCode,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                enabled: !_isSaving,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.telephoneNumber],
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-(). ]')),
                  LengthLimitingTextInputFormatter(20),
                ],
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  hintText: 'Example: (519) 555-1234',
                  helperText: 'Optional',
                  prefixIcon: Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: _validatePhone,
                onFieldSubmitted: (_) {
                  if (!_isSaving) {
                    _saveStore();
                  }
                },
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: _isSaving ? null : _saveStore,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_isSaving ? 'Saving Store...' : 'Save Store'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _isSaving
                    ? null
                    : () {
                        Navigator.pop(context);
                      },
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CanadianPostalCodeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final characters = newValue.text.toUpperCase().replaceAll(
      RegExp(r'[^A-Z0-9]'),
      '',
    );

    final limitedCharacters = characters.length > 6
        ? characters.substring(0, 6)
        : characters;

    final formattedValue = limitedCharacters.length > 3
        ? '${limitedCharacters.substring(0, 3)} '
              '${limitedCharacters.substring(3)}'
        : limitedCharacters;

    return TextEditingValue(
      text: formattedValue,
      selection: TextSelection.collapsed(offset: formattedValue.length),
    );
  }
}
