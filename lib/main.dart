import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'providers/user_provider.dart';

// เปิดการ import Firebase กลับมา
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';
import 'services/firebase_service.dart';
import 'services/cloudinary_service.dart';

void main() async {
  // เปิดการเริ่มต้น Firebase กลับมา
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // ตรวจสอบการเชื่อมต่อ Cloudinary
  try {
    print('Checking Cloudinary configuration...');
    if (CloudinaryService.cloudName == 'dxyattaiz' || 
        CloudinaryService.uploadPreset == 'Reed Images') {
      print('Warning: Cloudinary is not properly configured. Please update cloudName and uploadPreset in CloudinaryService.');
    } else {
      print('Cloudinary configuration looks good.');
    }
  } catch (e) {
    print('Error checking Cloudinary configuration: $e');
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
      child: MaterialApp(
        title: 'แอปพวงรีด',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blueGrey,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          fontFamily: 'Kanit',
        ),
        home: const LoginScreen(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/home': (context) => const HomeScreen(),
          '/profile': (context) => const ProfileScreen(),
        },
      ),
    );
  }
}
