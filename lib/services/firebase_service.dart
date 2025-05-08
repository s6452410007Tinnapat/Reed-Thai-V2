import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/user_model.dart';
import '../models/shop.dart';
import '../models/chat_message.dart';

class FirebaseService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // สำหรับ initialize Firebase
  static Future<void> initializeFirebase() async {
    await Firebase.initializeApp();
    print('Firebase initialized successfully');
  }

  // สำหรับลงทะเบียนผู้ใช้ใหม่
  static Future<UserCredential> registerUser({
    required String email,
    required String password,
    required String name,
    required String phone,
    required bool isShopOwner,
  }) async {
    try {
      // สร้างผู้ใช้ใน Firebase Authentication
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // สร้างข้อมูลผู้ใช้ใน Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'name': name,
        'email': email,
        'phone': phone,
        'isShopOwner': isShopOwner,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return userCredential;
    } catch (e) {
      print('Error in registerUser: $e');
      rethrow;
    }
  }

  // สำหรับเข้าสู่ระบบ
  static Future<UserCredential> loginUser({
    required String email,
    required String password,
  }) async {
    try {
      print('Attempting to login with email: $email');
      // ลองเข้าสู่ระบบด้วย Firebase Authentication
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      
      print('Login successful for user: ${userCredential.user?.uid}');
      return userCredential;
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException in loginUser: ${e.code} - ${e.message}');
      
      // จัดการข้อผิดพลาดที่เฉพาะเจาะจงมากขึ้น
      switch (e.code) {
        case 'invalid-credential':
          throw Exception('อีเมลหรือรหัสผ่านไม่ถูกต้อง กรุณาตรวจสอบและลองใหม่อีกครั้ง');
        case 'user-not-found':
          throw Exception('ไม่พบบัญชีผู้ใช้นี้ กรุณาตรวจสอบอีเมลหรือลงทะเบียนใหม่');
        case 'wrong-password':
          throw Exception('รหัสผ่านไม่ถูกต้อง กรุณาลองใหม่อีกครั้ง');
        case 'invalid-email':
          throw Exception('รูปแบบอีเมลไม่ถูกต้อง');
        case 'user-disabled':
          throw Exception('บัญชีนี้ถูกระงับการใช้งาน กรุณาติดต่อผู้ดูแลระบบ');
        case 'too-many-requests':
          throw Exception('มีการพยายามเข้าสู่ระบบหลายครั้งเกินไป กรุณาลองใหม่ในภายหลัง');
        default:
          throw Exception('เกิดข้อผิดพลาดในการเข้าสู่ระบบ: ${e.message}');
      }
    } catch (e) {
      print('Unexpected error in loginUser: $e');
      throw Exception('เกิดข้อผิดพลาดที่ไม่คาดคิด กรุณาลองใหม่อีกครั้ง');
    }
  }

  // สำหรับออกจากระบบ
  static Future<void> logoutUser() async {
    try {
      await _auth.signOut();
      // ลบข้อมูลผู้ใช้จาก SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      print('User logged out successfully');
    } catch (e) {
      print('Error in logoutUser: $e');
      rethrow;
    }
  }

  // ตรวจสอบสถานะการเข้าสู่ระบบ
  static bool isLoggedIn() {
    final user = _auth.currentUser;
    print('Current user: ${user?.uid}');
    return user != null;
  }

  // ดึงข้อมูลผู้ใช้ปัจจุบัน
  static Future<UserModel?> getCurrentUser() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        print('Fetching user data for: ${user.uid}');
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
        
        if (userDoc.exists) {
          print('User document found');
          return UserModel.fromFirestore(userDoc);
        } else {
          print('User document not found in Firestore');
          return null;
        }
      }
      print('No current user found');
      return null;
    } catch (e) {
      print('Error in getCurrentUser: $e');
      return null;
    }
  }

  // ดึงข้อมูลร้านพวงหรีดทั้งหมด
  static Future<List<Shop>> getAllShops() async {
    try {
      QuerySnapshot querySnapshot = await _firestore.collection('shops').get();
      return querySnapshot.docs.map((doc) => Shop.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error getting shops: $e');
      return [];
    }
  }

  // เพิ่มร้านพวงหรีดใหม่
  static Future<void> addShop(Shop shop) async {
    try {
      print('Checking user authentication...');
      User? user = _auth.currentUser;
      if (user == null) {
        print('User not authenticated');
        throw Exception('ไม่พบข้อมูลผู้ใช้ กรุณาเข้าสู่ระบบก่อน');
      }
      
      print('Adding shop to Firestore...');
      final docRef = await _firestore.collection('shops').add({
        'name': shop.name,
        'description': shop.description,
        'address': shop.address,
        'phone': shop.phone,
        'imageUrl': shop.imageUrl,
        'latitude': shop.latitude,
        'longitude': shop.longitude,
        'rating': shop.rating,
        'wreathTypes': shop.wreathTypes,
        'galleryImages': shop.galleryImages,
        'priceRange': shop.priceRange,
        'ownerId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      print('Shop added successfully with ID: ${docRef.id}');
      return;
    } catch (e) {
      print('Error in addShop: $e');
      rethrow;
    }
  }

  // อัปเดตข้อมูลร้านพวงหรีด
  static Future<void> updateShop(String shopId, Shop shop) async {
    try {
      print('Checking user authentication for shop update...');
      User? user = _auth.currentUser;
      if (user == null) {
        print('User not authenticated');
        throw Exception('ไม่พบข้อมูลผู้ใช้ กรุณาเข้าสู่ระบบก่อน');
      }
      
      // ตรวจสอบว่าร้านนี้เป็นของผู้ใช้ปัจจุบันหรือไม่
      DocumentSnapshot shopDoc = await _firestore.collection('shops').doc(shopId).get();
      if (!shopDoc.exists) {
        throw Exception('ไม่พบข้อมูลร้านค้า');
      }
      
      Map<String, dynamic> shopData = shopDoc.data() as Map<String, dynamic>;
      if (shopData['ownerId'] != user.uid) {
        throw Exception('คุณไม่มีสิทธิ์แก้ไขร้านค้านี้');
      }
      
      print('Updating shop in Firestore...');
      await _firestore.collection('shops').doc(shopId).update({
        'name': shop.name,
        'description': shop.description,
        'address': shop.address,
        'phone': shop.phone,
        'imageUrl': shop.imageUrl,
        'latitude': shop.latitude,
        'longitude': shop.longitude,
        'wreathTypes': shop.wreathTypes,
        'priceRange': shop.priceRange,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      print('Shop updated successfully with ID: $shopId');
      return;
    } catch (e) {
      print('Error in updateShop: $e');
      rethrow;
    }
  }

  // อัปเดตแกลเลอรีของร้านพวงหรีด
  static Future<void> updateShopGallery(String shopId, List<String> galleryImages) async {
    try {
      print('Checking user authentication for gallery update...');
      User? user = _auth.currentUser;
      if (user == null) {
        print('User not authenticated');
        throw Exception('ไม่พบข้อมูลผู้ใช้ กรุณาเข้าสู่ระบบก่อน');
      }
      
      // ตรวจสอบว่าร้านนี้เป็นของผู้ใช้ปัจจุบันหรือไม่
      DocumentSnapshot shopDoc = await _firestore.collection('shops').doc(shopId).get();
      if (!shopDoc.exists) {
        throw Exception('ไม่พบข้อมูลร้านค้า');
      }
      
      Map<String, dynamic> shopData = shopDoc.data() as Map<String, dynamic>;
      if (shopData['ownerId'] != user.uid) {
        throw Exception('คุณไม่มีสิทธิ์แก้ไขร้านค้านี้');
      }
      
      print('Updating shop gallery in Firestore...');
      await _firestore.collection('shops').doc(shopId).update({
        'galleryImages': galleryImages,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      print('Shop gallery updated successfully with ID: $shopId');
      return;
    } catch (e) {
      print('Error in updateShopGallery: $e');
      rethrow;
    }
  }

  // ดึงร้านพวงหรีดของเจ้าของร้านปัจจุบัน
  static Future<List<Shop>> getMyShops() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        QuerySnapshot querySnapshot = await _firestore
            .collection('shops')
            .where('ownerId', isEqualTo: user.uid)
            .get();
        return querySnapshot.docs.map((doc) => Shop.fromFirestore(doc)).toList();
      }
      return [];
    } catch (e) {
      print('Error getting my shops: $e');
      return [];
    }
  }
  
  // ลบร้านพวงหรีด
  static Future<void> deleteShop(String shopId) async {
    try {
      User? user = _auth.currentUser;
      if (user == null) {
        throw Exception('ไม่พบข้อมูลผู้ใช้ กรุณาเข้าสู่ระบบก่อน');
      }
      
      // ตรวจสอบว่าร้านนี้เป็นของผู้ใช้ปัจจุบันหรือไม่
      DocumentSnapshot shopDoc = await _firestore.collection('shops').doc(shopId).get();
      if (!shopDoc.exists) {
        throw Exception('ไม่พบข้อมูลร้านค้า');
      }
      
      Map<String, dynamic> shopData = shopDoc.data() as Map<String, dynamic>;
      if (shopData['ownerId'] != user.uid) {
        throw Exception('คุณไม่มีสิทธิ์ลบร้านค้านี้');
      }
      
      await _firestore.collection('shops').doc(shopId).delete();
    } catch (e) {
      rethrow;
    }
  }
  
  // ค้นหาร้านพวงหรีด
  static Future<List<Shop>> searchShops({
    String? keyword,
    List<String>? wreathTypes,
    int? minPriceRange,
    int? maxPriceRange,
    double? minRating,
  }) async {
    try {
      // เริ่มต้นด้วยการดึงข้อมูลทั้งหมด
      Query query = _firestore.collection('shops');
      
      // ใช้ตัวกรองแบบไม่เท่ากันกับฟิลด์เดียวเท่านั้น (เลือก priceRange)
      if (minPriceRange != null) {
        query = query.where('priceRange', isGreaterThanOrEqualTo: minPriceRange);
      }
      
      if (maxPriceRange != null) {
        query = query.where('priceRange', isLessThanOrEqualTo: maxPriceRange);
      }
      
      // ดึงข้อมูลตามเงื่อนไขที่กำหนด
      QuerySnapshot querySnapshot = await query.get();
      List<Shop> shops = querySnapshot.docs.map((doc) => Shop.fromFirestore(doc)).toList();
      
      // กรองตามคำค้นหา (ทำหลังจากดึงข้อมูลเนื่องจาก Firestore ไม่รองรับการค้นหาแบบ contains โดยตรง)
      if (keyword != null && keyword.isNotEmpty) {
        final String lowercaseKeyword = keyword.toLowerCase();
        shops = shops.where((shop) {
          return shop.name.toLowerCase().contains(lowercaseKeyword) ||
                 shop.description.toLowerCase().contains(lowercaseKeyword) ||
                 shop.address.toLowerCase().contains(lowercaseKeyword);
        }).toList();
      }
      
      // กรองตามประเภทพวงหรีด
      if (wreathTypes != null && wreathTypes.isNotEmpty) {
        shops = shops.where((shop) {
          // ตรวจสอบว่าร้านมีประเภทพวงหรีดที่ต้องการอย่างน้อย 1 ประเภท
          return shop.wreathTypes.any((type) => wreathTypes.contains(type));
        }).toList();
      }
      
      // กรองตามคะแนนขั้นต่ำ (ทำหลังจากดึงข้อมูลแล้ว)
      if (minRating != null) {
        shops = shops.where((shop) => shop.rating >= minRating).toList();
      }
      
      return shops;
    } catch (e) {
      print('Error searching shops: $e');
      return [];
    }
  }

  // ดึงข้อมูลร้านตาม ID
  static Future<Shop?> getShopById(String shopId) async {
    try {
      DocumentSnapshot shopDoc = await _firestore.collection('shops').doc(shopId).get();
      if (shopDoc.exists) {
        return Shop.fromFirestore(shopDoc);
      }
      return null;
    } catch (e) {
      print('Error getting shop by ID: $e');
      return null;
    }
  }

    // ดึงข้อมูลผู้ใช้ตาม ID
  static Future<UserModel?> getUserById(String userId) async {
    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        return UserModel.fromFirestore(userDoc);
      }
      return null;
    } catch (e) {
      print('Error getting user by ID: $e');
      return null;
    }
  }
}