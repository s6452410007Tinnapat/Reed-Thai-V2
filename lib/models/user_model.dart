import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final bool isShopOwner;
  final String? profileImageUrl;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.isShopOwner,
    this.profileImageUrl,
  });

  // แปลงข้อมูลจาก Firestore เป็น UserModel
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      isShopOwner: data['isShopOwner'] ?? false,
      profileImageUrl: data['profileImageUrl'],
    );
  }

  // แปลงข้อมูลจาก UserModel เป็น Map สำหรับบันทึกลง Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'isShopOwner': isShopOwner,
      'profileImageUrl': profileImageUrl,
    };
  }
}
