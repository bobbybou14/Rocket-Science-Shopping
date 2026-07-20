import 'package:flutter/material.dart';

class CartSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const CartSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  @override
  State<CartSearchBar> createState() => _CartSearchBarState();
}

class _CartSearchBarState extends State<CartSearchBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_updateClearButton);
  }

  @override
  void didUpdateWidget(CartSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_updateClearButton);
      widget.controller.addListener(_updateClearButton);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateClearButton);
    super.dispose();
  }

  void _updateClearButton() {
    if (mounted) {
      setState(() {});
    }
  }

  void _clearSearch() {
    widget.controller.clear();
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        12,
        16,
        8,
      ),
      child: TextField(
        controller: widget.controller,
        onChanged: widget.onChanged,
         textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search cart...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: widget.controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.clear),
                  onPressed: _clearSearch,
                ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}