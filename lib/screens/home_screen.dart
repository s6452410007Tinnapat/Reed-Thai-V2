import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/shop.dart';
import '../services/firebase_service.dart';
import 'shop_detail_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';
import 'chat_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final MapController _mapController = MapController();
  final LatLng _center = const LatLng(13.736717, 100.523186); // กรุงเทพฯ
  List<Marker> _markers = [];
  List<Shop> _shops = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadShops();
  }

  Future<void> _loadShops() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // ดึงข้อมูลร้านค้าจาก Firestore
      final shops = await FirebaseService.getAllShops();
      
      setState(() {
        _shops = shops;
        _isLoading = false;
      });
      
      // อัปเดตมาร์กเกอร์บนแผนที่
      if (_selectedIndex == 0) {
        _updateMapMarkers();
      }
    } catch (e) {
      print('Error loading shops: $e');
      
      // กรณีมีข้อผิดพลาด ใช้ข้อมูลจำลองแทน
      setState(() {
        _shops = sampleShops;
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ไม่สามารถโหลดข้อมูลร้านค้าได้: $e')),
      );
      
      if (_selectedIndex == 0) {
        _updateMapMarkers();
      }
    }
  }

  void _updateMapMarkers() {
    List<Marker> markers = [];
    
    for (final shop in _shops) {
      markers.add(
        Marker(
          width: 80,
          height: 80,
          point: LatLng(shop.latitude, shop.longitude),
          builder: (context) => GestureDetector(
            onTap: () {
              _showShopInfo(shop);
            },
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.blueGrey,
                    child: Icon(
                      Icons.store,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    shop.name,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    setState(() {
      _markers = markers;
    });
  }

  void _showShopInfo(Shop shop) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ShopDetailScreen(shop: shop),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedIndex == 0 ? 'แอปพวงรีด' : 
                   _selectedIndex == 1 ? 'รายการร้าน' : 
                   _selectedIndex == 2 ? 'โปรไฟล์' : 'การสนทนา'),
        actions: [
          if (_selectedIndex < 2)
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SearchScreen()),
              );
            },
          ),
          if (_selectedIndex < 2)
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadShops,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _selectedIndex == 0
              ? _buildMapView()
              : _buildListView(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'แผนที่',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: 'รายการร้าน',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'โปรไฟล์',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'แชท',
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: () {
                _mapController.move(_center, 12.0);
              },
              child: const Icon(Icons.my_location),
              tooltip: 'กลับไปยังตำแหน่งเริ่มต้น',
            )
          : null,
    );
  }

  Widget _buildMapView() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        center: _center,
        zoom: 12.0,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c'],
        ),
        MarkerLayer(
          markers: _markers,
        ),
      ],
    );
  }

  Widget _buildListView() {
    if (_selectedIndex == 3) {
      // แสดงหน้ารายการแชท
      return const ChatListScreen();
    } else if (_selectedIndex == 2) {
      // แสดงหน้าโปรไฟล์
      return const ProfileScreen();
    }
    
    // แสดงรายการร้าน
    return RefreshIndicator(
      onRefresh: _loadShops,
      child: ListView.builder(
        itemCount: _shops.length,
        itemBuilder: (context, index) {
          final shop = _shops[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blueGrey,
                backgroundImage: shop.imageUrl != null 
                  ? NetworkImage(shop.imageUrl!) 
                  : null,
                child: shop.imageUrl == null ? const Icon(Icons.store, color: Colors.white) : null,
              ),
              title: Text(shop.name),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(shop.address),
                  Row(
                    children: [
                      Icon(Icons.star, color: Colors.amber, size: 16),
                      Text(' ${shop.rating}'),
                      const SizedBox(width: 8),
                      Text('฿' * shop.priceRange),
                    ],
                  ),
                ],
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ShopDetailScreen(shop: shop),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
