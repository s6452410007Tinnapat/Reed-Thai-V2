import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/shop.dart';
import 'package:url_launcher/url_launcher.dart';
import 'gallery_view_screen.dart';
import 'gallery_manager_screen.dart';
import '../services/firebase_service.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/chat_service.dart';
import 'chat_screen.dart';

class ShopDetailScreen extends StatefulWidget {
  final Shop shop;

  const ShopDetailScreen({Key? key, required this.shop}) : super(key: key);

  @override
  _ShopDetailScreenState createState() => _ShopDetailScreenState();
}

class _ShopDetailScreenState extends State<ShopDetailScreen> {
  late Shop _shop;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _shop = widget.shop;
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    await launchUrl(launchUri);
  }

    // ฟังก์ชันสำหรับเปิดหน้าแชทกับร้านค้า
  Future<void> _openChatWithShop() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currentUser = userProvider.user;
    
    if (currentUser == null) {
      // ถ้ายังไม่ได้เข้าสู่ระบบ ให้แสดงข้อความแจ้งเตือน
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเข้าสู่ระบบก่อนเริ่มการสนทนา')),
      );
      
      // ถามว่าต้องการไปหน้าเข้าสู่ระบบหรือไม่
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('ต้องเข้าสู่ระบบก่อน'),
          content: const Text('คุณต้องเข้าสู่ระบบก่อนจึงจะสามารถแชทกับผู้ขายได้'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/login');
              },
              child: const Text('เข้าสู่ระบบ'),
            ),
          ],
        ),
      );
      return;
    }
    
    // ถ้าผู้ใช้เป็นเจ้าของร้านนี้ ไม่อนุญาตให้แชทกับตัวเอง
    if (_isShopOwner(context)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('คุณไม่สามารถแชทกับร้านของตัวเองได้')),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // สร้างหรือดึงห้องแชท
      final chatRoomId = await ChatService.createOrGetChatRoom(_shop, currentUser);
      
      if (mounted) {
        // เปิดหน้าแชท
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatRoomId: chatRoomId,
              shop: _shop,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ฟังก์ชันสำหรับตรวจสอบว่าผู้ใช้ปัจจุบันเป็นเจ้าของร้านนี้หรือไม่
  bool _isShopOwner(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currentUser = userProvider.user;
    
    if (currentUser == null) return false;
    
    return _shop.ownerId == currentUser.id;
  }

  // ฟังก์ชันสำหรับเปิดหน้าจัดการแกลเลอรี
  Future<void> _openGalleryManager() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GalleryManagerScreen(
          shop: _shop,
          onGalleryUpdated: () async {
            setState(() {
              _isLoading = true;
            });
            
            try {
              // โหลดข้อมูลร้านใหม่
              final updatedShop = await FirebaseService.getShopById(_shop.id);
              if (updatedShop != null) {
                setState(() {
                  _shop = updatedShop;
                  _isLoading = false;
                });
              }
            } catch (e) {
              print('Error refreshing shop data: $e');
              setState(() {
                _isLoading = false;
              });
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('ไม่สามารถโหลดข้อมูลร้านได้: $e')),
              );
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isOwner = _isShopOwner(context);
    
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 200,
                  pinned: true,
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(_shop.name),
                    background: _shop.imageUrl != null
                      ? Image.network(
                          _shop.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[300],
                              child: const Icon(
                                Icons.store,
                                size: 80,
                                color: Colors.grey,
                              ),
                            );
                          },
                        )
                      : Container(
                          color: Colors.grey[300],
                          child: const Icon(
                            Icons.store,
                            size: 80,
                            color: Colors.grey,
                          ),
                        ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildListDelegate([
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.star, color: Colors.amber),
                              Text(' ${_shop.rating}'),
                              const SizedBox(width: 16),
                              Text('฿' * _shop.priceRange),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'รายละเอียดร้าน',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(_shop.description),
                          const SizedBox(height: 16),
                          const Text(
                            'ที่อยู่',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.location_on, color: Colors.red),
                              const SizedBox(width: 8),
                              Expanded(child: Text(_shop.address)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // เพิ่มแผนที่แสดงตำแหน่งร้าน
                          Container(
                            height: 200,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: FlutterMap(
                                options: MapOptions(
                                  center: LatLng(_shop.latitude, _shop.longitude),
                                  zoom: 15.0,
                                ),
                                children: [
                                  TileLayer(
                                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                    subdomains: const ['a', 'b', 'c'],
                                  ),
                                  MarkerLayer(
                                    markers: [
                                      Marker(
                                        width: 80,
                                        height: 80,
                                        point: LatLng(_shop.latitude, _shop.longitude),
                                        builder: (context) => const Icon(
                                          Icons.location_pin,
                                          color: Colors.red,
                                          size: 40,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'ติดต่อ',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Card(
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Colors.blueGrey,
                                child: Icon(Icons.phone, color: Colors.white),
                              ),
                              title: Text(_shop.phone),
                              subtitle: const Text('แตะเพื่อโทรหาร้าน'),
                              trailing: ElevatedButton(
                                onPressed: () => _makePhoneCall(_shop.phone),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueGrey,
                                ),
                                child: const Text('โทร'),
                              ),
                              onTap: () => _makePhoneCall(_shop.phone),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'ประเภทพวงรีด',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: _shop.wreathTypes.map((type) {
                              return Chip(
                                label: Text(type),
                                backgroundColor: Colors.blueGrey.shade100,
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'แกลเลอรี',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Row(
                                children: [
                                  if (isOwner)
                                    TextButton.icon(
                                      onPressed: _openGalleryManager,
                                      icon: const Icon(Icons.edit),
                                      label: const Text('จัดการ'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.blueGrey,
                                      ),
                                    ),
                                  if (_shop.galleryImages.isNotEmpty)
                                    TextButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => GalleryViewScreen(
                                              images: _shop.galleryImages,
                                              shopName: _shop.name,
                                            ),
                                          ),
                                        );
                                      },
                                      child: const Text('ดูทั้งหมด'),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _shop.galleryImages.isEmpty
                              ? GestureDetector(
                                  onTap: isOwner ? _openGalleryManager : null,
                                  child: Container(
                                    height: 120,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(8),
                                      border: isOwner
                                          ? Border.all(color: Colors.blueGrey, width: 2, style: BorderStyle.solid)
                                          : null,
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        if (isOwner) ...[
                                          const Icon(Icons.add_photo_alternate, color: Colors.blueGrey, size: 32),
                                          const SizedBox(height: 8),
                                          const Text(
                                            'แตะเพื่อเพิ่มรูปภาพ',
                                            style: TextStyle(color: Colors.blueGrey),
                                          ),
                                        ] else
                                          const Text('ไม่มีรูปภาพในแกลเลอรี'),
                                      ],
                                    ),
                                  ),
                                )
                              : SizedBox(
                                  height: 120,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _shop.galleryImages.length + (isOwner ? 1 : 0),
                                    itemBuilder: (context, index) {
                                      // ถ้าเป็นเจ้าของร้านและเป็นช่องสุดท้าย ให้แสดงปุ่มเพิ่มรูปภาพ
                                      if (isOwner && index == _shop.galleryImages.length) {
                                        return GestureDetector(
                                          onTap: _openGalleryManager,
                                          child: Container(
                                            width: 120,
                                            margin: const EdgeInsets.only(right: 8),
                                            decoration: BoxDecoration(
                                              color: Colors.grey[200],
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: Colors.blueGrey,
                                                width: 2,
                                                style: BorderStyle.solid,
                                              ),
                                            ),
                                            child: const Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.add_photo_alternate, color: Colors.blueGrey, size: 32),
                                                SizedBox(height: 8),
                                                Text(
                                                  'เพิ่มรูปภาพ',
                                                  style: TextStyle(color: Colors.blueGrey),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }
                                      
                                      return GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => GalleryViewScreen(
                                                images: _shop.galleryImages,
                                                initialIndex: index,
                                                shopName: _shop.name,
                                              ),
                                            ),
                                          );
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.only(right: 8.0),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: Image.network(
                                              _shop.galleryImages[index],
                                              width: 160,
                                              height: 120,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) {
                                                return Container(
                                                  width: 160,
                                                  height: 120,
                                                  color: Colors.grey[300],
                                                  child: const Icon(
                                                    Icons.image_not_supported,
                                                    color: Colors.grey,
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _makePhoneCall(_shop.phone),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                backgroundColor: Colors.blueGrey,
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.phone),
                              label: const Text('โทรหาร้าน'),
                            ),
                          ),
                        const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => _openChatWithShop(),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                foregroundColor: Colors.blueGrey,
                                side: const BorderSide(color: Colors.blueGrey),
                              ),
                              icon: const Icon(Icons.chat),
                              label: const Text('แชทกับผู้ขาย'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ]),
                ),
              ],
            ),
    );
  }
}
