import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'register_screen.dart';
import 'home_screen.dart';
import '../models/shop.dart';
import '../services/firebase_service.dart';
import '../providers/user_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // ตรวจสอบว่ามีการล็อกอินอยู่แล้วหรือไม่
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (FirebaseService.isLoggedIn()) {
        _navigateToHome();
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _navigateToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        print('Attempting to login with email: ${_emailController.text.trim()}');
        
        // ล็อกอินด้วย Firebase
        await FirebaseService.loginUser(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        
        print('Login successful, loading user data');
        
        // โหลดข้อมูลผู้ใช้
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        await userProvider.loadCurrentUser();
        
        final user = userProvider.user;
        if (user != null) {
          print('User loaded successfully: ${user.name}, isShopOwner: ${user.isShopOwner}');
        } else {
          print('Warning: User data could not be loaded after successful login');
        }
        
        // ไปยังหน้าหลัก
        _navigateToHome();
      } catch (e) {
        print('Error during login: $e');
        setState(() {
          _errorMessage = _getErrorMessage(e.toString());
          _isLoading = false;
        });
      }
    }
  }

  String _getErrorMessage(String error) {
    if (error.contains('อีเมลหรือรหัสผ่านไม่ถูกต้อง')) {
      return 'อีเมลหรือรหัสผ่านไม่ถูกต้อง กรุณาตรวจสอบและลองใหม่อีกครั้ง';
    } else if (error.contains('user-not-found')) {
      return 'ไม่พบบัญชีผู้ใช้นี้';
    } else if (error.contains('wrong-password')) {
      return 'รหัสผ่านไม่ถูกต้อง';
    } else if (error.contains('invalid-email')) {
      return 'รูปแบบอีเมลไม่ถูกต้อง';
    } else if (error.contains('user-disabled')) {
      return 'บัญชีนี้ถูกระงับการใช้งาน';
    } else if (error.contains('too-many-requests')) {
      return 'มีการพยายามเข้าสู่ระบบหลายครั้งเกินไป กรุณาลองใหม่ในภายหลัง';
    } else if (error.contains('invalid-credential')) {
      return 'ข้อมูลการเข้าสู่ระบบไม่ถูกต้อง กรุณาตรวจสอบอีเมลและรหัสผ่าน';
    } else {
      return 'เกิดข้อผิดพลาด: $error';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 60),
                  Image.asset(
                    Shop.defaultAvatarPath,
                    height: 190,
                    errorBuilder: (context, error, stackTrace) {
                      // แสดงไอคอนแทนเมื่อไม่พบรูปภาพ
                      return Container(
                        height: 120,
                        width: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person,
                          size: 80,
                          color: Colors.grey,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'ยินดีต้อนรับ',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'เข้าสู่ระบบเพื่อใช้งานแอปพวงรีด',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade800),
                      ),
                    ),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'อีเมล',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'กรุณากรอกอีเมล';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'รหัสผ่าน',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'กรุณากรอกรหัสผ่าน';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        // ฟังก์ชันลืมรหัสผ่าน
                      },
                      child: const Text('ลืมรหัสผ่าน?'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'เข้าสู่ระบบ',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('ยังไม่มีบัญชี?'),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const RegisterScreen(),
                            ),
                          );
                        },
                        child: const Text('สมัครสมาชิก'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // ยังคงเก็บปุ่มเข้าสู่ระบบแบบทดสอบไว้เผื่อกรณีที่ Firebase มีปัญหา
                //   OutlinedButton(
                //     onPressed: () {
                //       Navigator.pushReplacement(
                //         context,
                //         MaterialPageRoute(builder: (context) => const HomeScreen()),
                //       );
                //     },
                //     style: OutlinedButton.styleFrom(
                //       padding: const EdgeInsets.symmetric(vertical: 16),
                //     ),
                //     child: const Text('เข้าสู่ระบบแบบทดสอบ (ไม่ต้องล็อกอิน)'),
                //   ),
                 ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
