import 'package:flutter/material.dart';

/// A searchable dropdown widget that allows typing to filter options
class SearchableDropdown<T> extends StatefulWidget {
  final List<T> items;
  final T? value;
  final String hintText;
  final String labelText;
  final String Function(T) itemLabelBuilder;
  final void Function(T?)? onChanged;
  final String? Function(String?)? validator;
  final Color dropdownColor;
  final Color textColor;
  final Color hintColor;
  final bool required;
  final VoidCallback? onAddNew;

  const SearchableDropdown({
    super.key,
    required this.items,
    this.value,
    required this.hintText,
    required this.labelText,
    required this.itemLabelBuilder,
    this.onChanged,
    this.validator,
    required this.dropdownColor,
    required this.textColor,
    required this.hintColor,
    this.required = false,
    this.onAddNew,
  });

  @override
  State<SearchableDropdown<T>> createState() => _SearchableDropdownState<T>();
}

class _SearchableDropdownState<T> extends State<SearchableDropdown<T>> {
  final TextEditingController _controller = TextEditingController();
  final LayerLink _layerLink = LayerLink();
  final FocusNode _focusNode = FocusNode();
  OverlayEntry? _overlayEntry;
  List<T> _filteredItems = [];
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.items;
    _controller.text = widget.value != null
        ? widget.itemLabelBuilder(widget.value!)
        : '';
    _controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(SearchableDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _controller.text = widget.value != null
          ? widget.itemLabelBuilder(widget.value!)
          : '';
    }
    if (widget.items != oldWidget.items) {
      _filteredItems = widget.items;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _onTextChanged() {
    final searchText = _controller.text.toLowerCase();
    setState(() {
      _filteredItems = widget.items.where((item) {
        return widget.itemLabelBuilder(item).toLowerCase().contains(searchText);
      }).toList();
    });
  }

  void _toggleDropdown() {
    if (_isOpen) {
      _removeOverlay();
    } else {
      _showOverlay();
    }
  }

  void _showOverlay() {
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    // Calculate available space below and above the dropdown
    final screenHeight = MediaQuery.of(context).size.height;
    final globalPosition = renderBox.localToGlobal(Offset.zero);
    final bottomSpace = screenHeight - globalPosition.dy - size.height;
    final topSpace = globalPosition.dy;

    // Check if there's enough space below (at least 200px) or if there's more space above
    final showAbove = bottomSpace < 220 && topSpace > bottomSpace;

    // Dropdown height is 200, add some buffer
    final dropdownHeight = 200.0;
    final offsetY = showAbove
        ? -(dropdownHeight + size.height + 4)
        : size.height + 4;

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Transparent barrier to detect taps outside
          Positioned.fill(
            child: GestureDetector(
              onTap: _removeOverlay,
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.transparent),
            ),
          ),
          // Dropdown content
          Positioned(
            width: size.width,
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: Offset(0, offsetY),
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                color: widget.dropdownColor,
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: widget.hintColor.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Search field in dropdown
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: TextField(
                          autofocus: true,
                          style: TextStyle(color: widget.textColor),
                          decoration: InputDecoration(
                            hintText: 'Search...',
                            hintStyle: TextStyle(color: widget.hintColor),
                            prefixIcon: Icon(
                              Icons.search,
                              color: widget.hintColor,
                            ),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: widget.hintColor.withOpacity(0.3),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: widget.hintColor.withOpacity(0.3),
                              ),
                            ),
                            filled: true,
                            fillColor: widget.textColor.withOpacity(0.05),
                          ),
                          onChanged: (value) {
                            final searchText = value.toLowerCase();
                            setState(() {
                              _filteredItems = widget.items.where((item) {
                                return widget
                                    .itemLabelBuilder(item)
                                    .toLowerCase()
                                    .contains(searchText);
                              }).toList();
                            });
                          },
                        ),
                      ),
                      // Results list
                      Flexible(
                        child: ListView(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          children: _filteredItems.map((item) {
                            final isSelected =
                                widget.value != null && widget.value == item;
                            return InkWell(
                              onTap: () {
                                _controller.text = widget.itemLabelBuilder(
                                  item,
                                );
                                widget.onChanged?.call(item);
                                _removeOverlay();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                color: isSelected
                                    ? widget.textColor.withOpacity(0.1)
                                    : null,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        widget.itemLabelBuilder(item),
                                        style: TextStyle(
                                          color: widget.textColor,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      Icon(
                                        Icons.check,
                                        size: 18,
                                        color: widget.textColor,
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      // Add new option
                      if (widget.onAddNew != null)
                        Divider(
                          height: 1,
                          color: widget.hintColor.withOpacity(0.2),
                        ),
                      if (widget.onAddNew != null)
                        InkWell(
                          onTap: () {
                            _removeOverlay();
                            _controller.clear();
                            widget.onAddNew?.call();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.add_circle_outline,
                                  size: 20,
                                  color: widget.textColor,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Add New Company',
                                  style: TextStyle(
                                    color: widget.textColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (_filteredItems.isEmpty && widget.onAddNew == null)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'No results found',
                            style: TextStyle(color: widget.hintColor),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _isOpen = true);

    // Request focus after the overlay is shown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    setState(() => _isOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: _toggleDropdown,
        child: TextFormField(
          controller: _controller,
          focusNode: _focusNode,
          readOnly: true,
          style: TextStyle(color: widget.textColor),
          decoration: InputDecoration(
            labelText: widget.labelText,
            labelStyle: TextStyle(color: widget.hintColor),
            hintText: widget.hintText,
            hintStyle: TextStyle(color: widget.hintColor.withOpacity(0.6)),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_controller.text.isNotEmpty)
                  IconButton(
                    icon: Icon(Icons.clear, color: widget.hintColor, size: 20),
                    onPressed: () {
                      _controller.clear();
                      widget.onChanged?.call(null);
                    },
                  ),
                Icon(
                  _isOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                  color: widget.hintColor,
                ),
              ],
            ),
            filled: true,
            fillColor: widget.dropdownColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: widget.hintColor.withOpacity(0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: widget.hintColor.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: widget.textColor),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          validator: widget.validator,
          onTap: _toggleDropdown,
        ),
      ),
    );
  }
}
