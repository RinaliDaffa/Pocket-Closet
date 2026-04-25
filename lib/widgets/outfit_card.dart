import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/outfit_model.dart';

class OutfitCard extends StatelessWidget {
  final OutfitModel outfit;
  final List<Map<String, dynamic>> items;
  final VoidCallback? onTap;
  final VoidCallback? onSetOotd;
  final VoidCallback? onDelete;

  const OutfitCard({
    super.key,
    required this.outfit,
    required this.items,
    this.onTap,
    this.onSetOotd,
    this.onDelete,
  });

  Color _occasionColor(String occasion) {
    switch (occasion) {
      case 'formal':
        return const Color(0xFF7B68EE);
      case 'sport':
        return const Color(0xFF4CAF82);
      case 'hangout':
        return const Color(0xFFE8A040);
      default:
        return AppTheme.goldPrimary;
    }
  }

  String _occasionLabel(String occasion) {
    switch (occasion) {
      case 'formal':
        return 'Formal';
      case 'sport':
        return 'Sport';
      case 'hangout':
        return 'Hangout';
      default:
        return 'Casual';
    }
  }

  @override
  Widget build(BuildContext context) {
    final occasionColor = _occasionColor(outfit.occasion);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: outfit.isOotd
                ? AppTheme.goldPrimary.withOpacity(0.6)
                : AppTheme.goldPrimary.withOpacity(0.15),
            width: outfit.isOotd ? 1.5 : 1,
          ),
          boxShadow: outfit.isOotd
              ? [
                  BoxShadow(
                    color: AppTheme.goldPrimary.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (outfit.isOotd)
                          Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.goldPrimary.withOpacity(0.8),
                                  AppTheme.goldLight.withOpacity(0.6),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded,
                                    size: 11, color: AppTheme.backgroundDark),
                                const SizedBox(width: 4),
                                Text(
                                  'OOTD Hari Ini',
                                  style: GoogleFonts.dmSans(
                                    color: AppTheme.backgroundDark,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Text(
                          outfit.name,
                          style: GoogleFonts.dmSans(
                            color: AppTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: occasionColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: occasionColor.withOpacity(0.4)),
                              ),
                              child: Text(
                                _occasionLabel(outfit.occasion),
                                style: GoogleFonts.dmSans(
                                  color: occasionColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${items.length} item',
                              style: GoogleFonts.dmSans(
                                color: AppTheme.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Action buttons
                  Column(
                    children: [
                      if (onSetOotd != null && !outfit.isOotd)
                        GestureDetector(
                          onTap: onSetOotd,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.goldPrimary,
                                  AppTheme.goldLight,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'OOTD',
                              style: GoogleFonts.dmSans(
                                color: AppTheme.backgroundDark,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      if (onDelete != null)
                        GestureDetector(
                          onTap: onDelete,
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: AppTheme.errorColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: AppTheme.errorColor.withOpacity(0.3)),
                            ),
                            child: const Icon(
                              Icons.delete_outline_rounded,
                              size: 16,
                              color: AppTheme.errorColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              if (items.isNotEmpty) ...[
                const SizedBox(height: 12),
                Divider(color: AppTheme.goldPrimary.withOpacity(0.1)),
                const SizedBox(height: 10),
                // Item emoji row
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: items.map((item) {
                    final icon = item['categoryIcon'] as String? ?? '👕';
                    final name = item['name'] as String? ?? '';
                    final role = item['role'] as String? ?? '';
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppTheme.goldPrimary.withOpacity(0.1)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(icon, style: const TextStyle(fontSize: 13)),
                          const SizedBox(width: 5),
                          Text(
                            name,
                            style: GoogleFonts.dmSans(
                              color: AppTheme.textPrimary,
                              fontSize: 12,
                            ),
                          ),
                          if (role.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            Text(
                              '· $role',
                              style: GoogleFonts.dmSans(
                                color: AppTheme.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
