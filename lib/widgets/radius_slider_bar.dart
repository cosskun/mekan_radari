import 'package:flutter/material.dart';

import '../controllers/places_controller.dart';

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
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.social_distance_rounded,
                    color: Color(0xFF38BDF8),
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Mesafe Yarıçapı: ',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12.5,
                    ),
                  ),
                  Text(
                    formatRadius(currentRadius),
                    key: const Key('radius_display_label'),
                    style: const TextStyle(
                      color: Color(0xFF38BDF8),
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  ...presets.map(
                    (preset) {
                      final active = (currentRadius - preset).abs() < 15;
                      return Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: InkWell(
                          key: ValueKey('radius_preset_${preset.toInt()}'),
                          onTap: () {
                            controller.setRadiusMeters(preset);
                            if (preset > 1200) {
                              controller.loadPlaces();
                            }
                            onRadiusPresetTapped?.call(preset);
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: active
                                  ? const Color(0xFF38BDF8)
                                  : Colors.white10,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              formatPresetLabel(preset),
                              style: TextStyle(
                                color: active ? Colors.black : Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: const Color(0xFF38BDF8),
                  inactiveTrackColor: Colors.white12,
                  thumbColor: const Color(0xFF38BDF8),
                  overlayColor:
                      const Color(0xFF38BDF8).withValues(alpha: 0.2),
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
