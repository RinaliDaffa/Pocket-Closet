import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../db/database_helper.dart';
import '../models/clothing_model.dart';
import '../models/category_model.dart';
import '../services/notification_service.dart';
import '../services/firestore_service.dart';

class AddClothingScreen extends StatefulWidget {
  final String userId;
  const AddClothingScreen({super.key, required this.userId});

  @override
  State<AddClothingScreen> createState() => _AddClothingScreenState();
}

class _AddClothingScreenState extends State<AddClothingScreen> {
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _colorController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  List<CategoryModel> _categories = [];
  CategoryModel? _selectedCategory;
  String _selectedStatus = 'clean';
  String? _imagePath;
  bool _isLoading = false;

  final _statuses = [
    {'value': 'clean', 'label': 'Bersih', 'icon': Icons.check_circle_rounded, 'color': AppTheme.statusClean},
    {'value': 'dirty', 'label': 'Kotor', 'icon': Icons.warning_amber_rounded, 'color': AppTheme.statusDirty},
    {'value': 'laundry', 'label': 'Laundry', 'icon': Icons.local_laundry_service_rounded, 'color': AppTheme.statusLaundry},
  ];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final cats = await DatabaseHelper.instance.getAllCategories();
    if (mounted) {
      setState(() {
        _categories = cats;
        if (cats.isNotEmpty) _selectedCategory = cats.first;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (picked != null && mounted) {
      setState(() => _imagePath = picked.path);
    }
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textSecondary.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Pilih Foto',
              style: GoogleFonts.cormorantGaramond(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            _imageOptionTile(
              icon: Icons.camera_alt_rounded,
              label: 'Foto Langsung',
              subtitle: 'Gunakan kamera',
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            const SizedBox(height: 12),
            _imageOptionTile(
              icon: Icons.photo_library_rounded,
              label: 'Pilih dari Galeri',
              subtitle: 'Dari penyimpanan',
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _imageOptionTile({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.goldPrimary.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.goldPrimary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppTheme.goldPrimary, size: 22),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.dmSans(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.dmSans(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const Spacer(),
            const Icon(Icons.chevron_right_rounded,
                color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      _showSnack('Pilih kategori pakaian');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final item = ClothingModel(
        name: _nameController.text.trim(),
        brand: _brandController.text.trim(),
        color: _colorController.text.trim(),
        imagePath: _imagePath,
        categoryId: _selectedCategory!.id!,
        status: _selectedStatus,
        userId: widget.userId,
        createdAt: DateTime.now(),
      );

      // 1. Simpan ke SQLite (local)
      final localId = await DatabaseHelper.instance.insertClothing(item);

      // 2. Sync ke Firestore (cloud)
      try {
        final firestoreId = await FirestoreService.instance.addClothing(item);
        await DatabaseHelper.instance.updateFirestoreId(localId, firestoreId);
      } catch (firestoreErr) {
        // Firestore error tidak blok local save — tampilkan warning
        debugPrint('Firestore sync failed: $firestoreErr');
      }

      // 3. Notifikasi
      await NotificationService.instance
          .showClothingAdded(_nameController.text.trim());

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showSnack('Gagal menyimpan: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tambah Pakaian'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _save,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.goldPrimary),
                  )
                : Text(
                    'Simpan',
                    style: GoogleFonts.dmSans(
                      color: AppTheme.goldPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image picker
              GestureDetector(
                onTap: _showImageOptions,
                child: Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.goldPrimary.withOpacity(0.3),
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: _imagePath != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(19),
                          child: Image.file(
                            File(_imagePath!),
                            fit: BoxFit.cover,
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.goldPrimary.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.add_a_photo_rounded,
                                color: AppTheme.goldPrimary,
                                size: 32,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Tambahkan Foto',
                              style: GoogleFonts.dmSans(
                                color: AppTheme.goldPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Kamera atau galeri',
                              style: GoogleFonts.dmSans(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              if (_imagePath != null) ...[
                const SizedBox(height: 8),
                Center(
                  child: TextButton.icon(
                    onPressed: () => setState(() => _imagePath = null),
                    icon: const Icon(Icons.close_rounded,
                        size: 16, color: AppTheme.textSecondary),
                    label: Text(
                      'Hapus foto',
                      style: GoogleFonts.dmSans(
                          color: AppTheme.textSecondary, fontSize: 12),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),
              _sectionLabel('DETAIL PAKAIAN'),
              const SizedBox(height: 12),

              // Name
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Nama Pakaian *',
                  prefixIcon: Icon(Icons.label_outline_rounded),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Nama wajib diisi' : null,
              ),
              const SizedBox(height: 14),

              // Brand
              TextFormField(
                controller: _brandController,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Brand (opsional)',
                  prefixIcon: Icon(Icons.storefront_outlined),
                ),
              ),
              const SizedBox(height: 14),

              // Color
              TextFormField(
                controller: _colorController,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Warna (opsional)',
                  prefixIcon: Icon(Icons.palette_outlined),
                ),
              ),
              const SizedBox(height: 24),

              _sectionLabel('KATEGORI'),
              const SizedBox(height: 12),

              // Category chips
              if (_categories.isEmpty)
                const Center(child: CircularProgressIndicator())
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _categories.map((cat) {
                    final selected = _selectedCategory?.id == cat.id;
                    return GestureDetector(
                      onTap: () =>
                          setState(() => _selectedCategory = cat),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
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
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(cat.icon,
                                style: const TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            Text(
                              cat.name,
                              style: GoogleFonts.dmSans(
                                color: selected
                                    ? AppTheme.goldPrimary
                                    : AppTheme.textPrimary,
                                fontSize: 13,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

              const SizedBox(height: 24),
              _sectionLabel('STATUS PAKAIAN'),
              const SizedBox(height: 12),

              // Status selection
              Row(
                children: _statuses.map((s) {
                  final selected = _selectedStatus == s['value'] as String;
                  final color = s['color'] as Color;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _selectedStatus = s['value'] as String),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: selected
                              ? color.withOpacity(0.2)
                              : AppTheme.surfaceColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? color
                                : AppTheme.goldPrimary.withOpacity(0.2),
                            width: selected ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              s['icon'] as IconData,
                              color: selected ? color : AppTheme.textSecondary,
                              size: 20,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              s['label'] as String,
                              style: GoogleFonts.dmSans(
                                color: selected ? color : AppTheme.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 40),

              // Save button
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
                      : const Icon(Icons.add_rounded, size: 20),
                  label: Text(_isLoading ? 'Menyimpan...' : 'Tambah ke Lemari'),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
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
