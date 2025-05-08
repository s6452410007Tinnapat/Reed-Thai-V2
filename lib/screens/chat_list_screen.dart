import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/chat_message.dart';
import '../providers/user_provider.dart';
import '../services/chat_service.dart';
import '../services/firebase_service.dart';
import 'chat_screen.dart';
import 'package:intl/intl.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<UserProvider>(context).user;
    
    if (currentUser == null) {
      return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.chat_bubble_outline,
                size: 80,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              const Text(
                'กรุณาเข้าสู่ระบบเพื่อดูการสนทนา',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/login');
                },
                child: const Text('เข้าสู่ระบบ'),
              ),
            ],
        ),
      );
    }

    return StreamBuilder<List<ChatRoom>>(
        stream: ChatService.getChatRooms(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'),
            );
          }

          final chatRooms = snapshot.data ?? [];
          
          if (chatRooms.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.chat_bubble_outline,
                    size: 80,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'ยังไม่มีการสนทนา',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'เริ่มการสนทนากับร้านพวงหรีดที่คุณสนใจ',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: chatRooms.length,
            itemBuilder: (context, index) {
              final chatRoom = chatRooms[index];
              final bool isShopOwner = currentUser.id == chatRoom.shopOwnerId;
              
              return FutureBuilder(
                future: isShopOwner
                    ? FirebaseService.getUserById(chatRoom.customerId)
                    : FirebaseService.getShopById(chatRoom.shopId),
                builder: (context, snapshot) {
                  final name = isShopOwner
                      ? chatRoom.customerName
                      : chatRoom.shopName;
                  
                  final imageUrl = isShopOwner
                      ? null
                      : chatRoom.shopImageUrl;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.grey[300],
                      backgroundImage: imageUrl != null
                          ? NetworkImage(imageUrl)
                          : null,
                      child: imageUrl == null
                          ? Icon(
                              isShopOwner ? Icons.person : Icons.store,
                              color: Colors.grey,
                            )
                          : null,
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Row(
                    children: [
                      if (chatRoom.lastMessageHasImage)
                        const Padding(
                          padding: EdgeInsets.only(right: 4.0),
                          child: Icon(Icons.photo, size: 16, color: Colors.grey),
                        ),
                      Expanded(
                        child: Text(
                      chatRoom.lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      ),
                      ),
                    ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          DateFormat('HH:mm').format(chatRoom.lastMessageTime),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (chatRoom.unreadCount > 0)
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              chatRoom.unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    onTap: () async {
                      if (isShopOwner) {
                        final customer = await FirebaseService.getUserById(chatRoom.customerId);
                        if (customer != null) {
                          final shop = await FirebaseService.getShopById(chatRoom.shopId);
                          if (shop != null && context.mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatScreen(
                                  chatRoomId: chatRoom.id,
                                  shop: shop,
                                  customer: customer,
                                ),
                              ),
                            );
                          }
                        }
                      } else {
                        final shop = await FirebaseService.getShopById(chatRoom.shopId);
                        if (shop != null && context.mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatScreen(
                                chatRoomId: chatRoom.id,
                                shop: shop,
                              ),
                            ),
                          );
                        }
                      }
                    },
                  );
                },
              );
            },
          );
        },
    );
  }
}
