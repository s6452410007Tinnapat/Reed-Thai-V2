import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String senderId;
  final String receiverId;
  final String message;
  final DateTime timestamp;
  final bool isRead;
  final String? imageUrl; // เพิ่มฟิลด์สำหรับเก็บ URL ของรูปภาพ
  final bool hasImage;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.message,
    required this.timestamp,
    this.isRead = false,
    this.imageUrl,
    this.hasImage = false,
  });

  // แปลงข้อมูลจาก Firestore เป็น ChatMessage
  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      receiverId: data['receiverId'] ?? '',
      message: data['message'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      isRead: data['isRead'] ?? false,
      imageUrl: data['imageUrl'],
      hasImage: data['hasImage'] ?? false,
    );
  }

  // แปลงข้อมูลจาก ChatMessage เป็น Map สำหรับบันทึกลง Firestore
  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'message': message,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
      'imageUrl': imageUrl,
      'hasImage': hasImage,
    };
  }
}

class ChatRoom {
  final String id;
  final String shopId;
  final String shopOwnerId;
  final String customerId;
  final DateTime lastMessageTime;
  final String lastMessage;
  final String shopName;
  final String customerName;
  final String? shopImageUrl;
  final int unreadCount;
  final bool lastMessageHasImage;

  ChatRoom({
    required this.id,
    required this.shopId,
    required this.shopOwnerId,
    required this.customerId,
    required this.lastMessageTime,
    required this.lastMessage,
    required this.shopName,
    required this.customerName,
    this.shopImageUrl,
    this.unreadCount = 0,
    this.lastMessageHasImage = false,
  });

  // แปลงข้อมูลจาก Firestore เป็น ChatRoom
  factory ChatRoom.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ChatRoom(
      id: doc.id,
      shopId: data['shopId'] ?? '',
      shopOwnerId: data['shopOwnerId'] ?? '',
      customerId: data['customerId'] ?? '',
      lastMessageTime: (data['lastMessageTime'] as Timestamp).toDate(),
      lastMessage: data['lastMessage'] ?? '',
      shopName: data['shopName'] ?? '',
      customerName: data['customerName'] ?? '',
      shopImageUrl: data['shopImageUrl'],
      unreadCount: data['unreadCount'] ?? 0,
      lastMessageHasImage: data['lastMessageHasImage'] ?? false,
    );
  }

  // แปลงข้อมูลจาก ChatRoom เป็น Map สำหรับบันทึกลง Firestore
  Map<String, dynamic> toMap() {
    return {
      'shopId': shopId,
      'shopOwnerId': shopOwnerId,
      'customerId': customerId,
      'lastMessageTime': Timestamp.fromDate(lastMessageTime),
      'lastMessage': lastMessage,
      'shopName': shopName,
      'customerName': customerName,
      'shopImageUrl': shopImageUrl,
      'unreadCount': unreadCount,
      'lastMessageHasImage': lastMessageHasImage,
    };
  }
}
