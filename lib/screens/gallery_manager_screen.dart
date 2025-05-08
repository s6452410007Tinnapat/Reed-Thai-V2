import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import '../models/shop.dart';
import '../services/firebase_service.dart';
import '../services/cloudinary_service.dart';

class GalleryManagerScreen extends StatefulWidget {
  final Shop shop;
  final Function? onGalleryUpdated;

  const GalleryManagerScreen({
    Key? key,
    required this.shop,
    this.onGalleryUpdated,
  }) : super(key: key);

  @override
  _GalleryManagerScreenState createState() => _GalleryManagerScreenState();
}

class _GalleryManagerScreenState extends State<GalleryManagerScreen> {
  List<String> _galleryImages = [];
  List<dynamic> _newImages = []; // จะเก็บทั้ง File และ Uint8List
  bool _isLoading = false;
  String? _errorMessage;
  final int _maxImages = 8;

  @override
  void initState() {
    super.initState();
    _galleryImages = List.from(widget.shop.galleryImages);
  }

  Future<void> _pickImage() async {
    if (_galleryImages.length + _newImages.length >= _maxImages) {
      setState(() {
        _errorMessage = 'ไม่สามารถเพิ่มรูปภาพได้อีก (สูงสุด $_maxImages รูป)';
      });
      return;
    }

    final ImagePicker picker = ImagePicker();
    
    try {
      final XFile? pickedImage = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (pickedImage != null) {
        if (kIsWeb) {
          // สำหรับ Web
          final Uint8List bytes = await pickedImage.readAsBytes();
          setState(() {
            _newImages.add(bytes);
            _errorMessage = null;
          });
        } else {
          // สำหรับ Mobile
          setState(() {
            _newImages.add(File(pickedImage.path));
            _errorMessage = null;
          });
        }
      }
    } catch (e) {
      print('Error picking image: $e');
      setState(() {
        _errorMessage = 'เกิดข้อผิดพลาดในการเลือกรูปภาพ: $e';
      });
    }
  }

  Future<List<String>> _uploadNewImages() async {
    List<String> uploadedUrls = [];
    
    if (_newImages.isEmpty) return uploadedUrls;
    
    final String folderPath = 'wreath_shop/gallery_images';
    
    for (var image in _newImages) {
      try {
        String? imageUrl;
        
        if (kIsWeb && image is Uint8List) {
          imageUrl = await CloudinaryService.uploadImage(image, folderPath);
        } else if (image is File) {
          imageUrl = await CloudinaryService.uploadImage(image.path, folderPath);
        }
        
        if (imageUrl != null) {
          uploadedUrls.add(imageUrl);
        }
      } catch (e) {
        print('Error uploading image: $e');
        // ทำต่อไปแม้จะมีรูปที่อัปโหลดไม่สำเร็จ
      }
    }
    
    return uploadedUrls;
  }

  void _removeExistingImage(int index) {
    setState(() {
      _galleryImages.removeAt(index);
    });
  }

  void _removeNewImage(int index) {
    setState(() {
      _newImages.removeAt(index);
    });
  }

  Future<void> _saveGallery() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // อัปโหลดรูปภาพใหม่
      List<String> newImageUrls = await _uploadNewImages();
      
      // รวมรูปภาพเดิมและรูปภาพใหม่
      List<String> updatedGallery = [..._galleryImages, ...newImageUrls];
      
      // อัปเดตข้อมูลแกลเลอรีใน Firestore
      await FirebaseService.updateShopGallery(widget.shop.id, updatedGallery);
      
      // แจ้งเตือนว่าอัปเดตสำเร็จ
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('อัปเดตแกลเลอรีสำเร็จ')),
        );
      }
      
      // เรียกฟังก์ชัน callback (ถ้ามี)
      if (widget.onGalleryUpdated != null) {
        widget.onGalleryUpdated!();
      }
      
      // กลับไปยังหน้าก่อนหน้า
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      print('Error saving gallery: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'เกิดข้อผิดพลาด: $e';
          _isLoading = false;
        });
      }
    } finally {
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final int totalImages = _galleryImages.length + _newImages.length;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('จัดการแกลเลอรี'),
        actions: [
          TextButton.icon(
            onPressed: totalImages > 0 ? _saveGallery : null,
            icon: const Icon(Icons.save, color: Colors.white),
            label: const Text('บันทึก', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'รูปภาพในแกลเลอรี ($totalImages/$_maxImages)',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: totalImages < _maxImages ? _pickImage : null,
                        icon: const Icon(Icons.add_photo_alternate),
                        label: const Text('เพิ่มรูป'),
                      ),
                    ],
                  ),
                ),
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red.shade800),
                    ),
                  ),
                Expanded(
                  child: totalImages == 0
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.photo_library_outlined,
                                size: 80,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'ยังไม่มีรูปภาพในแกลเลอรี',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _pickImage,
                                icon: const Icon(Icons.add_photo_alternate),
                                label: const Text('เพิ่มรูปภาพ'),
                              ),
                            ],
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 1,
                          ),
                          itemCount: totalImages,
                          itemBuilder: (context, index) {
                            if (index < _galleryImages.length) {
                              // แสดงรูปภาพเดิม
                              return _buildExistingImageItem(index);
                            } else {
                              // แสดงรูปภาพใหม่
                              return _buildNewImageItem(index - _galleryImages.length);
                            }
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildExistingImageItem(int index) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              _galleryImages[index],
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
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
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey[200],
                  child: const Icon(
                    Icons.broken_image,
                    size: 50,
                    color: Colors.grey,
                  ),
                );
              },
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: () => _removeExistingImage(index),
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
    );
  }

  Widget _buildNewImageItem(int index) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: kIsWeb
                ? _newImages[index] is Uint8List
                    ? Image.memory(
                        _newImages[index],
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      )
                    : const Icon(Icons.broken_image, size: 50, color: Colors.grey)
                : _newImages[index] is File
                    ? Image.file(
                        _newImages[index],
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      )
                    : const Icon(Icons.broken_image, size: 50, color: Colors.grey),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: () => _removeNewImage(index),
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
        Positioned(
          bottom: 8,
          left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blueGrey,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'ใหม่',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
