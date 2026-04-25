import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../db/database_helper.dart';
import '../models/outfit_model.dart';
import '../models/clothing_model.dart';
import '../models/category_model.dart';
import '../widgets/outfit_card.dart';
import '../services/notification_service.dart';
import '../services/firestore_service.dart';

class OutfitScreen extends StatefulWidget {
  final String userId;
  const OutfitScreen({super.key, required this.userId});

  @override
  State<OutfitScreen> createState() => _OutfitScreenState();
}

class _OutfitScreenState extends State<OutfitScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<OutfitModel> _outfits = [];
  Map<int, List<Map<String, dynamic>>> _outfitItems = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOutfits();
  }

  Future<void> _loadOutfits() async {
    setState(() => _isLoading = true);
    final outfits = await DatabaseHelper.instance.getAllOutfits(widget.userId);
    final Map<int, List<Map<String, dynamic>>> itemsMap = {};
    for (final o in outfits) {
      if (o.id != null) {
        itemsMap[o.id!] =
            await DatabaseHelper.instance.getOutfitItems(o.id!);
      }
    }
    if (mounted) {
      setState(() {
        _outfits = outfits;
        _outfitItems = itemsMap;
        _isLoading = false;
      });
    }
  }

  Future<void> _setOotd(OutfitModel outfit) async {
    // Update lokal SQLite
    await DatabaseHelper.instance.setOotd(outfit.id!, widget.userId);
    // Sync ke Firestore jika ada firestoreId
    if (outfit.firestoreId != null) {
      try {
        await FirestoreService.instance.setOotd(outfit.firestoreId!);
      } catch (e) {
        debugPrint('Firestore OOTD sync failed: $e');
      }
    }
    await NotificationService.instance.showOotdSet(outfit.name);
    _loadOutfits();
  }

  Future<void> _deleteOutfit(int id, String name, String? firestoreId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Hapus Outfit',
          style: GoogleFonts.cormorantGaramond(
            color: AppTheme.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text('Hapus outfit "$name"?',
            style: GoogleFonts.dmSans(color: AppTheme.textSecondary)),
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
                foregroundColor: Colors.white),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      // 1. Hapus dari SQLite lokal
      await DatabaseHelper.instance.deleteOutfit(id);

      // 2. Sync hapus dari Firestore
      if (firestoreId != null) {
        try {
          await FirestoreService.instance.deleteOutfit(firestoreId);
        } catch (e) {
          debugPrint('Firestore deleteOutfit failed: $e');
        }
      }

      _loadOutfits();
    }
  }

  void _openBuilder() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _OutfitBuilderSheet(
        userId: widget.userId,
        onSaved: () {
          Navigator.pop(ctx);
          _loadOutfits();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadOutfits,
        color: AppTheme.goldPrimary,
        backgroundColor: AppTheme.surfaceColor,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.goldPrimary),
              )
            : _outfits.isEmpty
                ? _buildEmptyState()
                : ListView(
                    padding:
                        const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    children: _outfits.map((outfit) {
                      final items = _outfitItems[outfit.id] ?? [];
                      return OutfitCard(
                        outfit: outfit,
                        items: items,
                        onSetOotd: outfit.isOotd
                            ? null
                            : () => _setOotd(outfit),
                        onDelete: () =>
                            _deleteOutfit(outfit.id!, outfit.name, outfit.firestoreId),
                      );
                    }).toList(),
                  ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openBuilder,
        backgroundColor: AppTheme.goldPrimary,
        foregroundColor: AppTheme.backgroundDark,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'Buat Outfit',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
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
            child: const Icon(Icons.style_outlined,
                size: 52, color: AppTheme.goldPrimary),
          ),
          const SizedBox(height: 20),
          Text(
            'Belum ada outfit',
            style: GoogleFonts.cormorantGaramond(
              color: AppTheme.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Rakit outfit dari pakaian di lemarimu',
            style:
                GoogleFonts.dmSans(color: AppTheme.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: _openBuilder,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Buat Outfit'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// OUTFIT BUILDER SHEET
// ============================================================
class _OutfitBuilderSheet extends StatefulWidget {
  final String userId;
  final VoidCallback onSaved;

  const _OutfitBuilderSheet({
    required this.userId,
    required this.onSaved,
  });

  @override
  State<_OutfitBuilderSheet> createState() => _OutfitBuilderSheetState();
}

class _OutfitBuilderSheetState extends State<_OutfitBuilderSheet> {
  final _nameController = TextEditingController();
  String _selectedOccasion = 'casual';
  List<ClothingModel> _allClothes = [];
  List<CategoryModel> _categories = [];

  // Selected per kategori — key = nama kategori (sesuai DB seed)
  // Semua opsional, minimal 1 harus dipilih
  final Map<String, ClothingModel?> _selected = {
    'Atasan':    null,
    'Bawahan':   null,
    'Dress':     null,
    'Outerwear': null,
    'Sepatu':    null,
    'Aksesoris': null,
  };

  bool _isLoading = false;
  bool _isLoadingData = true;

  final _occasions = [
    {'value': 'casual', 'label': '😎 Casual'},
    {'value': 'formal', 'label': '👔 Formal'},
    {'value': 'sport', 'label': '🏃 Sport'},
    {'value': 'hangout', 'label': '🎉 Hangout'},
  ];

  // Role = 1:1 dengan nama kategori di DB
  final _roles = [
    {'value': 'Atasan',    'label': 'Atasan',    'icon': '👕'},
    {'value': 'Bawahan',   'label': 'Bawahan',   'icon': '👖'},
    {'value': 'Dress',     'label': 'Dress',     'icon': '👗'},
    {'value': 'Outerwear', 'label': 'Outerwear', 'icon': '🧥'},
    {'value': 'Sepatu',    'label': 'Sepatu',    'icon': '👟'},
    {'value': 'Aksesoris', 'label': 'Aksesoris', 'icon': '⌚'},
  ];

  /// Filter pakaian berdasarkan nama kategori (1:1 match)
  List<ClothingModel> _clothesForRole(String categoryName) {
    return _allClothes.where((item) {
      final cat = _categories.firstWhere(
        (c) => c.id == item.categoryId,
        orElse: () => CategoryModel(name: '', icon: ''),
      );
      return cat.name == categoryName;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final clothesRaw =
        await DatabaseHelper.instance.getAllClothing(widget.userId);
    final cats = await DatabaseHelper.instance.getAllCategories();
    if (mounted) {
      setState(() {
        _allClothes =
            clothesRaw.map((m) => ClothingModel.fromMap(m)).toList();
        _categories = cats;
        _isLoadingData = false;
      });
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Nama outfit wajib diisi'),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }
    final selectedItems = _selected.entries
        .where((e) => e.value != null)
        .map((e) => {
              'clothingId': e.value!.id!,
              'role': e.key,
            })
        .toList();
    if (selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Pilih minimal 1 pakaian'),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }
    setState(() => _isLoading = true);
    final outfit = OutfitModel(
      name: name,
      occasion: _selectedOccasion,
      userId: widget.userId,
      createdAt: DateTime.now(),
    );

    // 1. Simpan ke SQLite lokal — dapat local ID
    final localId =
        await DatabaseHelper.instance.insertOutfit(outfit, selectedItems);

    // 2. Sync ke Firestore — dapat firestoreId, simpan balik ke SQLite
    try {
      final firestoreId = await FirestoreService.instance.addOutfit(outfit);
      await DatabaseHelper.instance
          .updateOutfitFirestoreId(localId, firestoreId);
    } catch (e) {
      debugPrint('Firestore outfit sync failed: $e');
    }

    if (mounted) widget.onSaved();
  }

  void _pickClothing(String role) {
    final filtered = _clothesForRole(role);
    final roleLabel = _roles.firstWhere((r) => r['value'] == role)['label'];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (ctx, scrollCtrl) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textSecondary.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text(
                'Pilih $roleLabel',
                style: GoogleFonts.cormorantGaramond(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                '${filtered.length} item tersedia',
                style: GoogleFonts.dmSans(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '🕵️',
                            style: const TextStyle(fontSize: 36),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Tidak ada $roleLabel di lemarimu',
                            style: GoogleFonts.dmSans(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Tambah dulu di tab Wardrobe',
                            style: GoogleFonts.dmSans(
                              color: AppTheme.textSecondary.withOpacity(0.6),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                          Divider(color: AppTheme.goldPrimary.withOpacity(0.1)),
                      itemBuilder: (ctx2, i) {
                        final item = filtered[i];
                        final isSelected = _selected[role]?.id == item.id;
                        final cat = _categories.firstWhere(
                          (c) => c.id == item.categoryId,
                          orElse: () =>
                              CategoryModel(name: '', icon: '👕'),
                        );
                        return ListTile(
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppTheme.cardColor,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: AppTheme.goldPrimary
                                      .withOpacity(0.2)),
                            ),
                            child: Center(
                              child: Text(cat.icon,
                                  style: const TextStyle(fontSize: 20)),
                            ),
                          ),
                          title: Text(
                            item.name,
                            style: GoogleFonts.dmSans(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w500),
                          ),
                          subtitle: item.brand.isNotEmpty
                              ? Text(item.brand,
                                  style: GoogleFonts.dmSans(
                                      color: AppTheme.textSecondary,
                                      fontSize: 12))
                              : null,
                          trailing: isSelected
                              ? const Icon(Icons.check_circle_rounded,
                                  color: AppTheme.goldPrimary)
                              : const Icon(Icons.radio_button_unchecked,
                                  color: AppTheme.textSecondary),
                          onTap: () {
                            setState(() {
                              _selected[role] = isSelected ? null : item;
                            });
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (ctx, scrollCtrl) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textSecondary.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Row(
                children: [
                  Text(
                    'Outfit Builder',
                    style: GoogleFonts.cormorantGaramond(
                      color: AppTheme.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: AppTheme.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoadingData
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppTheme.goldPrimary))
                  : ListView(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      children: [
                        // Name
                        TextField(
                          controller: _nameController,
                          style:
                              const TextStyle(color: AppTheme.textPrimary),
                          decoration: const InputDecoration(
                            labelText: 'Nama Outfit',
                            prefixIcon:
                                Icon(Icons.label_outline_rounded),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Occasion
                        _sheetSectionLabel('OCCASION'),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _occasions.map((occ) {
                            final selected =
                                _selectedOccasion == occ['value'];
                            return GestureDetector(
                              onTap: () => setState(
                                  () => _selectedOccasion =
                                      occ['value'] as String),
                              child: AnimatedContainer(
                                duration:
                                    const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? AppTheme.goldPrimary
                                          .withOpacity(0.2)
                                      : AppTheme.cardColor,
                                  borderRadius:
                                      BorderRadius.circular(20),
                                  border: Border.all(
                                    color: selected
                                        ? AppTheme.goldPrimary
                                        : AppTheme.goldPrimary
                                            .withOpacity(0.2),
                                    width: selected ? 1.5 : 1,
                                  ),
                                ),
                                child: Text(
                                  occ['label'] as String,
                                  style: GoogleFonts.dmSans(
                                    color: selected
                                        ? AppTheme.goldPrimary
                                        : AppTheme.textSecondary,
                                    fontSize: 13,
                                    fontWeight: selected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),

                        // Role selectors
                        Row(
                          children: [
                            _sheetSectionLabel('PILIH PAKAIAN'),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.textSecondary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'semua opsional • min. 1',
                                style: GoogleFonts.dmSans(
                                  color: AppTheme.textSecondary,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ..._roles.map((role) {
                          final roleVal = role['value'] as String;
                          final selected = _selected[roleVal];
                          final available = _clothesForRole(roleVal).length;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: AppTheme.cardColor,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: selected != null
                                    ? AppTheme.goldPrimary.withOpacity(0.5)
                                    : AppTheme.goldPrimary.withOpacity(0.15),
                              ),
                            ),
                            child: Row(
                              children: [
                                // Tap area (buka picker)
                                Expanded(
                                  child: GestureDetector(
                                    onTap: available == 0
                                        ? null
                                        : () => _pickClothing(roleVal),
                                    child: Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Row(
                                        children: [
                                          Text(
                                            role['icon'] as String,
                                            style: TextStyle(
                                              fontSize: 22,
                                              color: available == 0
                                                  ? AppTheme.textSecondary
                                                      .withOpacity(0.3)
                                                  : null,
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Text(
                                                      role['label'] as String,
                                                      style: GoogleFonts.dmSans(
                                                        color: AppTheme
                                                            .textSecondary,
                                                        fontSize: 11,
                                                        letterSpacing: 0.5,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      available == 0
                                                          ? '(tidak ada di lemari)'
                                                          : '($available item)',
                                                      style: GoogleFonts.dmSans(
                                                        color: available == 0
                                                            ? AppTheme
                                                                .errorColor
                                                                .withOpacity(
                                                                    0.7)
                                                            : AppTheme
                                                                .textSecondary
                                                                .withOpacity(
                                                                    0.5),
                                                        fontSize: 10,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                Text(
                                                  selected?.name ??
                                                      (available == 0
                                                          ? 'Tambah dulu di Wardrobe'
                                                          : 'Ketuk untuk pilih'),
                                                  style: GoogleFonts.dmSans(
                                                    color: selected != null
                                                        ? AppTheme.textPrimary
                                                        : AppTheme.textSecondary
                                                            .withOpacity(0.5),
                                                    fontSize: 14,
                                                    fontWeight: selected != null
                                                        ? FontWeight.w600
                                                        : FontWeight.w400,
                                                    fontStyle: selected == null
                                                        ? FontStyle.italic
                                                        : FontStyle.normal,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Icon(
                                            selected != null
                                                ? Icons.check_circle_rounded
                                                : available == 0
                                                    ? Icons.block_rounded
                                                    : Icons
                                                        .add_circle_outline_rounded,
                                            color: selected != null
                                                ? AppTheme.goldPrimary
                                                : available == 0
                                                    ? AppTheme.textSecondary
                                                        .withOpacity(0.3)
                                                    : AppTheme.textSecondary,
                                            size: 22,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                // Clear button — hanya muncul kalau ada yang dipilih
                                if (selected != null)
                                  GestureDetector(
                                    onTap: () => setState(
                                        () => _selected[roleVal] = null),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 14),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          left: BorderSide(
                                            color: AppTheme.goldPrimary
                                                .withOpacity(0.15),
                                          ),
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.close_rounded,
                                        size: 18,
                                        color: AppTheme.textSecondary
                                            .withOpacity(0.7),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }),

                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _save,
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppTheme.backgroundDark,
                                    ),
                                  )
                                : const Icon(Icons.check_rounded,
                                    size: 20),
                            label: Text(
                              _isLoading
                                  ? 'Menyimpan...'
                                  : 'Simpan Outfit',
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sheetSectionLabel(String label) {
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
