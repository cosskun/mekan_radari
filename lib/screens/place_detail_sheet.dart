import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/place_model.dart';
import '../theme/app_theme.dart';

/// Sorting options for venue visitor reviews.
enum ReviewSortOption {
  newest,
  highestRated,
  lowestRated,
}

class PlaceDetailSheet extends StatefulWidget {
  final Place place;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final ValueChanged<PlaceReview> onAddReview;

  const PlaceDetailSheet({
    super.key,
    required this.place,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onAddReview,
  });

  @override
  State<PlaceDetailSheet> createState() => _PlaceDetailSheetState();
}

class _PlaceDetailSheetState extends State<PlaceDetailSheet> {
  late bool _isFav;
  late List<PlaceReview> _reviews;
  late double _rating;
  late int _reviewCount;

  int? _selectedStarFilter; // null means All, 1..5
  ReviewSortOption _selectedSortOption = ReviewSortOption.newest;
  final Set<String> _likedReviewIds = <String>{};

  @override
  void initState() {
    super.initState();
    _isFav = widget.isFavorite;
    _reviews = List.from(widget.place.reviews);
    _rating = widget.place.rating;
    _reviewCount = widget.place.reviewCount;
  }

  double _getSafeRating(double rating) {
    if (rating.isNaN || rating.isInfinite) return 1.0;
    return rating.clamp(0.0, 5.0);
  }

  int _getReviewAgeMinutes(PlaceReview review) {
    if (review.isUserReview) {
      final match = RegExp(r'user_(\d+)').firstMatch(review.id);
      if (match != null) {
        final timestamp = int.tryParse(match.group(1)!);
        if (timestamp != null) {
          final diff =
              (DateTime.now().millisecondsSinceEpoch - timestamp) ~/ 60000;
          return diff >= 0 ? diff : 0;
        }
      }
      return 0; // Fresh user review in current session
    }

    final trimmedRaw = review.relativeTime.trim();
    if (trimmedRaw.isEmpty) {
      final idx = _reviews.indexOf(review);
      return 100000000 + (idx >= 0 ? idx : 0);
    }

    final isoDate = DateTime.tryParse(trimmedRaw);
    if (isoDate != null) {
      final diff = DateTime.now().difference(isoDate).inMinutes;
      return diff >= 0 ? diff : 0;
    }

    final time = trimmedRaw.toLowerCase();

    // Check for optional time component (e.g. "14:30" or "14:30:00")
    final timeMatch =
        RegExp(r'\b(\d{1,2}):(\d{2})(?::(\d{2}))?\b').firstMatch(time);
    final hour = timeMatch != null ? int.tryParse(timeMatch.group(1)!) ?? 0 : 0;
    final minute =
        timeMatch != null ? int.tryParse(timeMatch.group(2)!) ?? 0 : 0;

    // Try European/Turkish date format: DD.MM.YYYY, DD/MM/YYYY, DD-MM-YYYY
    final dmyMatch =
        RegExp(r'\b(\d{1,2})[./\-](\d{1,2})[./\-](\d{4})\b').firstMatch(time);
    if (dmyMatch != null) {
      final day = int.tryParse(dmyMatch.group(1)!);
      final month = int.tryParse(dmyMatch.group(2)!);
      final year = int.tryParse(dmyMatch.group(3)!);
      if (day != null && month != null && year != null) {
        if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
          final date = DateTime(year, month, day, hour, minute);
          final diff = DateTime.now().difference(date).inMinutes;
          return diff >= 0 ? diff : 0;
        }
      }
    }

