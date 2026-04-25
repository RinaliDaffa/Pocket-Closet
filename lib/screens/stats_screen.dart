import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../db/database_helper.dart';
import '../widgets/stat_card.dart';
import '../services/notification_service.dart';

class StatsScreen extends StatefulWidget {
  final String userId;
  const StatsScreen({super.key, required this.userId});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Map<String, dynamic>? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    final stats = await DatabaseHelper.instance.getStats(widget.userId);
    if (mounted) {
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    }
    // check if any dirty items
    final dirtyCount = stats['dirtyCount'] as int? ?? 0;
    if (dirtyCount >= 3) {
      await NotificationService.instance.showLaundryReminder(dirtyCount);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadStats,
        color: AppTheme.goldPrimary,
        backgroundColor: AppTheme.surfaceColor,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.goldPrimary),
              )
            : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    final s = _stats!;
    final totalClothing = s['totalClothing'] as int? ?? 0;
    final totalOutfits = s['totalOutfits'] as int? ?? 0;
    final neverWorn = s['neverWorn'] as int? ?? 0;
    final dirtyCount = s['dirtyCount'] as int? ?? 0;
    final mostWorn = s['mostWorn'] as Map<String, dynamic>?;
    final topCategory = s['topCategory'] as Map<String, dynamic>?;

    final insights = _buildInsights(
      totalClothing: totalClothing,
      neverWorn: neverWorn,
      dirtyCount: dirtyCount,
      mostWorn: mostWorn,
      topCategory: topCategory,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        // Hero banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.goldPrimary.withOpacity(0.25),
                AppTheme.goldPrimary.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.goldPrimary.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '✦ Lemari Digital',
                style: GoogleFonts.dmSans(
                  color: AppTheme.goldPrimary,
                  fontSize: 12,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Statistik\nPakaianmu',
                style: GoogleFonts.cormorantGaramond(
                  color: AppTheme.textPrimary,
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Semua insight ada di sini',
                style: GoogleFonts.dmSans(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Primary stats grid
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.1,
          children: [
            StatCard(
              emoji: '👗',
              label: 'Total Pakaian',
              value: '$totalClothing',
              subtitle: 'item di lemarimu',
              accentColor: AppTheme.goldPrimary,
            ),
            StatCard(
              emoji: '🧩',
              label: 'Total Outfit',
              value: '$totalOutfits',
              subtitle: 'kombinasi tersimpan',
              accentColor: const Color(0xFF7B68EE),
            ),
            StatCard(
              emoji: '😴',
              label: 'Belum Pernah Dipakai',
              value: '$neverWorn',
              subtitle: neverWorn == 0
                  ? 'semua sudah dipakai!'
                  : 'pakaian terabaikan',
              accentColor: neverWorn > 0
                  ? AppTheme.warningColor
                  : AppTheme.statusClean,
            ),
            StatCard(
              emoji: '🧺',
              label: 'Perlu Dicuci',
              value: '$dirtyCount',
              subtitle: dirtyCount == 0 ? 'lemari bersih!' : 'pakaian kotor',
              accentColor: dirtyCount > 0
                  ? AppTheme.statusDirty
                  : AppTheme.statusClean,
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Most worn & top category
        if (mostWorn != null || topCategory != null) ...[
          _sectionLabel('HIGHLIGHT'),
          const SizedBox(height: 12),
          if (mostWorn != null)
            _highlightCard(
              emoji: '🏆',
              title: 'Paling Sering Dipakai',
              value: mostWorn['name'] as String? ?? '-',
              sub: '${mostWorn['wearCount']}x dipakai',
              color: AppTheme.goldPrimary,
            ),
          if (topCategory != null)
            _highlightCard(
              emoji: topCategory['icon'] as String? ?? '👕',
              title: 'Kategori Terbanyak',
              value: topCategory['name'] as String? ?? '-',
              sub: '${topCategory['total']} item',
              color: const Color(0xFF7B68EE),
            ),
          const SizedBox(height: 8),
        ],

        // Insights
        if (insights.isNotEmpty) ...[
          _sectionLabel('INSIGHT'),
          const SizedBox(height: 12),
          ...insights,
        ],

        const SizedBox(height: 16),

        // Schedule daily notif button
        OutlinedButton.icon(
          onPressed: () async {
            await NotificationService.instance.scheduleDailyOotdReminder();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text(
                      'Pengingat OOTD harian diaktifkan — jam 07.30 ☀️'),
                  backgroundColor: AppTheme.goldPrimary.withOpacity(0.85),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              );
            }
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.goldPrimary,
            side: BorderSide(color: AppTheme.goldPrimary.withOpacity(0.4)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.alarm_rounded, size: 18),
          label: Text(
            'Aktifkan Pengingat OOTD Harian',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _highlightCard({
    required String emoji,
    required String title,
    required String value,
    required String sub,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.dmSans(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.dmSans(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  sub,
                  style: GoogleFonts.dmSans(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildInsights({
    required int totalClothing,
    required int neverWorn,
    required int dirtyCount,
    required Map<String, dynamic>? mostWorn,
    required Map<String, dynamic>? topCategory,
  }) {
    final List<Widget> items = [];
    if (totalClothing == 0) {
      items.add(const InsightBanner(
        emoji: '👗',
        text: 'Mulai tambahkan pakaian ke lemarimu!',
      ));
      return items;
    }
    if (mostWorn != null) {
      final name = mostWorn['name'] as String? ?? '';
      final count = mostWorn['wearCount'] as int? ?? 0;
      items.add(InsightBanner(
        emoji: '🏆',
        text: '"$name" sudah dipakai ${count}x — tertinggi di lemarimu',
        color: AppTheme.goldPrimary,
      ));
    }
    if (neverWorn > 0) {
      items.add(InsightBanner(
        emoji: '😴',
        text: '$neverWorn pakaian belum pernah dipakai sama sekali — coba pakai hari ini!',
        color: AppTheme.warningColor,
      ));
    }
    if (topCategory != null) {
      final catName = topCategory['name'] as String? ?? '';
      final catTotal = topCategory['total'] as int? ?? 0;
      final catIcon = topCategory['icon'] as String? ?? '👕';
      items.add(InsightBanner(
        emoji: catIcon,
        text: 'Kategori terbanyak: $catName ($catTotal item)',
        color: const Color(0xFF7B68EE),
      ));
    }
    if (dirtyCount >= 3) {
      items.add(InsightBanner(
        emoji: '🧺',
        text: '$dirtyCount pakaian perlu dicuci — jangan biarkan menumpuk!',
        color: AppTheme.statusDirty,
      ));
    } else if (dirtyCount == 0 && totalClothing > 0) {
      items.add(const InsightBanner(
        emoji: '✨',
        text: 'Semua pakaian bersih — lemarimu sangat rapi!',
        color: AppTheme.statusClean,
      ));
    }
    return items;
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.dmSans(
        color: AppTheme.textSecondary,
        fontSize: 11,
        letterSpacing: 1.5,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
