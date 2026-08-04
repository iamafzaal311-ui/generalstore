import 'package:flutter/material.dart';

class SearchableAutocompleteField<T> extends StatefulWidget {
  final String labelText;
  final String? hintText;
  final T? initialValue;
  final List<T> items;
  final String Function(T) itemAsString;
  final String? Function(T)? itemSubtitle;
  final Widget Function(T)? itemTrailing;
  final bool Function(T item, String query)? filterFn;
  final ValueChanged<T?> onSelected;
  final Widget? prefixIcon;
  final Widget? suffixAction;
  final bool enabled;
  final String? Function(String?)? validator;

  const SearchableAutocompleteField({
    super.key,
    required this.labelText,
    this.hintText,
    this.initialValue,
    required this.items,
    required this.itemAsString,
    this.itemSubtitle,
    this.itemTrailing,
    this.filterFn,
    required this.onSelected,
    this.prefixIcon,
    this.suffixAction,
    this.enabled = true,
    this.validator,
  });

  @override
  State<SearchableAutocompleteField<T>> createState() =>
      _SearchableAutocompleteFieldState<T>();
}

class _SearchableAutocompleteFieldState<T>
    extends State<SearchableAutocompleteField<T>> {
  final LayerLink _layerLink = LayerLink();
  final FocusNode _focusNode = FocusNode();
  final TextEditingController _controller = TextEditingController();
  OverlayEntry? _overlayEntry;
  T? _selectedItem;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedItem = widget.initialValue;
    if (_selectedItem != null) {
      _controller.text = widget.itemAsString(_selectedItem as T);
    }

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        _showOverlay();
      } else {
        _hideOverlay();
      }
    });
  }

  @override
  void didUpdateWidget(covariant SearchableAutocompleteField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue) {
      _selectedItem = widget.initialValue;
      if (_selectedItem != null) {
        _controller.text = widget.itemAsString(_selectedItem as T);
      } else {
        _controller.clear();
      }
    }
  }

  @override
  void dispose() {
    _hideOverlay();
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  List<T> get _filteredItems {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return widget.items;

    return widget.items.where((item) {
      if (widget.filterFn != null) {
        return widget.filterFn!(item, query);
      }
      final title = widget.itemAsString(item).toLowerCase();
      final sub = widget.itemSubtitle?.call(item);
      final subtitle = sub != null ? sub.toLowerCase() : '';
      return title.contains(query) || subtitle.contains(query);
    }).toList();
  }

  void _showOverlay() {
    _hideOverlay();
    if (!mounted) return;

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final size = renderBox.size;
    final theme = Theme.of(context);

    _overlayEntry = OverlayEntry(
      builder: (context) {
        final items = _filteredItems;
        return Positioned(
          width: size.width,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: Offset(0, size.height + 4),
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(10),
              color: theme.cardColor,
              shadowColor: Colors.black26,
              child: Container(
                constraints: const BoxConstraints(maxHeight: 240),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: theme.dividerColor.withOpacity(0.4),
                  ),
                ),
                child: items.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'No matching items found',
                          style: TextStyle(
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: items.length,
                        separatorBuilder: (context, index) => Divider(
                          height: 1,
                          thickness: 0.5,
                          color: theme.dividerColor.withOpacity(0.3),
                        ),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final title = widget.itemAsString(item);
                          final subtitle = widget.itemSubtitle?.call(item);
                          final trailing = widget.itemTrailing?.call(item);
                          final isSelected = item == _selectedItem;

                          return ListTile(
                            dense: true,
                            selected: isSelected,
                            selectedTileColor: theme.colorScheme.primary
                                .withOpacity(0.08),
                            title: Text(
                              title,
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : null,
                              ),
                            ),
                            subtitle: subtitle != null
                                ? Text(
                                    subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12),
                                  )
                                : null,
                            trailing: trailing,
                            onTap: () {
                              setState(() {
                                _selectedItem = item;
                                _controller.text = title;
                                _searchQuery = '';
                              });
                              widget.onSelected(item);
                              _focusNode.unfocus();
                              _hideOverlay();
                            },
                          );
                        },
                      ),
              ),
            ),
          ),
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _clearSelection() {
    setState(() {
      _selectedItem = null;
      _controller.clear();
      _searchQuery = '';
    });
    widget.onSelected(null);
    if (_focusNode.hasFocus) {
      _showOverlay();
    }
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextFormField(
              controller: _controller,
              focusNode: _focusNode,
              enabled: widget.enabled,
              decoration: InputDecoration(
                labelText: widget.labelText,
                hintText: widget.hintText ?? 'Type to search...',
                isDense: true,
                prefixIcon: widget.prefixIcon ?? const Icon(Icons.search, size: 20),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_controller.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: _clearSelection,
                      ),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                  _selectedItem = null;
                });
                widget.onSelected(null);
                if (!_focusNode.hasFocus) {
                  _focusNode.requestFocus();
                } else {
                  _showOverlay();
                }
              },
              validator: widget.validator,
            ),
          ),
          if (widget.suffixAction != null) ...[
            const SizedBox(width: 6),
            widget.suffixAction!,
          ],
        ],
      ),
    );
  }
}