    // Try YYYY.MM.DD, YYYY/MM/DD
    final ymdMatch =
        RegExp(r'\b(\d{4})[./\-](\d{1,2})[./\-](\d{1,2})\b').firstMatch(time);
    if (ymdMatch != null) {
      final year = int.tryParse(ymdMatch.group(1)!);
      final month = int.tryParse(ymdMatch.group(2)!);
      final day = int.tryParse(ymdMatch.group(3)!);
      if (year != null && month != null && day != null) {
        if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
          final date = DateTime(year, month, day, hour, minute);
          final diff = DateTime.now().difference(date).inMinutes;
          return diff >= 0 ? diff : 0;
        }
      }
    }

    // Try Turkish named dates: "15 Mayıs 2024" or "Mayıs 2024"
    const monthNames = {
      'ocak': 1, 'şubat': 2, 'subat': 2, 'mart': 3, 'nisan': 4,
      'mayıs': 5, 'mayis': 5, 'haziran': 6, 'temmuz': 7, 'ağustos': 8,
      'agustos': 8, 'eylül': 9, 'eylul': 9, 'ekim': 10, 'kasım': 11,
      'kasim': 11, 'aralık': 12, 'aralik': 12, 'january': 1,
      'february': 2, 'march': 3, 'april': 4, 'may': 5, 'june': 6,
      'july': 7, 'august': 8, 'september': 9, 'october': 10,
      'november': 11, 'december': 12,
    };
    final namedDateMatch =
        RegExp(r'\b(\d{1,2})\s+([a-zA-ZçğıöşüÇĞİÖŞÜ]+)\s+(\d{4})\b')
            .firstMatch(time);
    if (namedDateMatch != null) {
      final day = int.tryParse(namedDateMatch.group(1)!);
      final mStr = namedDateMatch.group(2)!.toLowerCase();
      final year = int.tryParse(namedDateMatch.group(3)!);
      final mNum = monthNames[mStr];
      if (day != null && mNum != null && year != null) {
        final date = DateTime(year, mNum, day, hour, minute);
        final diff = DateTime.now().difference(date).inMinutes;
        return diff >= 0 ? diff : 0;
      }
    }
    final monthYearMatch =
        RegExp(r'\b([a-zA-ZçğıöşüÇĞİÖŞÜ]+)\s+(\d{4})\b').firstMatch(time);
    if (monthYearMatch != null) {
      final mStr = monthYearMatch.group(1)!.toLowerCase();
      final year = int.tryParse(monthYearMatch.group(2)!);
      final mNum = monthNames[mStr];
      if (mNum != null && year != null) {
        final date = DateTime(year, mNum, 1);
        final diff = DateTime.now().difference(date).inMinutes;
        return diff >= 0 ? diff : 0;
      }
    }

    if (time.contains('az önce') ||
        time.contains('just now') ||
        time.contains('şimdi') ||
        time.contains('anlık') ||
        time.contains('yeni') ||
        time == 'new') {
      return 0;
    }

    if (time.contains('bugün') || time.contains('today')) {
      return 60; // 1 hour ago
    }
    if (time.contains('dün') || time.contains('yesterday')) {
      return 1440; // 1 day ago
    }
    if (time.contains('geçen hafta') || time.contains('last week')) {
      return 10080; // 1 week ago
    }
    if (time.contains('geçen ay') || time.contains('last month')) {
      return 43200; // 1 month ago
    }
    if (time.contains('geçen yıl') ||
        time.contains('geçen sene') ||
        time.contains('last year')) {
      return 525600; // 1 year ago
    }

    // Parse compound or specific units: e.g. "2 saat 30 dakika önce"
    int calculatedMinutes = 0;
    bool hasUnit = false;

    final hrMatch =
        RegExp(r'(\d+)\s*(?:saat|hour|hours|hr|hrs)\b').firstMatch(time);
    if (hrMatch != null) {
      calculatedMinutes += (int.tryParse(hrMatch.group(1)!) ?? 0) * 60;
      hasUnit = true;
    }

    final minMatch =
        RegExp(r'(\d+)\s*(?:dakika|dk|min|mins|minute|minutes)\b')
            .firstMatch(time);
    if (minMatch != null) {
      calculatedMinutes += int.tryParse(minMatch.group(1)!) ?? 0;
      hasUnit = true;
    }

    final dayMatch =
        RegExp(r'(\d+)\s*(?:gün|gun|day|days)\b').firstMatch(time);
    if (dayMatch != null) {
      calculatedMinutes += (int.tryParse(dayMatch.group(1)!) ?? 0) * 1440;
      hasUnit = true;
    }

    final wkMatch =
        RegExp(r'(\d+)\s*(?:hafta|week|weeks)\b').firstMatch(time);
    if (wkMatch != null) {
      calculatedMinutes += (int.tryParse(wkMatch.group(1)!) ?? 0) * 10080;
      hasUnit = true;
    }

    final moMatch =
        RegExp(r'(\d+)\s*(?:ay|aylar|month|months)\b').firstMatch(time);
    if (moMatch != null) {
      calculatedMinutes += (int.tryParse(moMatch.group(1)!) ?? 0) * 43200;
      hasUnit = true;
    }

    final yrMatch =
        RegExp(r'(\d+)\s*(?:yıl|sene|year|years)\b').firstMatch(time);
    if (yrMatch != null) {
      calculatedMinutes += (int.tryParse(yrMatch.group(1)!) ?? 0) * 525600;
      hasUnit = true;
    }

    if (hasUnit && calculatedMinutes > 0) {
      return calculatedMinutes;
    }

    // Fallback for single words without preceding numbers
    if (RegExp(r'\b(dakika|dk|min|mins)\b').hasMatch(time)) return 15;
    if (RegExp(r'\b(saat|hour|hours)\b').hasMatch(time)) return 120;
    if (RegExp(r'\b(gün|gun|day|days)\b').hasMatch(time)) return 1440;
    if (RegExp(r'\b(hafta|week|weeks)\b').hasMatch(time)) return 10080;
    if (RegExp(r'\b(ay|aylar|month|months)\b').hasMatch(time)) return 43200;
    if (RegExp(r'\b(yıl|sene|year|years)\b').hasMatch(time)) return 525600;

    final idx = _reviews.indexOf(review);
    return 100000000 + (idx >= 0 ? idx : 0);
  }

  List<PlaceReview> get _filteredAndSortedReviews {
    var list = List<PlaceReview>.from(_reviews);

    if (_selectedStarFilter != null) {
      list = list
          .where((r) =>
              _getSafeRating(r.rating).round().clamp(1, 5) ==
              _selectedStarFilter)
          .toList();
    }

    switch (_selectedSortOption) {
      case ReviewSortOption.newest:
        list.sort((a, b) {
          final aAge = _getReviewAgeMinutes(a);
          final bAge = _getReviewAgeMinutes(b);
          if (aAge != bAge) {
            return aAge.compareTo(bAge);
          }
          return _reviews.indexOf(a).compareTo(_reviews.indexOf(b));
        });
        break;
      case ReviewSortOption.highestRated:
        list.sort((a, b) {
          final aRating = _getSafeRating(a.rating);
          final bRating = _getSafeRating(b.rating);
          final cmp = bRating.compareTo(aRating);
          if (cmp != 0) return cmp;
          final ageCmp =
              _getReviewAgeMinutes(a).compareTo(_getReviewAgeMinutes(b));
          if (ageCmp != 0) return ageCmp;
          return _reviews.indexOf(a).compareTo(_reviews.indexOf(b));
        });
        break;
      case ReviewSortOption.lowestRated:
        list.sort((a, b) {
          final aRating = _getSafeRating(a.rating);
          final bRating = _getSafeRating(b.rating);
          final cmp = aRating.compareTo(bRating);
          if (cmp != 0) return cmp;
          final ageCmp =
              _getReviewAgeMinutes(a).compareTo(_getReviewAgeMinutes(b));
          if (ageCmp != 0) return ageCmp;
          return _reviews.indexOf(a).compareTo(_reviews.indexOf(b));
        });
        break;
    }

    return list;
  }

  Future<void> _openUrl(String urlString) async {
    final uri = Uri.tryParse(urlString);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bağlantı açılamadı.')),
        );
      }
    }
  }

  void _showAddReviewDialog() {
    double selectedStars = 5.0;
    final nameController = TextEditingController();
    final commentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
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
                      Expanded(
                        child: Text(
                          '${widget.place.name} İçin Yorum Yaz',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Puanınız:',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: List.generate(5, (index) {
                      final starVal = index + 1.0;
                      return IconButton(
                        onPressed: () {
                          setModalState(() => selectedStars = starVal);
                        },
                        icon: Icon(
                          starVal <= selectedStars
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: AppColors.primary,
                          size: 36,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Adınız (İsteğe bağlı)',
                      labelStyle: const TextStyle(color: AppColors.textTertiary),
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
                  const SizedBox(height: 12),
                  TextField(
                    controller: commentController,
                    maxLines: 3,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Deneyiminizi ve önerdiğiniz lezzetleri paylaşın...',
                      labelStyle: const TextStyle(color: AppColors.textTertiary),
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
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        final text = commentController.text.trim();
                        if (text.isEmpty) return;
                        final newRev = PlaceReview(
                          id: 'user_${DateTime.now().millisecondsSinceEpoch}',
                          authorName: nameController.text.trim().isEmpty
                              ? 'Siz (Mekan Radarı Kullanıcısı)'
                              : nameController.text.trim(),
                          authorBadge: 'Doğrulanmış Ziyaretçi',
                          rating: selectedStars,
                          relativeTime: 'Az önce',
                          comment: text,
                          likesCount: 1,
                          isUserReview: true,
                        );
                        widget.onAddReview(newRev);
                        setState(() {
                          _reviews.insert(0, newRev);
                          _reviewCount += 1;
                          _rating = double.parse(
                            (((_rating * (_reviewCount - 1)) + selectedStars) /
                                    _reviewCount)
                                .toStringAsFixed(1),
                          );
                          _selectedStarFilter = null;
                          _selectedSortOption = ReviewSortOption.newest;
                        });
                        Navigator.pop(ctx);
                      },
                      icon: const Icon(Icons.send_rounded),
                      label: const Text(
                        'Yorumu Yayınla',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final place = widget.place;

    return DraggableScrollableSheet(
      initialChildSize: 0.86,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: [
                    // Category & Data Source Row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            place.subCategory,
                            style: const TextStyle(
                              color: AppColors.primaryDark,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.greenLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.verified_rounded,
                                size: 13,
                                color: AppColors.green,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                place.dataSource,
                                style: const TextStyle(
                                  color: AppColors.green,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () {
                            widget.onToggleFavorite();
                            setState(() => _isFav = !_isFav);
                          },
                          icon: Icon(
                            _isFav
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: _isFav
                                ? AppColors.red
                                : AppColors.textDisabled,
                            size: 28,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Title
                    Text(
                      place.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Distance, Walking time, Open status, Price
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.near_me_rounded,
                              size: 16,
                              color: AppColors.blue,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${place.formattedDistance} uzaklıkta (~${place.walkingMinutes} dk yürüyüş)',
                              style: const TextStyle(
                                color: AppColors.blue,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '•  ${place.priceSymbol}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          place.isOpenNow ? '•  Şu an Açık' : '•  Kapalı',
                          style: TextStyle(
                            color: place.isOpenNow
                                ? AppColors.green
                                : AppColors.red,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Address & Hours
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          color: AppColors.textTertiary,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            place.address,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time_rounded,
                          color: AppColors.textTertiary,
                          size: 17,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Çalışma Saatleri: ${place.openingHours}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Quick Action Buttons (Google Reviews, Directions, Add Review)
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () => _openUrl(place.googleMapsSearchUrl),
                            icon: const Icon(Icons.open_in_new_rounded, size: 18),
                            label: const Text(
                              'Google Harita & Yorumlar',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () =>
                                _openUrl(place.googleDirectionsUrl),
                            icon: const Icon(Icons.directions_walk_rounded, size: 18),
                            label: const Text(
                              'Yol Tarifi Al',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Google-Style Rating Breakdown Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.inputBackground,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Row(
                        children: [
                          // Left big score
                          Builder(
                            builder: (context) {
                              final safeOverallRating =
                                  (_rating.isNaN || _rating.isInfinite)
                                      ? 0.0
                                      : _rating.clamp(0.0, 5.0);
                              return Column(
                                children: [
                                  Text(
                                    safeOverallRating.toStringAsFixed(1),
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 42,
                                      fontWeight: FontWeight.w900,
                                      height: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: List.generate(5, (i) {
                                      return Icon(
                                        i < safeOverallRating.round()
                                            ? Icons.star_rounded
                                            : Icons.star_border_rounded,
                                        color: AppColors.primary,
                                        size: 18,
                                      );
                                    }),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$_reviewCount değerlendirme',
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(width: 20),
                          // Right bars
                          Expanded(
                            child: Column(
                              children: [5, 4, 3, 2, 1].map((star) {
                                final distSum = place.starDistribution.values
                                    .fold(0.0, (sum, v) => sum + v);
                                double ratio;
                                if (place.starDistribution.isEmpty ||
                                    distSum == 0) {
                                  ratio = _reviews.isNotEmpty
                                      ? _reviews
                                              .where((r) =>
                                                  _getSafeRating(r.rating)
                                                      .round()
                                                      .clamp(1, 5) ==
                                                  star)
                                              .length /
                                          _reviews.length
                                      : 0.0;
                                } else if (distSum > 1.0) {
                                  ratio =
                                      (place.starDistribution[star] ?? 0.0) /
                                          distSum;
                                } else {
                                  ratio = place.starDistribution[star] ?? 0.0;
                                }
                                ratio = ratio.clamp(0.0, 1.0);
                                final isBarSelected = _selectedStarFilter == star;
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 2.0),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      key: ValueKey('star_bar_$star'),
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () {
                                        setState(() {
                                          if (_selectedStarFilter == star) {
                                            _selectedStarFilter = null;
                                          } else {
                                            _selectedStarFilter = star;
                                          }
                                        });
                                      },
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 180),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isBarSelected
                                              ? AppColors.primaryLight
                                              : Colors.transparent,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                            color: isBarSelected
                                                ? AppColors.primary
                                                : Colors.transparent,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Text(
                                              '$star',
                                              style: TextStyle(
                                                color: isBarSelected
                                                    ? AppColors.primaryDark
                                                    : AppColors.textSecondary,
                                                fontSize: 12,
                                                fontWeight: isBarSelected
                                                    ? FontWeight.bold
                                                    : FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Icon(
                                              Icons.star_rounded,
                                              size: 13,
                                              color: isBarSelected
                                                  ? AppColors.primaryDark
                                                  : AppColors.primary,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                child: LinearProgressIndicator(
                                                  value: ratio,
                                                  minHeight: 7,
                                                  backgroundColor: AppColors.cardBorder,
                                                  valueColor:
                                                      AlwaysStoppedAnimation(
                                                    isBarSelected
                                                        ? AppColors.primaryDark
                                                        : AppColors.primary,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Rich Sentiment Breakdown Card
                    _buildSentimentCard(place),
                    const SizedBox(height: 18),

                    // Popular Items & Highlights
                    const Text(
                      'Öne Çıkan Lezzetler & Özellikler',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ...place.popularItems.map(
                          (item) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.local_fire_department_rounded,
                                  size: 15,
                                  color: AppColors.primaryDark,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  item,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        ...place.tags.map(
                          (tag) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.inputBackground,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.cardBorder),
                            ),
                            child: Text(
                              tag,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),

                    // Reviews Header + Write Review Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Ziyaretçi Yorumları (${_reviews.length})',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _showAddReviewDialog,
                          icon: const Icon(
                            Icons.rate_review_rounded,
                            size: 18,
                            color: AppColors.primaryDark,
                          ),
                          label: const Text(
                            'Yorum Yaz',
                            style: TextStyle(
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Review Filtering Chips by Star Rating
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildStarFilterChip(
                            label: 'All',
                            starValue: null,
                            key: const Key('review_filter_all'),
                          ),
                          const SizedBox(width: 8),
                          ...[5, 4, 3, 2, 1].map((star) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _buildStarFilterChip(
                                label: '$star★',
                                starValue: star,
                                key: Key('review_filter_$star'),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Review Sorting Bar
                    Builder(
                      builder: (context) {
                        final currentFiltered = _filteredAndSortedReviews;
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                _selectedStarFilter != null
                                    ? '$_selectedStarFilter★ (${currentFiltered.length} yorum)'
                                    : 'Tümü (${currentFiltered.length} yorum)',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                const Icon(
                                  Icons.sort_rounded,
                                  size: 16,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  height: 32,
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppColors.cardBorder),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<ReviewSortOption>(
                                      key: const Key('review_sort_button'),
                                      value: _selectedSortOption,
                                      dropdownColor: AppColors.surface,
                                      icon: const Icon(
                                        Icons.arrow_drop_down,
                                        color: AppColors.primaryDark,
                                        size: 18,
                                      ),
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      onChanged: (newOption) {
                                        if (newOption != null) {
                                          setState(() => _selectedSortOption = newOption);
                                        }
                                      },
                                      items: const [
                                        DropdownMenuItem(
                                          key: Key('review_sort_newest'),
                                          value: ReviewSortOption.newest,
                                          child: Text('Newest'),
                                        ),
                                        DropdownMenuItem(
                                          key: Key('review_sort_highest'),
                                          value: ReviewSortOption.highestRated,
                                          child: Text('Highest Rated'),
                                        ),
                                        DropdownMenuItem(
                                          key: Key('review_sort_lowest'),
                                          value: ReviewSortOption.lowestRated,
                                          child: Text('Lowest Rated'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),

                    // Filtered and Sorted Reviews List
                    Builder(
                      builder: (context) {
                        final displayedReviews = _filteredAndSortedReviews;

                        if (displayedReviews.isEmpty) {
                          final hasAnyReviews = _reviews.isNotEmpty;
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 20),
                            padding: const EdgeInsets.all(24),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.inputBackground,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.cardBorder),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  hasAnyReviews
                                      ? Icons.star_border_rounded
                                      : Icons.rate_review_outlined,
                                  size: 40,
                                  color: AppColors.textTertiary,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  hasAnyReviews
                                      ? '$_selectedStarFilter★ kriterine uygun değerlendirme bulunamadı.'
                                      : 'Bu mekan için henüz değerlendirme yapılmamış.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                if (hasAnyReviews)
                                  TextButton(
                                    onPressed: () {
                                      setState(() => _selectedStarFilter = null);
                                    },
                                    child: const Text(
                                      'Tüm Yorumları Göster',
                                      style: TextStyle(
                                        color: AppColors.primaryDark,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                else
                                  TextButton.icon(
                                    onPressed: _showAddReviewDialog,
                                    icon: const Icon(
                                      Icons.edit_note_rounded,
                                      color: AppColors.primaryDark,
                                      size: 18,
                                    ),
                                    label: const Text(
                                      'İlk Değerlendirmeyi Siz Yapın',
                                      style: TextStyle(
                                        color: AppColors.primaryDark,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }

                        final seenIds = <String, int>{};
                        return Column(
                          children:
                              displayedReviews.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final rev = entry.value;
                            final count =
                                seenIds[rev.id] = (seenIds[rev.id] ?? 0) + 1;
                            final reviewKey = rev.id.isEmpty
                                ? 'rev_$idx'
                                : (count == 1 ? rev.id : '${rev.id}_$count');
                            final isLiked =
                                _likedReviewIds.contains(reviewKey);
                            final currentLikes =
                                rev.likesCount + (isLiked ? 1 : 0);
                            final safeRevRating = _getSafeRating(rev.rating);
                            final sentiment = _getSentimentLabel(safeRevRating);
                            final trimmedAuthor = rev.authorName.trim();
                            final displayAuthor = trimmedAuthor.isEmpty
                                ? 'Anonim Ziyaretçi'
                                : trimmedAuthor;
                            final avatarLetter = (trimmedAuthor.isNotEmpty
                                    ? trimmedAuthor.characters.first
                                    : 'Z')
                                .toUpperCase();

                            return Container(
                              key: ValueKey('review_card_$reviewKey'),
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: AppColors.cardShadow,
                                border: Border.all(
                                  color: rev.isUserReview
                                      ? AppColors.primary
                                          .withValues(alpha: 0.5)
                                      : AppColors.cardBorder,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor:
                                            AppColors.inputBackground,
                                        child: Text(
                                          avatarLetter,
                                          style: const TextStyle(
                                            color: AppColors.primaryDark,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              displayAuthor,
                                              style: const TextStyle(
                                                color: AppColors.textPrimary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 4,
                                              children: [
                                                // Verified visitor badge
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.blueLight,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6),
                                                    border: Border.all(
                                                      color: AppColors.blue
                                                          .withValues(
                                                              alpha: 0.35),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      const Icon(
                                                        Icons.verified_rounded,
                                                        size: 11,
                                                        color: AppColors.blue,
                                                      ),
                                                      const SizedBox(width: 3),
                                                      Text(
                                                        rev.authorBadge,
                                                        style: const TextStyle(
                                                          color: AppColors.blue,
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                if (rev.isUserReview)
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.primaryLight,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              6),
                                                      border: Border.all(
                                                        color: AppColors.primary
                                                            .withValues(
                                                                alpha: 0.4),
                                                      ),
                                                    ),
                                                    child: const Text(
                                                      'Sizin Yorumunuz',
                                                      style: TextStyle(
                                                        color: AppColors.primaryDark,
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        rev.relativeTime,
                                        style: const TextStyle(
                                          color: AppColors.textTertiary,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  // Clear rating indicator + Stars + Sentiment badge
                                  Wrap(
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryLight,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          border: Border.all(
                                            color: AppColors.primary
                                                .withValues(alpha: 0.4),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              safeRevRating.toStringAsFixed(1),
                                              style: const TextStyle(
                                                color: AppColors.primaryDark,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(width: 2),
                                            const Icon(
                                              Icons.star_rounded,
                                              size: 13,
                                              color: AppColors.primaryDark,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: List.generate(5, (i) {
                                          return Icon(
                                            i < safeRevRating.round()
                                                ? Icons.star_rounded
                                                : Icons.star_border_rounded,
                                            color: AppColors.primary,
                                            size: 15,
                                          );
                                        }),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: sentiment.color
                                              .withValues(alpha: 0.14),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          sentiment.label,
                                          style: TextStyle(
                                            color: sentiment.color,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    rev.comment,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 13.5,
                                      height: 1.45,
                                    ),
                                  ),
                                  if (rev.orderedItems.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: rev.orderedItems.map((item) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.inputBackground,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            border: Border.all(color: AppColors.cardBorder),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.restaurant_menu,
                                                size: 11,
                                                color: AppColors.textSecondary,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                item,
                                                style: const TextStyle(
                                                  color: AppColors.textSecondary,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  // Helpful badge
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: InkWell(
                                      key: ValueKey(
                                          'helpful_badge_$reviewKey'),
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () {
                                        setState(() {
                                          if (isLiked) {
                                            _likedReviewIds.remove(reviewKey);
                                          } else {
                                            _likedReviewIds.add(reviewKey);
                                          }
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isLiked
                                              ? AppColors.blueLight
                                              : AppColors.inputBackground,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                            color: isLiked
                                                ? AppColors.blue
                                                : AppColors.cardBorder,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              isLiked
                                                  ? Icons.thumb_up_rounded
                                                  : Icons.thumb_up_outlined,
                                              size: 13,
                                              color: isLiked
                                                  ? AppColors.blue
                                                  : AppColors.textSecondary,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Faydalı ($currentLikes)',
                                              style: TextStyle(
                                                color: isLiked
                                                    ? AppColors.blue
                                                    : AppColors.textSecondary,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStarFilterChip({
    required String label,
    required int? starValue,
    required Key key,
  }) {
    final isSelected = _selectedStarFilter == starValue;
    return InkWell(
      key: key,
      onTap: () {
        setState(() {
          if (_selectedStarFilter == starValue) {
            _selectedStarFilter = null;
          } else {
            _selectedStarFilter = starValue;
          }
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.inputBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.cardBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildSentimentCard(Place place) {
    final total = _reviews.length;
    final positiveCount = _reviews.where((r) => r.rating >= 4.0).length;
    final neutralCount =
        _reviews.where((r) => r.rating >= 2.5 && r.rating < 4.0).length;
    final criticalCount = _reviews.where((r) => r.rating < 2.5).length;

    final positivePct =
        total > 0 ? ((positiveCount / total) * 100).round() : 0;
    final neutralPct =
        total > 0 ? ((neutralCount / total) * 100).round() : 0;
    final criticalPct =
        total > 0 ? ((criticalCount / total) * 100).round() : 0;

    final Color badgeColor;
    final Color badgeBg;
    if (total == 0) {
      badgeColor = AppColors.textDisabled;
      badgeBg = AppColors.cardBorder;
    } else if (positivePct >= 70) {
      badgeColor = AppColors.green;
      badgeBg = AppColors.greenLight;
    } else if (positivePct >= 40) {
      badgeColor = AppColors.primaryDark;
      badgeBg = AppColors.primaryLight;
    } else {
      badgeColor = AppColors.red;
      badgeBg = AppColors.redLight;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: const [
                    Icon(
                      Icons.auto_graph_rounded,
                      size: 16,
                      color: AppColors.blue,
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Duygu & Memnuniyet Analizi',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  total > 0 ? '%$positivePct Memnuniyet' : 'Değerlendirme Yok',
                  style: TextStyle(
                    color: badgeColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 6,
              child: Row(
                children: [
                  if (positiveCount > 0)
                    Expanded(
                      flex: positiveCount,
                      child: Container(color: AppColors.green),
                    ),
                  if (neutralCount > 0)
                    Expanded(
                      flex: neutralCount,
                      child: Container(color: AppColors.primary),
                    ),
                  if (criticalCount > 0)
                    Expanded(
                      flex: criticalCount,
                      child: Container(color: AppColors.red),
                    ),
                  if (total == 0)
                    Expanded(
                      child: Container(color: AppColors.cardBorder),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.spaceAround,
            spacing: 12,
            runSpacing: 6,
            children: [
              _buildSentimentLegendItem(
                icon: Icons.sentiment_very_satisfied_rounded,
                color: AppColors.green,
                label: 'Olumlu',
                pct: positivePct,
              ),
              _buildSentimentLegendItem(
                icon: Icons.sentiment_neutral_rounded,
                color: AppColors.primaryDark,
                label: 'Dengeli',
                pct: neutralPct,
              ),
              _buildSentimentLegendItem(
                icon: Icons.sentiment_dissatisfied_rounded,
                color: AppColors.red,
                label: 'Eleştiri',
                pct: criticalPct,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSentimentLegendItem({
    required IconData icon,
    required Color color,
    required String label,
    required int pct,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          '$label %$pct',
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  ({String label, Color color}) _getSentimentLabel(double rating) {
    if (rating >= 4.5) {
      return (label: 'Harika', color: const Color(0xFF10B981));
    } else if (rating >= 4.0) {
      return (label: 'Çok İyi', color: const Color(0xFF34D399));
    } else if (rating >= 3.0) {
      return (label: 'Ortalama', color: const Color(0xFFFBBF24));
    } else if (rating >= 2.0) {
      return (label: 'Geliştirilmeli', color: const Color(0xFFF97316));
    } else {
      return (label: 'Kötü', color: const Color(0xFFEF4444));
    }
  }
}
