import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/chat_message.dart';
import '../models/user_model.dart';
import '../models/shop.dart';
import '../services/cloudinary_service.dart';

class ChatService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // สร้างหรือดึงห้องแชทระหว่างลูกค้าและร้านค้า
  static Future<String> createOrGetChatRoom(Shop shop, UserModel customer) async {
    try {
      // ตรวจสอบว่ามีห้องแชทอยู่แล้วหรือไม่
      final querySnapshot = await _firestore
          .collection('chatRooms')
          .where('shopId', isEqualTo: shop.id)
          .where('customerId', isEqualTo: customer.id)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        // มีห้องแชทอยู่แล้ว
        return querySnapshot.docs.first.id;
      } else {
        // สร้างห้องแชทใหม่
        final chatRoom = ChatRoom(
          id: '', // จะถูกกำหนดโดย Firestore
          shopId: shop.id,
          shopOwnerId: shop.ownerId ?? '',
          customerId: customer.id,
          lastMessageTime: DateTime.now(),
          lastMessage: 'เริ่มการสนทนา',
          shopName: shop.name,
          customerName: customer.name,
          shopImageUrl: shop.imageUrl,
          unreadCount: 0,
        );

        final docRef = await _firestore.collection('chatRooms').add(chatRoom.toMap());
        return docRef.id;
      }
    } catch (e) {
      print('Error creating or getting chat room: $e');
      rethrow;
    }
  }

  // ส่งข้อความในห้องแชท
  static Future<void> sendMessage(String chatRoomId, String message, {dynamic imageData}) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('ไม่พบข้อมูลผู้ใช้ กรุณาเข้าสู่ระบบก่อน');
      }

      // ดึงข้อมูลห้องแชท
      final chatRoomDoc = await _firestore.collection('chatRooms').doc(chatRoomId).get();
      if (!chatRoomDoc.exists) {
        throw Exception('ไม่พบห้องแชท');
      }

      final chatRoom = ChatRoom.fromFirestore(chatRoomDoc);
      
      // ตรวจสอบว่าผู้ใช้ปัจจุบันเป็นเจ้าของร้านหรือลูกค้า
      String senderId = currentUser.uid;
      String receiverId = senderId == chatRoom.shopOwnerId 
          ? chatRoom.customerId 
          : chatRoom.shopOwnerId;

      // อัปโหลดรูปภาพ (ถ้ามี)
      String? imageUrl;
      bool hasImage = false;
      
      if (imageData != null) {
        try {
          final String folderPath = 'wreath_shop/chat_images';
          
          if (kIsWeb && imageData is Uint8List) {
            imageUrl = await CloudinaryService.uploadImage(imageData, folderPath);
          } else if (imageData is File) {
            imageUrl = await CloudinaryService.uploadImage(imageData.path, folderPath);
          }
          
          if (imageUrl != null) {
            hasImage = true;
          }
        } catch (e) {
          print('Error uploading chat image: $e');
          // ทำต่อไปแม้จะอัปโหลดรูปภาพไม่สำเร็จ
        }
      }

      // สร้างข้อความใหม่
      final chatMessage = ChatMessage(
        id: '', // จะถูกกำหนดโดย Firestore
        senderId: senderId,
        receiverId: receiverId,
        message: message.trim(),
        timestamp: DateTime.now(),
        isRead: false,
        hasImage: hasImage,
        imageUrl: imageUrl,
      );

      // บันทึกข้อความลง Firestore
      await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .collection('messages')
          .add(chatMessage.toMap());

      // อัปเดตข้อมูลล่าสุดของห้องแชท
      String displayMessage = hasImage ? (message.isNotEmpty ? '$message [รูปภาพ]' : '[รูปภาพ]') : message;
      await _firestore.collection('chatRooms').doc(chatRoomId).update({
        'lastMessage': displayMessage,
        'lastMessageTime': Timestamp.fromDate(DateTime.now()),
        'unreadCount': FieldValue.increment(1),
        'lastMessageHasImage': hasImage,
      });
    } catch (e) {
      print('Error sending message: $e');
      rethrow;
    }
  }

  // ดึงข้อความทั้งหมดในห้องแชท
  static Stream<List<ChatMessage>> getMessages(String chatRoomId) {
    return _firestore
        .collection('chatRooms')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => ChatMessage.fromFirestore(doc)).toList();
    });
  }

  // ดึงห้องแชททั้งหมดของผู้ใช้ (ทั้งเจ้าของร้านและลูกค้า)
  static Stream<List<ChatRoom>> getChatRooms() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value([]);
    }

  try {
    return _firestore
        .collection('chatRooms')
        .where(Filter.or(
          Filter('shopOwnerId', isEqualTo: currentUser.uid),
          Filter('customerId', isEqualTo: currentUser.uid),
        ))
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => ChatRoom.fromFirestore(doc)).toList();
      })
          .handleError((error) {
            print('Error fetching chat rooms: $error');
            // ส่งรายการว่างเมื่อเกิดข้อผิดพลาด
            return [];
    });
    } catch (e) {
      print('Exception in getChatRooms: $e');
      return Stream.value([]);
    }
  }

  // อ่านข้อความทั้งหมดในห้องแชท
  static Future<void> markMessagesAsRead(String chatRoomId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return;
      }

      // ดึงข้อมูลห้องแชท
      final chatRoomDoc = await _firestore.collection('chatRooms').doc(chatRoomId).get();
      if (!chatRoomDoc.exists) {
        return;
      }

      final chatRoom = ChatRoom.fromFirestore(chatRoomDoc);
      
      // ตรวจสอบว่าผู้ใช้ปัจจุบันเป็นผู้รับข้อความหรือไม่
      bool isReceiver = currentUser.uid == chatRoom.shopOwnerId || currentUser.uid == chatRoom.customerId;
      
      if (isReceiver) {
        // อัปเดตสถานะการอ่านข้อความ
        final batch = _firestore.batch();
        
        final messagesSnapshot = await _firestore
            .collection('chatRooms')
            .doc(chatRoomId)
            .collection('messages')
            .where('receiverId', isEqualTo: currentUser.uid)
            .where('isRead', isEqualTo: false)
            .get();
        
        for (var doc in messagesSnapshot.docs) {
          batch.update(doc.reference, {'isRead': true});
        }
        
        // รีเซ็ตจำนวนข้อความที่ยังไม่ได้อ่าน
        batch.update(_firestore.collection('chatRooms').doc(chatRoomId), {'unreadCount': 0});
        
        await batch.commit();
      }
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }
}
