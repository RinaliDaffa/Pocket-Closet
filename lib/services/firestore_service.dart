import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/clothing_model.dart';
import '../models/outfit_model.dart';

class FirestoreService {
  static final FirestoreService instance = FirestoreService._init();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  FirestoreService._init();

  /// Ambil userId dari auth — pastikan user sudah login
  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  /// Referensi subcollection clothing milik user ini
  CollectionReference get _clothingCol =>
      _db.collection('users').doc(_uid).collection('clothing_items');

  /// Referensi subcollection outfits milik user ini
  CollectionReference get _outfitsCol =>
      _db.collection('users').doc(_uid).collection('outfits');

  // ========================
  // CLOTHING
  // ========================
  Future<String> addClothing(ClothingModel item) async {
    final data = item.toFirestore();
    final ref = await _clothingCol.add(data);
    return ref.id;
  }

  Future<void> updateClothing(String firestoreId, ClothingModel item) async {
    await _clothingCol.doc(firestoreId).update(item.toFirestore());
  }

  Future<void> updateClothingStatus(String firestoreId, String status) async {
    await _clothingCol.doc(firestoreId).update({'status': status});
  }

  Future<void> deleteClothing(String firestoreId) async {
    await _clothingCol.doc(firestoreId).delete();
  }

  // ========================
  // OUTFITS
  // ========================
  Future<String> addOutfit(OutfitModel outfit) async {
    final ref = await _outfitsCol.add(outfit.toFirestore());
    return ref.id;
  }

  Future<void> deleteOutfit(String firestoreId) async {
    await _outfitsCol.doc(firestoreId).delete();
  }

  Future<void> setOotd(String firestoreId) async {
    await _outfitsCol.doc(firestoreId).update({'isOotd': true});
  }
}