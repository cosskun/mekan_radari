import 'package:flutter/material.dart';

import '../controllers/places_controller.dart';
import '../theme/app_theme.dart';

/// Distance radius slider (50m to 3000m) with 6 quick preset chips and auto-fetch trigger.
class RadiusSliderBar extends StatelessWidget {
  final PlacesController controller;
  final ValueChanged<double>? onRadiusChanged;
  final ValueChanged<double>? onRadiusPresetTapped;
  final List<double> presets;

  const RadiusSliderBar({
    super.key,
    required this.controller,
    this.onRadiusChanged,
    this.onRadiusPresetTapped,
    this.presets = const [50.0, 100.0, 250.0, 500.0, 1000.0, 2500.0],
  });

  /// Formats radius distance in meters or kilometers.
  static String formatRadius(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    }
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  /// Compact chip label for presets (e.g. 50m, 1km, 2.5km).
  static String formatPresetLabel(double preset) {
    if (preset < 1000) {
      return '${preset.toInt()}m';
    }
    return '${(preset / 1000).toStringAsFixed(preset == 1000 ? 0 : 1)}km';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final currentRadius = controller.radiusMeters.clamp(50.0, 3000.0);

        return Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            color: AppColors.inputBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.radar_rounded,
                    color: AppColors.blue,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Mesafe Yarıçapı',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.blueLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.blue.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Text(
                      formatRadius(currentRadius),
                      key: const Key('radius_display_label'),
                      style: const TextStyle(
                        color: AppColors.blue,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: presets.map(
                    (preset) {
                      final active = (currentRadius - preset).abs() < 15;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: InkWell(
                          key: ValueKey('radius_preset_${preset.toInt()}'),
                          onTap: () {
                            controller.setRadiusMeters(preset);
                            if (preset > 1200) {
                              controller.loadPlaces();
                            }
                            onRadiusPresetTapped?.call(preset);
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: active
                                  ? AppColors.blue
                                  : AppColors.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: active
                                    ? AppColors.blue
                                    : AppColors.cardBorder,
                              ),
                              boxShadow: active
                                  ? [
                                      BoxShadow(
                                        color: AppColors.blue.withValues(alpha: 0.2),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Text(
                              formatPresetLabel(preset),
                              style: TextStyle(
                                color: active ? Colors.white : AppColors.textSecondary,
                                fontSize: 11.5,
                                fontWeight: active ? FontWeight.bold : FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ).toList(),
                ),
              ),
              const SizedBox(height: 4),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppColors.blue,
                  inactiveTrackColor: AppColors.cardBorder,
                  thumbColor: AppColors.blue,
                  overlayColor:
                      AppColors.blue.withValues(alpha: 0.15),
                  trackHeight: 4,
                ),
                child: Slider(
                  key: const Key('radius_slider'),
                  value: currentRadius,
                  min: 50.0,
                  max: 3000.0,
                  divisions: 59,
                  onChanged: (val) {
                    controller.setRadiusMeters(val);
                  },
                  onChangeEnd: (val) {
                    if (val > 1200) {
                      controller.loadPlaces();
                    }
                    onRadiusChanged?.call(val);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
