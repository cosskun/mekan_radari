import 'package:flutter/material.dart';

import '../controllers/places_controller.dart';
import '../theme/app_theme.dart';

/// Top search bar with text input, clear action, and Map/List view mode toggle.
class SearchViewToggleBar extends StatefulWidget {
  final PlacesController controller;
  final TextEditingController? searchController;
  final String hintText;
  final VoidCallback? onToggleView;
  final ValueChanged<String>? onSearchChanged;
  final ValueChanged<String>? onSearchSubmitted;

  const SearchViewToggleBar({
    super.key,
    required this.controller,
    this.searchController,
    this.hintText = 'Mekan veya tatlı ara...',
    this.onToggleView,
    this.onSearchChanged,
    this.onSearchSubmitted,
  });

  @override
  State<SearchViewToggleBar> createState() => _SearchViewToggleBarState();
}

class _SearchViewToggleBarState extends State<SearchViewToggleBar> {
  late TextEditingController _textController;
  bool _isInternalController = false;

  @override
  void initState() {
    super.initState();
    if (widget.searchController != null) {
      _textController = widget.searchController!;
    } else {
      _textController =
          TextEditingController(text: widget.controller.searchQuery);
      _isInternalController = true;
    }
  }

  @override
  void didUpdateWidget(covariant SearchViewToggleBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchController != null &&
        widget.searchController != _textController) {
      if (_isInternalController) {
        _textController.dispose();
        _isInternalController = false;
      }
      _textController = widget.searchController!;
    } else if (widget.searchController == null && !_isInternalController) {
      _textController =
          TextEditingController(text: widget.controller.searchQuery);
      _isInternalController = true;
    }

    if (_textController.text != widget.controller.searchQuery) {
      _textController.text = widget.controller.searchQuery;
    }
  }

  @override
  void dispose() {
    if (_isInternalController) {
      _textController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final query = widget.controller.searchQuery;
        final isMapView = widget.controller.isMapView;

        return Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('search_text_field'),
                controller: _textController,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                onChanged: (val) {
                  widget.controller.setSearchQuery(val);
                  widget.onSearchChanged?.call(val);
                },
                onSubmitted: (val) {
                  widget.controller.loadPlaces();
                  widget.onSearchSubmitted?.call(val);
                },
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  hintStyle: const TextStyle(
                    color: AppColors.textDisabled,
                    fontSize: 13,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  suffixIcon: query.isNotEmpty || _textController.text.isNotEmpty
                      ? IconButton(
                          key: const Key('search_clear_button'),
                          icon: const Icon(
                            Icons.clear_rounded,
                            color: AppColors.textTertiary,
                            size: 18,
                          ),
                          onPressed: () {
                            _textController.clear();
                            widget.controller.setSearchQuery('');
                            widget.onSearchChanged?.call('');
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 14,
                  ),
                  filled: true,
                  fillColor: AppColors.inputBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            InkWell(
              key: const Key('map_list_toggle_button'),
              onTap: widget.onToggleView ?? widget.controller.toggleViewMode,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22F59E0B),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      isMapView
                          ? Icons.view_list_rounded
                          : Icons.map_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isMapView ? 'Liste' : 'Harita',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
