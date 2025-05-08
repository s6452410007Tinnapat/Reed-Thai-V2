import 'package:cloud_firestore/cloud_firestore.dart';

class Shop {
  final String id;
  final String name;
  final String description;
  final String address;
  final String phone;
  final String? imageUrl;
  final double latitude;
  final double longitude;
  final double rating;
  final List<String> wreathTypes;
  final List<String> galleryImages;
  final int priceRange; // 1-3 representing price range (low to high)
  final String? ownerId; // เพิ่ม ownerId เพื่อเชื่อมโยงกับเจ้าของร้าน

  // ค่าคงที่สำหรับรูปภาพเริ่มต้น
  static const String defaultAvatarPath = 'assets/images/default_avatar.png';

  Shop({
    required this.id,
    required this.name,
    required this.description,
    required this.address,
    required this.phone,
    this.imageUrl,
    required this.latitude,
    required this.longitude,
    required this.rating,
    required this.wreathTypes,
    required this.galleryImages,
    required this.priceRange,
    this.ownerId,
  });
  
  // เพิ่มเมธอดสำหรับรับ URL รูปภาพ (ใช้รูปเริ่มต้นถ้าไม่มีรูป)
  String getImageUrl() {
    return this.imageUrl ?? Shop.defaultAvatarPath;
  }

  // แปลงข้อมูลจาก Firestore เป็น Shop
  factory Shop.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Shop(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      address: data['address'] ?? '',
      phone: data['phone'] ?? '',
      imageUrl: data['imageUrl'],
      latitude: (data['latitude'] ?? 0.0).toDouble(),
      longitude: (data['longitude'] ?? 0.0).toDouble(),
      rating: (data['rating'] ?? 0.0).toDouble(),
      wreathTypes: List<String>.from(data['wreathTypes'] ?? []),
      galleryImages: List<String>.from(data['galleryImages'] ?? []),
      priceRange: data['priceRange'] ?? 1,
      ownerId: data['ownerId'],
    );
  }

  // แปลงข้อมูลจาก Shop เป็น Map สำหรับบันทึกลง Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'address': address,
      'phone': phone,
      'imageUrl': imageUrl,
      'latitude': latitude,
      'longitude': longitude,
      'rating': rating,
      'wreathTypes': wreathTypes,
      'galleryImages': galleryImages,
      'priceRange': priceRange,
      'ownerId': ownerId,
    };
  }
}

// ข้อมูลตัวอย่างร้านพวงรีด (ใช้สำหรับการทดสอบเท่านั้น)
List<Shop> sampleShops = [
  Shop(
    id: '1',
    name: 'ร้านพวงรีดสวยงาม',
    description: 'ร้านพวงรีดคุณภาพดี ราคาย่อมเยา บริการจัดส่งทั่วกรุงเทพฯ',
    address: '123 ถนนสุขุมวิท กรุงเทพฯ',
    phone: '02-123-4567',
    imageUrl: null, // ไม่มีรูปภาพ จะใช้รูปเริ่มต้น
    latitude: 13.736717,
    longitude: 100.523186,
    rating: 4.5,
    wreathTypes: ['พวงรีดดอกไม้สด', 'พวงรีดผ้า', 'พวงรีดพัดลม'],
    galleryImages: [
      'https://via.placeholder.com/300x200?text=พวงรีด1',
      'https://via.placeholder.com/300x200?text=พวงรีด2',
      'https://via.placeholder.com/300x200?text=พวงรีด3',
    ],
    priceRange: 2,
  ),
  Shop(
    id: '2',
    name: 'ร้านพวงรีดมาลัย',
    description: 'ร้านพวงรีดคุณภาพสูง ดีไซน์สวยงาม เหมาะสำหรับทุกงาน',
    address: '456 ถนนเพชรบุรี กรุงเทพฯ',
    phone: '02-765-4321',
    imageUrl: null, // ไม่มีรูปภาพ จะใช้รูปเริ่มต้น
    latitude: 13.746717,
    longitude: 100.533186,
    rating: 4.8,
    wreathTypes: ['พวงรีดดอกไม้สด', 'พวงรีดผ้า', 'พวงรีดพัดลม', 'พวงรีดนาฬิกา'],
    galleryImages: [
      'https://via.placeholder.com/300x200?text=พวงรีด4',
      'https://via.placeholder.com/300x200?text=พวงรีด5',
      'https://via.placeholder.com/300x200?text=พวงรีด6',
    ],
    priceRange: 3,
  ),
  Shop(
    id: '3',
    name: 'ร้านพวงรีดราคาประหยัด',
    description: 'ร้านพวงรีดราคาประหยัด คุณภาพดี เหมาะสำหรับทุกงบประมาณ',
    address: '789 ถนนรัชดาภิเษก กรุงเทพฯ',
    phone: '02-987-6543',
    imageUrl: null, // ไม่มีรูปภาพ จะใช้รูปเริ่มต้น
    latitude: 13.756717,
    longitude: 100.543186,
    rating: 4.2,
    wreathTypes: ['พวงรีดผ้า', 'พวงรีดพัดลม'],
    galleryImages: [
      'https://via.placeholder.com/300x200?text=พวงรีด7',
      'https://via.placeholder.com/300x200?text=พวงรีด8',
      'https://via.placeholder.com/300x200?text=พวงรีด9',
    ],
    priceRange: 1,
  ),
  // เพิ่มร้านพวงหรีดตัวอย่างเพิ่มเติมเพื่อทดสอบแผนที่
  Shop(
    id: '4',
    name: 'ร้านพวงรีดดอกไม้สด',
    description: 'ร้านพวงรีดดอกไม้สดคุณภาพดี สวยงาม ส่งเร็ว',
    address: '111 ถนนพระราม 9 กรุงเทพฯ',
    phone: '02-111-2222',
    imageUrl: null,
    latitude: 13.726717,
    longitude: 100.513186,
    rating: 4.7,
    wreathTypes: ['พวงรีดดอกไม้สด'],
    galleryImages: [
      'https://via.placeholder.com/300x200?text=พวงรีด10',
      'https://via.placeholder.com/300x200?text=พวงรีด11',
    ],
    priceRange: 3,
  ),
  Shop(
    id: '5',
    name: 'ร้านพวงรีดพัดลม',
    description: 'ร้านพวงรีดพัดลมคุณภาพดี ประหยัดและเป็นมิตรกับสิ่งแวดล้อม',
    address: '222 ถนนเพชรเกษม กรุงเทพฯ',
    phone: '02-333-4444',
    imageUrl: null,
    latitude: 13.716717,
    longitude: 100.503186,
    rating: 4.3,
    wreathTypes: ['พวงรีดพัดลม'],
    galleryImages: [
      'https://via.placeholder.com/300x200?text=พวงรีด12',
      'https://via.placeholder.com/300x200?text=พวงรีด13',
    ],
    priceRange: 2,
  ),
];
