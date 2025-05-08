import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/firebase_service.dart';

class UserProvider extends ChangeNotifier {
  UserModel? _user;
  bool _isLoading = false;
  String? _error;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ตรวจสอบและโหลดข้อมูลผู้ใช้ปัจจุบัน
  Future<void> loadCurrentUser() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      print('UserProvider: Loading current user data');
      _user = await FirebaseService.getCurrentUser();
      
      if (_user != null) {
        print('UserProvider: User loaded successfully - ${_user!.name}');
      } else {
        print('UserProvider: No user data found');
        _error = 'ไม่พบข้อมูลผู้ใช้';
      }
    } catch (e) {
      print('UserProvider: Error loading user: $e');
      _error = 'เกิดข้อผิดพลาดในการโหลดข้อมูลผู้ใช้: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ล้างข้อมูลผู้ใช้เมื่อออกจากระบบ
  void clearUser() {
    print('UserProvider: Clearing user data');
    _user = null;
    _error = null;
    notifyListeners();
  }
}
