import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/chat_message.dart';
import '../models/shop.dart';
import '../models/user_model.dart';
import '../providers/user_provider.dart';
import '../services/chat_service.dart';
import 'package:intl/intl.dart';

class ChatScreen extends StatefulWidget {
  final String chatRoomId;
  final Shop shop;
  final UserModel? customer;

  const ChatScreen({
    Key? key,
    required this.chatRoomId,
    required this.shop,
    this.customer,
  }) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  // ตัวแปรสำหรับเก็บรูปภาพที่เลือก
  File? _imageFile;
  Uint8List? _webImage;
  bool _hasImage = false;

  @override
  void initState() {
    super.initState();
    // อ่านข้อความทั้งหมดเมื่อเปิดหน้าแชท
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ChatService.markMessagesAsRead(widget.chatRoomId);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    
    try {
      final XFile? pickedImage = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (pickedImage != null) {
        setState(() {
          if (kIsWeb) {
            // สำหรับ Web
            pickedImage.readAsBytes().then((bytes) {
              setState(() {
                _webImage = bytes;
                _imageFile = null;
                _hasImage = true;
              });
            });
          } else {
            // สำหรับ Mobile
            _imageFile = File(pickedImage.path);
            _webImage = null;
            _hasImage = true;
          }
        });
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ไม่สามารถเลือกรูปภาพได้: $e')),
      );
    }
  }

  void _clearSelectedImage() {
    setState(() {
      _imageFile = null;
      _webImage = null;
      _hasImage = false;
    });
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty && !_hasImage) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // ส่งข้อความพร้อมรูปภาพ (ถ้ามี)
      dynamic imageData = _hasImage ? (kIsWeb ? _webImage : _imageFile) : null;
      
      await ChatService.sendMessage(widget.chatRoomId, message, imageData: imageData);
      _messageController.clear();
      _clearSelectedImage();
      
      // เลื่อนไปที่ข้อความล่าสุด
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ไม่สามารถส่งข้อความได้: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<UserProvider>(context).user;
    final bool isShopOwner = currentUser?.id == widget.shop.ownerId;
    
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.grey[300],
              backgroundImage: widget.shop.imageUrl != null
                  ? NetworkImage(widget.shop.imageUrl!)
                  : null,
              child: widget.shop.imageUrl == null
                  ? const Icon(Icons.store, color: Colors.grey)
                  : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isShopOwner
                        ? widget.customer?.name ?? 'ลูกค้า'
                        : widget.shop.name,
                    style: const TextStyle(fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    isShopOwner ? 'ลูกค้า' : 'เจ้าของร้าน',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: ChatService.getMessages(widget.chatRoomId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'),
                  );
                }

                final messages = snapshot.data ?? [];
                
                if (messages.isEmpty) {
                  return const Center(
                    child: Text('ยังไม่มีข้อความ เริ่มการสนทนาเลย!'),
                  );
                }

                // เลื่อนไปที่ข้อความล่าสุดเมื่อโหลดข้อความเสร็จ
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom();
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final bool isMe = currentUser?.id == message.senderId;
                    
                    // แสดงวันที่เมื่อเปลี่ยนวัน
                    bool showDate = false;
                    if (index == 0) {
                      showDate = true;
                    } else {
                      final prevMessage = messages[index - 1];
                      final prevDate = DateFormat('yyyy-MM-dd').format(prevMessage.timestamp);
                      final currentDate = DateFormat('yyyy-MM-dd').format(message.timestamp);
                      showDate = prevDate != currentDate;
                    }

                    return Column(
                      children: [
                        if (showDate)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  DateFormat('d MMMM yyyy').format(message.timestamp),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[800],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.7,
                            ),
                            decoration: BoxDecoration(
                              color: isMe ? Colors.green[100] : Colors.grey[200],
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (message.hasImage && message.imageUrl != null)
                                  GestureDetector(
                                    onTap: () {
                                      // แสดงรูปภาพแบบเต็มหน้าจอเมื่อคลิก
                                      showDialog(
                                        context: context,
                                        builder: (context) => Dialog(
                                          backgroundColor: Colors.transparent,
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              InteractiveViewer(
                                                minScale: 0.5,
                                                maxScale: 3.0,
                                                child: Image.network(
                                                  message.imageUrl!,
                                                  fit: BoxFit.contain,
                                                  loadingBuilder: (context, child, loadingProgress) {
                                                    if (loadingProgress == null) return child;
                                                    return Center(
                                                      child: CircularProgressIndicator(
                                                        value: loadingProgress.expectedTotalBytes != null
                                                            ? loadingProgress.cumulativeBytesLoaded /
                                                                loadingProgress.expectedTotalBytes!
                                                            : null,
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                              Positioned(
                                                top: 0,
                                                right: 0,
                                                child: IconButton(
                                                  icon: const Icon(Icons.close, color: Colors.white),
                                                  onPressed: () => Navigator.pop(context),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        message.imageUrl!,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        loadingBuilder: (context, child, loadingProgress) {
                                          if (loadingProgress == null) return child;
                                          return Container(
                                            height: 150,
                                            width: 200,
                                            alignment: Alignment.center,
                                            child: CircularProgressIndicator(
                                              value: loadingProgress.expectedTotalBytes != null
                                                  ? loadingProgress.cumulativeBytesLoaded /
                                                      loadingProgress.expectedTotalBytes!
                                                  : null,
                                            ),
                                          );
                                        },
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            height: 150,
                                            width: 200,
                                            color: Colors.grey[300],
                                            alignment: Alignment.center,
                                            child: const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                if (message.message.isNotEmpty)
                                  Padding(
                                    padding: EdgeInsets.only(top: message.hasImage ? 8 : 0),
                                    child: Text(message.message),
                                  ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('HH:mm').format(message.timestamp),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          // แสดงรูปภาพที่เลือกก่อนส่ง
          if (_hasImage)
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.grey[200],
              child: Row(
                children: [
                  Expanded(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          height: 100,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: kIsWeb
                                ? _webImage != null
                                    ? Image.memory(
                                        _webImage!,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: 100,
                                      )
                                    : const Icon(Icons.image, size: 50, color: Colors.grey)
                                : _imageFile != null
                                    ? Image.file(
                                        _imageFile!,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: 100,
                                      )
                                    : const Icon(Icons.image, size: 50, color: Colors.grey),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: _clearSelectedImage,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 2,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.photo),
                  onPressed: _pickImage,
                  tooltip: 'เลือกรูปภาพ',
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'พิมพ์ข้อความ...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.green,
                  child: IconButton(
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.send, color: Colors.white),
                    onPressed: _isLoading ? null : _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
