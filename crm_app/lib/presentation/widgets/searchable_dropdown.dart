import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../data/models/company_model.dart';

/// An enhanced searchable dropdown widget with better UX:
/// - Loading state indicator
/// - Keyboard navigation support
/// - Highlighted matching text in results
/// - Improved empty state UI
/// - Optional leading widget support
/// - Debounced search
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
  final bool isLoading;
  final Widget? Function(T)? leadingBuilder;
  final Widget? Function(T, String)? highlightBuilder;

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
    this.isLoading = false,
    this.leadingBuilder,
    this.highlightBuilder,
  });

  @override
  State<SearchableDropdown<T>> createState() => _SearchableDropdownState<T>();
}

class _SearchableDropdownState<T> extends State<SearchableDropdown<T>> {
  final TextEditingController _controller = TextEditingController();
  final LayerLink _layerLink = LayerLink();
  final FocusNode _focusNode = FocusNode();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  OverlayEntry? _overlayEntry;
  List<T> _filteredItems = [];
  bool _isOpen = false;
  int _highlightedIndex = -1;
  String _searchText = '';

  // Debounce timer
  DateTime _lastSearchTime = DateTime.now();
  static const _debounceMs = 300;

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.items;
    _controller.text = widget.value != null
        ? widget.itemLabelBuilder(widget.value as T)
        : '';
    _controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(SearchableDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _controller.text = widget.value != null
          ? widget.itemLabelBuilder(widget.value as T)
          : '';
    }
    if (widget.items != oldWidget.items) {
      _filterItems(_searchText);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _onTextChanged() {
    final now = DateTime.now();
    final diff = now.difference(_lastSearchTime).inMilliseconds;

    if (diff >= _debounceMs) {
      _filterItems(_controller.text);
    }
  }

  void _filterItems(String searchText) {
    _searchText = searchText.toLowerCase();
    _lastSearchTime = DateTime.now();

    setState(() {
      _filteredItems = widget.items.where((item) {
        return widget
            .itemLabelBuilder(item)
            .toLowerCase()
            .contains(_searchText);
      }).toList();
      _highlightedIndex = _filteredItems.isNotEmpty ? 0 : -1;
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

    // Dropdown height is 250 (increased for better UX), add some buffer
    const dropdownHeight = 280.0;
    final offsetY = showAbove
        ? -(dropdownHeight + size.height + 4)
        : size.height + 4;

    _filterItems(_controller.text);

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
                borderRadius: BorderRadius.circular(16),
                color: widget.dropdownColor,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: widget.hintColor.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Search field in dropdown
                      _buildSearchField(),
                      // Results list
                      Flexible(child: _buildResultsList()),
                      // Add new option
                      if (widget.onAddNew != null) _buildAddNewOption(),
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
      _searchFocusNode.requestFocus();
    });
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: _handleKeyEvent,
        child: TextField(
          controller: _controller,
          focusNode: _searchFocusNode,
          style: TextStyle(color: widget.textColor),
          decoration: InputDecoration(
            hintText: 'Search...',
            hintStyle: TextStyle(color: widget.hintColor.withOpacity(0.6)),
            prefixIcon: widget.isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: widget.hintColor,
                      ),
                    ),
                  )
                : Icon(Icons.search, color: widget.hintColor),
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, color: widget.hintColor, size: 20),
                    onPressed: () {
                      _controller.clear();
                      _filterItems('');
                      _searchFocusNode.requestFocus();
                    },
                  )
                : null,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
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
              borderSide: BorderSide(color: widget.textColor, width: 2),
            ),
            filled: true,
            fillColor: widget.textColor.withOpacity(0.05),
          ),
          onChanged: _filterItems,
        ),
      ),
    );
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        if (_highlightedIndex < _filteredItems.length - 1) {
          _highlightedIndex++;
          _scrollToHighlighted();
        }
      });
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        if (_highlightedIndex > 0) {
          _highlightedIndex--;
          _scrollToHighlighted();
        }
      });
    } else if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (_highlightedIndex >= 0 && _highlightedIndex < _filteredItems.length) {
        _selectItem(_filteredItems[_highlightedIndex]);
      }
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      _removeOverlay();
    }
  }

  void _scrollToHighlighted() {
    if (_highlightedIndex >= 0 && _scrollController.hasClients) {
      final itemHeight = 72.0; // Approximate height of each item
      final targetOffset = _highlightedIndex * itemHeight;
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    }
  }

  Widget _buildResultsList() {
    if (_filteredItems.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: widget.hintColor.withOpacity(0.5),
            ),
            const SizedBox(height: 12),
            Text(
              _searchText.isEmpty
                  ? 'No items available'
                  : 'No results found for "$_searchText"',
              textAlign: TextAlign.center,
              style: TextStyle(color: widget.hintColor, fontSize: 14),
            ),
            if (_searchText.isNotEmpty && widget.onAddNew != null) ...[
              const SizedBox(height: 12),
              Text(
                'Press Enter or tap below to add new',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: widget.hintColor.withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 220),
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        itemCount: _filteredItems.length,
        itemBuilder: (context, index) {
          final item = _filteredItems[index];
          final isSelected = widget.value != null && widget.value == item;
          final isHighlighted = index == _highlightedIndex;

          return _buildItem(item, isSelected, isHighlighted);
        },
      ),
    );
  }

  Widget _buildItem(T item, bool isSelected, bool isHighlighted) {
    final label = widget.itemLabelBuilder(item);

    return InkWell(
      onTap: () => _selectItem(item),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isHighlighted
              ? widget.textColor.withOpacity(0.1)
              : (isSelected ? widget.textColor.withOpacity(0.08) : null),
          border: isHighlighted
              ? Border(left: BorderSide(color: widget.textColor, width: 3))
              : null,
        ),
        child: Row(
          children: [
            // Optional leading widget
            if (widget.leadingBuilder != null) ...[
              widget.leadingBuilder!(item) ?? const SizedBox.shrink(),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: widget.highlightBuilder != null
                  ? widget.highlightBuilder!(item, _searchText) != label
                        ? widget.highlightBuilder!(item, _searchText)!
                        : Text(
                            label,
                            style: TextStyle(
                              color: widget.textColor,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          )
                  : _buildHighlightedText(label),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: widget.textColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 14, color: Colors.white),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightedText(String text) {
    if (_searchText.isEmpty) {
      return Text(
        text,
        style: TextStyle(
          color: widget.textColor,
          fontWeight: FontWeight.normal,
        ),
      );
    }

    final lowerText = text.toLowerCase();
    final lowerSearch = _searchText.toLowerCase();
    final startIndex = lowerText.indexOf(lowerSearch);

    if (startIndex == -1) {
      return Text(
        text,
        style: TextStyle(
          color: widget.textColor,
          fontWeight: FontWeight.normal,
        ),
      );
    }

    final endIndex = startIndex + _searchText.length;

    return RichText(
      text: TextSpan(
        style: TextStyle(
          color: widget.textColor,
          fontWeight: FontWeight.normal,
        ),
        children: [
          TextSpan(text: text.substring(0, startIndex)),
          TextSpan(
            text: text.substring(startIndex, endIndex),
            style: TextStyle(
              color: widget.textColor,
              fontWeight: FontWeight.bold,
              backgroundColor: widget.textColor.withOpacity(0.2),
            ),
          ),
          TextSpan(text: text.substring(endIndex)),
        ],
      ),
    );
  }

  Widget _buildAddNewOption() {
    return Column(
      children: [
        Divider(height: 1, color: widget.hintColor.withOpacity(0.2)),
        InkWell(
          onTap: () {
            _removeOverlay();
            _controller.clear();
            widget.onAddNew?.call();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: widget.textColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.add_circle_outline,
                    size: 18,
                    color: widget.textColor,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Add New Company',
                  style: TextStyle(
                    color: widget.textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _selectItem(T item) {
    _controller.text = widget.itemLabelBuilder(item);
    widget.onChanged?.call(item);
    _removeOverlay();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    setState(() {
      _isOpen = false;
      _highlightedIndex = -1;
    });
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
                if (_controller.text.isNotEmpty && !widget.required)
                  IconButton(
                    icon: Icon(Icons.clear, color: widget.hintColor, size: 20),
                    onPressed: () {
                      _controller.clear();
                      widget.onChanged?.call(null);
                    },
                  ),
                AnimatedRotation(
                  turns: _isOpen ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    color: widget.hintColor,
                  ),
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
              borderSide: BorderSide(color: widget.textColor, width: 2),
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

/// A specialized dropdown for Company selection - simplified design:
/// - Company name prominently
/// - Location/country as optional secondary info
/// - Clean and user-friendly display
class CompanyDropdown extends StatelessWidget {
  final List<Company> companies;
  final String? value;
  final String hintText;
  final String labelText;
  final void Function(String?)? onChanged;
  final String? Function(String?)? validator;
  final Color dropdownColor;
  final Color textColor;
  final Color hintColor;
  final bool required;
  final VoidCallback? onAddNew;
  final bool isLoading;

  const CompanyDropdown({
    super.key,
    required this.companies,
    this.value,
    required this.hintText,
    required this.labelText,
    this.onChanged,
    this.validator,
    required this.dropdownColor,
    required this.textColor,
    required this.hintColor,
    this.required = false,
    this.onAddNew,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SearchableDropdown<String>(
      items: companies.map((c) => c.id).toList(),
      value: value,
      hintText: hintText,
      labelText: labelText,
      itemLabelBuilder: (id) {
        final company = companies.where((c) => c.id == id).firstOrNull;
        return company?.name ?? '';
      },
      onChanged: onChanged,
      validator: validator,
      dropdownColor: dropdownColor,
      textColor: textColor,
      hintColor: hintColor,
      required: required,
      onAddNew: onAddNew,
      isLoading: isLoading,
      leadingBuilder: (id) {
        final company = companies.where((c) => c.id == id).firstOrNull;
        if (company == null) return const SizedBox.shrink();

        return _CompanyAvatar(
          name: company.name,
          size: 36,
          backgroundColor: textColor.withOpacity(0.1),
          textColor: textColor,
        );
      },
      highlightBuilder: (id, searchText) {
        final company = companies.where((c) => c.id == id).firstOrNull;
        if (company == null) return const SizedBox.shrink();

        return _CompanyListTile(
          company: company,
          searchText: searchText,
          textColor: textColor,
        );
      },
    );
  }
}

/// Simple avatar widget for company
class _CompanyAvatar extends StatelessWidget {
  final String name;
  final double size;
  final Color backgroundColor;
  final Color textColor;

  const _CompanyAvatar({
    required this.name,
    required this.size,
    required this.backgroundColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final initials = _getInitials(name);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(size / 3),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: size / 2.5,
          ),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final words = name.trim().split(' ');
    if (words.isEmpty) return '';
    if (words.length == 1) {
      return words[0].substring(0, words[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }
}

/// Rich company list tile - simplified design showing only name + optional location
class _CompanyListTile extends StatelessWidget {
  final Company company;
  final String searchText;
  final Color textColor;

  const _CompanyListTile({
    required this.company,
    required this.searchText,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Company name with highlighted search
        _buildHighlightedName(),
        // Show location as subtle secondary info (only if exists)
        if (company.location != null || company.country != null) ...[
          const SizedBox(height: 2),
          Text(
            _getLocationString(),
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: textColor.withOpacity(0.5)),
          ),
        ],
      ],
    );
  }

  Widget _buildHighlightedName() {
    if (searchText.isEmpty) {
      return Text(
        company.name,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      );
    }

    final lowerName = company.name.toLowerCase();
    final lowerSearch = searchText.toLowerCase();
    final startIndex = lowerName.indexOf(lowerSearch);

    if (startIndex == -1) {
      return Text(
        company.name,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      );
    }

    final endIndex = startIndex + searchText.length;

    return RichText(
      text: TextSpan(
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        children: [
          TextSpan(text: company.name.substring(0, startIndex)),
          TextSpan(
            text: company.name.substring(startIndex, endIndex),
            style: TextStyle(backgroundColor: textColor.withOpacity(0.2)),
          ),
          TextSpan(text: company.name.substring(endIndex)),
        ],
      ),
    );
  }

  String _getLocationString() {
    if (company.location != null && company.country != null) {
      return '${company.location}, ${company.country}';
    }
    return company.location ?? company.country ?? '';
  }
}
