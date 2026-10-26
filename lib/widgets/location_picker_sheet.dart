import 'dart:async';
import 'package:flutter/material.dart';

import '../controllers/places_controller.dart';
import '../models/location_preset.dart';
import '../theme/app_theme.dart';
import 'home_app_bar.dart';

/// Modal bottom sheet allowing users to pick location from popular presets
/// or search addresses via Nominatim live search with debouncing.
class LocationPickerSheet extends StatefulWidget {
  final PlacesController controller;
  final void Function(double lat, double lon)? onLocationSelected;
  final Future<void> Function()? onGpsPressed;

  const LocationPickerSheet({
    super.key,
    required this.controller,
    this.onLocationSelected,
    this.onGpsPressed,
  });

  /// Displays the location picker modal bottom sheet.
  static Future<void> show({
    required BuildContext context,
    required PlacesController controller,
    void Function(double lat, double lon)? onLocationSelected,
    Future<void> Function()? onGpsPressed,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => LocationPickerSheet(
        controller: controller,
        onLocationSelected: onLocationSelected,
        onGpsPressed: onGpsPressed,
      ),
    );
  }

  @override
  State<LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<LocationPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  List<LocationPreset> _searchResults = const [];
  bool _isSearching = false;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    if (query.trim().length < 2) {
      if (_searchResults.isNotEmpty || _isSearching) {
        setState(() {
          _searchResults = const [];
          _isSearching = false;
        });
      }
      return;
    }
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _performAddressSearch(query);
    });
  }

  Future<void> _performAddressSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return;

    setState(() => _isSearching = true);
    final results = await widget.controller.searchAddress(trimmed);
    if (!mounted) return;

    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  void _clearSearch() {
    _debounceTimer?.cancel();
    _searchController.clear();
    setState(() {
      _searchResults = const [];
      _isSearching = false;
    });
  }

  void _selectLocation({
    required double lat,
    required double lon,
    required String label,
  }) {
    Navigator.pop(context);
    widget.controller.setLocation(
      lat: lat,
      lon: lon,
      label: label,
    );
    widget.onLocationSelected?.call(lat, lon);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Arama Konumunu Belirle',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // GPS Button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                Navigator.pop(context);
                if (widget.onGpsPressed != null) {
                  await widget.onGpsPressed!();
                } else {
                  await HomeAppBar.useCurrentGpsLocation(
                    context: context,
                    controller: widget.controller,
                    onLocationChanged: widget.onLocationSelected,
                  );
                }
              },
              icon: const Icon(Icons.my_location_rounded),
              label: const Text(
                'Cihazımın Gerçek GPS Konumunu Kullan',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Live Nominatim Address Search
          TextField(
            controller: _searchController,
            style: const TextStyle(color: AppColors.textPrimary),
            onChanged: _onSearchChanged,
            onSubmitted: (val) {
              _debounceTimer?.cancel();
              _performAddressSearch(val);
            },
            decoration: InputDecoration(
              hintText: 'İlçe, semt veya cadde ara (Örn: Üsküdar, Kızılay)...',
              hintStyle: const TextStyle(color: AppColors.textDisabled, fontSize: 13),
              prefixIcon: const Icon(Icons.search, color: AppColors.primary),
              suffixIcon: _isSearching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_searchController.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(
                              Icons.clear_rounded,
                              color: AppColors.textTertiary,
                              size: 18,
                            ),
                            onPressed: _clearSearch,
                          ),
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_forward_rounded,
                            color: AppColors.primary,
                          ),
                          onPressed: () {
                            _debounceTimer?.cancel();
                            _performAddressSearch(_searchController.text);
                          },
                        ),
                      ],
                    ),
              filled: true,
              fillColor: AppColors.inputBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.cardBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.cardBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (_searchResults.isNotEmpty) ...[
            const Text(
              'Arama Sonuçları (Canlı Harita)',
              style: TextStyle(
                color: AppColors.primaryDark,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _searchResults.length,
                itemBuilder: (_, idx) {
                  final item = _searchResults[idx];
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.place_rounded,
                      color: AppColors.blue,
                    ),
                    title: Text(
                      item.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      item.subtitle,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    onTap: () => _selectLocation(
                      lat: item.latitude,
                      lon: item.longitude,
                      label: item.name,
                    ),
                  );
                },
              ),
            ),
            const Divider(color: AppColors.divider),
          ],
          const Text(
            'Popüler Lezzet & Tatlı Merkezleri',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: LocationPreset.popularLocations.length,
              itemBuilder: (_, index) {
                final loc = LocationPreset.popularLocations[index];
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.location_city_rounded,
                    color: AppColors.primaryDark,
                  ),
                  title: Text(
                    loc.name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    loc.subtitle,
                    style: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 12,
                    ),
                  ),
                  onTap: () => _selectLocation(
                    lat: loc.latitude,
                    lon: loc.longitude,
                    label: loc.name,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
