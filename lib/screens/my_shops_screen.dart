import 'package:flutter/material.dart';
import '../models/shop.dart';
import '../services/firebase_service.dart';
import 'add_shop_screen.dart';
import 'shop_detail_screen.dart';
import 'edit_shop_screen.dart';
import 'gallery_manager_screen.dart';

class MyShopsScreen extends StatefulWidget {
  const MyShopsScreen({Key? key}) : super(key: key);

  @override
  _MyShopsScreenState createState() => _MyShopsScreenState();
}

class _MyShopsScreenState extends State<MyShopsScreen> {
  List<Shop> _myShops = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMyShops();
  }

  Future<void> _loadMyShops() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final shops = await FirebaseService.getMyShops();
      setState(() {
        _myShops = shops;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading my shops: $e');
      setState(() {
        _myShops = [];
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ไม่สามารถโหลดข้อมูลร้านค้าได้: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ร้านค้าของฉัน'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMyShops,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _myShops.isEmpty
              ? _buildEmptyState()
              : _buildShopsList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddShopScreen(
                onShopAdded: () {
                  print('Shop added callback triggered');
                  _loadMyShops();
                },
              ),
            ),
          );
        },
        child: const Icon(Icons.add),
        tooltip: 'เพิ่มร้านพวงหรีดใหม่',
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.store_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          const Text(
            'คุณยังไม่มีร้านพวงหรีด',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'กดปุ่ม + เพื่อเพิ่มร้านพวงหรีดใหม่',
            style: TextStyle(
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddShopScreen(
                    onShopAdded: () {
                      print('Shop added callback triggered');
                      _loadMyShops();
                    },
                  ),
                ),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('เพิ่มร้านพวงหรีดใหม่'),
          ),
        ],
      ),
    );
  }

  Widget _buildShopsList() {
    return ListView.builder(
      itemCount: _myShops.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final shop = _myShops[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (shop.imageUrl != null)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  child: Image.network(
                    shop.imageUrl!,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 150,
                        color: Colors.grey[300],
                        child: const Icon(
                          Icons.image_not_supported,
                          size: 50,
                          color: Colors.grey,
                        ),
                      );
                    },
                  ),
                )
              else
                Container(
                  height: 150,
                  width: double.infinity,
                  color: Colors.grey[300],
                  child: const Icon(
                    Icons.store,
                    size: 50,
                    color: Colors.grey,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shop.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.star, color: Colors.amber, size: 16),
                        Text(' ${shop.rating}'),
                        const SizedBox(width: 16),
                        Text('฿' * shop.priceRange),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      shop.address,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ShopDetailScreen(shop: shop),
                                ),
                              );
                            },
                            icon: const Icon(Icons.visibility),
                            label: const Text('ดูรายละเอียด'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EditShopScreen(
                                    shop: shop,
                                    onShopUpdated: () {
                                      print('Shop updated callback triggered');
                                      _loadMyShops();
                                    },
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.edit),
                            label: const Text('แก้ไข'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => GalleryManagerScreen(
                                shop: shop,
                                onGalleryUpdated: () {
                                  print('Gallery updated callback triggered');
                                  _loadMyShops();
                                },
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.photo_library),
                        label: const Text('จัดการแกลเลอรี'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blueGrey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
