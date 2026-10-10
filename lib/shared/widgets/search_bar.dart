import 'package:flutter/material.dart';

class AppSearchBar extends StatefulWidget {
  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  
  const AppSearchBar({
    super.key,
    this.controller,
    this.hintText = 'Search...',
    this.onChanged,
    this.onClear,
  });

  @override
  State<AppSearchBar> createState() => _AppSearchBarState();
}

class _AppSearchBarState extends State<AppSearchBar> {
  late TextEditingController _controller;
  bool _showClear = false;
  
  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _controller.addListener(_updateClearButton);
    _showClear = _controller.text.isNotEmpty;
  }
  
  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }
  
  void _updateClearButton() {
    setState(() {
      _showClear = _controller.text.isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        hintText: widget.hintText,
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        suffixIcon: _showClear
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _controller.clear();
                  widget.onChanged?.call('');
                  widget.onClear?.call();
                },
              )
            : null,
        // Matches the 48px height of the buttons it usually sits beside.
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }
}