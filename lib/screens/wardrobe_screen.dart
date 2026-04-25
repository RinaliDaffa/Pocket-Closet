import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../db/database_helper.dart';
import '../models/category_model.dart';
import '../widgets/clothing_card.dart';
import '../services/firestore_service.dart';
import 'add_clothing_screen.dart';

class WardrobeScreen extends StatefulWidget {
  final String userId;
  const WardrobeScreen({super.key, required this.userId});

  @override
  State<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends State<WardrobeScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<Map<String, dynamic>> _clothes = [];
  List<CategoryModel> _categories = [];
  int? _selectedCategoryId; // null = all
  String? _selectedStatus; // null = all
  bool _isLoading = true;

  final _statusFilters = [
    {'value': null, 'label': 'Semua'},
    {'value': 'clean', 'label': '✓ Bersih'},
    {'value': 'dirty', 'label': '⚠ Kotor'},
    {'value': 'laundry', 'label': '🧺 Laundry'},
  ];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    await Future.wait([_loadCategories(), _loadClothes()]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadCategories() async {
    final cats = await DatabaseHelper.instance.getAllCategories();
    if (mounted) setState(() => _categories = cats);
  }

  Future<void> _loadClothes() async {
    List<Map<String, dynamic>> result;
    if (_selectedCategoryId != null) {
      result = await DatabaseHelper.instance.getClothingByCategory(
          _selectedCategoryId!, widget.userId);
    } else if (_selectedStatus != null) {
      result = await DatabaseHelper.instance
          .getClothingByStatus(_selectedStatus!, widget.userId);
    } else {
      result = await DatabaseHelper.instance.getAllClothing(widget.userId);
    }
    if (mounted) setState(() => _clothes = result);
  }

  Future<void> _openAddClothing() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => AddClothingScreen(userId: widget.userId)),
    );
    if (added == true) {
      _loadClothes();
    }
  }

  Future<void> _changeStatus(int id, String currentStatus) async {
    final statuses = ['clean', 'dirty', 'laundry'];
    final nextIndex = (statuses.indexOf(currentStatus) + 1) % statuses.length;
    final newStatus = statuses[nextIndex];
    await DatabaseHelper.instance.updateClothingStatus(id, newStatus);
    _loadClothes();
  }

  Future<void> _deleteClothing(int id, String name, String? firestoreId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Hapus Pakaian',
          style: GoogleFonts.cormorantGaramond(
            color: AppTheme.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Hapus "$name" dari lemarimu?',
          style: GoogleFonts.dmSans(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal',
                style: GoogleFonts.dmSans(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      // 1. Hapus dari SQLite lokal
      await DatabaseHelper.instance.deleteClothing(id);

      // 2. Sync hapus dari Firestore
      if (firestoreId != null) {
        try {
          await FirestoreService.instance.deleteClothing(firestoreId);
        } catch (e) {
          debugPrint('Firestore delete failed: $e');
        }
      }

      _loadClothes();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadAll,
        color: AppTheme.goldPrimary,
        backgroundColor: AppTheme.surfaceColor,
        child: CustomScrollView(
          slivers: [
            // Stats header
            SliverToBoxAdapter(
              child: _buildHeader(),
            ),

            // Category filter
            SliverToBoxAdapter(
              child: _buildCategoryFilter(),
            ),

            // Status filter
            SliverToBoxAdapter(
              child: _buildStatusFilter(),
            ),

            // Content
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: AppTheme.goldPrimary),
                ),
              )
            else if (_clothes.isEmpty)
              SliverFillRemaining(
                child: _buildEmptyState(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      final item = _clothes[i];
                      final id = item['id'] as int;
                      final name = item['name'] as String? ?? '';
                      final status = item['status'] as String? ?? 'clean';
                      final firestoreId = item['firestoreId'] as String?;
                      return ClothingCard(
                        item: item,
                        onStatusChange: () => _changeStatus(id, status),
                        onDelete: () => _deleteClothing(id, name, firestoreId),
                      );
                    },
                    childCount: _clothes.length,
                  ),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.72,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddClothing,
        backgroundColor: AppTheme.goldPrimary,
        foregroundColor: AppTheme.backgroundDark,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'Tambah',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final totalCount = _clothes.length;
    final cleanCount =
        _clothes.where((c) => c['status'] == 'clean').length;
    final dirtyCount =
        _clothes.where((c) => c['status'] == 'dirty').length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.goldPrimary.withOpacity(0.15),
            AppTheme.goldPrimary.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.goldPrimary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          _headerStat('$totalCount', 'Total', AppTheme.goldPrimary),
          _divider(),
          _headerStat('$cleanCount', 'Bersih', AppTheme.statusClean),
          _divider(),
          _headerStat('$dirtyCount', 'Kotor', AppTheme.statusDirty),
        ],
      ),
    );
  }

  Widget _headerStat(String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.cormorantGaramond(
              color: color,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.dmSans(
              color: AppTheme.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      height: 36,
      width: 1,
      color: AppTheme.goldPrimary.withOpacity(0.2),
    );
  }

  Widget _buildCategoryFilter() {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        children: [
          // All button
          _filterChip(
            label: 'Semua',
            selected: _selectedCategoryId == null,
            onTap: () {
              setState(() => _selectedCategoryId = null);
              _loadClothes();
            },
          ),
          ..._categories.map((cat) => _filterChip(
                label: '${cat.icon} ${cat.name}',
                selected: _selectedCategoryId == cat.id,
                onTap: () {
                  setState(() => _selectedCategoryId = cat.id);
                  _loadClothes();
                },
              )),
        ],
      ),
    );
  }

  Widget _buildStatusFilter() {
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        children: _statusFilters.map((s) {
          final value = s['value'] as String?; // ignore: unnecessary_cast
          return _filterChip(
            label: s['label'] as String,
            selected: _selectedStatus == value,
            onTap: () {
              setState(() {
                _selectedStatus = value;
                _selectedCategoryId = null;
              });
              _loadClothes();
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.goldPrimary.withOpacity(0.2)
              : AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppTheme.goldPrimary
                : AppTheme.goldPrimary.withOpacity(0.2),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            color:
                selected ? AppTheme.goldPrimary : AppTheme.textSecondary,
            fontSize: 13,
            fontWeight:
                selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppTheme.goldPrimary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.checkroom_outlined,
              size: 52,
              color: AppTheme.goldPrimary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Lemarimu masih kosong',
            style: GoogleFonts.cormorantGaramond(
              color: AppTheme.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Mulai tambahkan pakaian pertamamu',
            style: GoogleFonts.dmSans(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: _openAddClothing,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Tambah Pakaian'),
          ),
        ],
      ),
    );
  }
}
