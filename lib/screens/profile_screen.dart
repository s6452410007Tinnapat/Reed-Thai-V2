import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'login_screen.dart';
import '../models/shop.dart';
import '../providers/user_provider.dart';
import '../services/firebase_service.dart';
import 'add_shop_screen.dart';
import 'my_shops_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        final user = userProvider.user;
        
        // ถ้ายังไม่มีข้อมูลผู้ใช้ ให้โหลดข้อมูล
        if (user == null && !userProvider.isLoading) {
          userProvider.loadCurrentUser();
          return const Center(child: CircularProgressIndicator());
        }
        
        // ถ้ากำลังโหลดข้อมูล
        if (userProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        
        // ถ้าไม่มีข้อมูลผู้ใช้ (ไม่ได้ล็อกอิน)
        if (user == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('กรุณาเข้าสู่ระบบเพื่อดูข้อมูลโปรไฟล์'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                    );
                  },
                  child: const Text('เข้าสู่ระบบ'),
                ),
              ],
            ),
          );
        }
        
        // แสดงข้อมูลผู้ใช้
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 16),
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: user.profileImageUrl != null
                      ? NetworkImage(user.profileImageUrl!)
                      : null,
                  child: user.profileImageUrl == null
                      ? const Icon(Icons.person, size: 50, color: Colors.grey)
                      : null,
                ),
                const SizedBox(height: 16),
                Text(
                  user.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.isShopOwner ? 'เจ้าของร้าน' : 'ลูกค้า',
                  style: TextStyle(
                    color: user.isShopOwner ? Colors.blueGrey : Colors.blue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(),
                _buildProfileItem(Icons.email, 'อีเมล', user.email),
                _buildProfileItem(Icons.phone, 'เบอร์โทรศัพท์', user.phone),
                const Divider(),
                if (user.isShopOwner) ...[
                  _buildMenuButton(
                    context,
                    Icons.store,
                    'จัดการร้านค้าของฉัน',
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MyShopsScreen(),
                        ),
                      );
                    },
                  ),
                  _buildMenuButton(
                    context,
                    Icons.add_circle,
                    'เพิ่มร้านพวงหรีดใหม่',
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddShopScreen(
                            onShopAdded: () {
                              // รีเฟรชข้อมูลหลังจากเพิ่มร้านค้า
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('เพิ่มร้านพวงหรีดสำเร็จ')),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ],
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () async {
                    await FirebaseService.logoutUser();
                    Provider.of<UserProvider>(context, listen: false).clearUser();
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                    );
                  },
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: const Text(
                    'ออกจากระบบ',
                    style: TextStyle(color: Colors.red),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMenuButton(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onPressed,
  ) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onPressed,
    );
  }
}
