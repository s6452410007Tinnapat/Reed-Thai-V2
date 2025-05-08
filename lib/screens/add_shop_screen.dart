import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/firebase_service.dart';
import '../services/cloudinary_service.dart';
import '../models/shop.dart';

class AddShopScreen extends StatefulWidget {
  final Function? onShopAdded;
  
  const AddShopScreen({Key? key, this.onShopAdded}) : super(key: key);

  @override
  _AddShopScreenState createState() => _AddShopScreenState();
}

class _AddShopScreenState extends State<AddShopScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  
  // ตำแหน่งเริ่มต้น (กรุงเทพฯ)
  LatLng _selectedLocation = LatLng(13.736717, 100.523186);
  final MapController _mapController = MapController();
  
  List<String> _selectedWreathTypes = [];
  int _priceRange = 2;
  
  // ตัวแปรสำหรับเก็บรูปภาพที่เลือก
  File? _imageFile;
  Uint8List? _webImage;
  bool _hasImage = false;
  
  // ตัวแปรสำหรับเก็บรูปภาพแกลเลอรี
  List<dynamic> _galleryImages = []; // จะเก็บทั้ง File และ Uint8List
  
  bool _isLoading = false;
  String? _errorMessage;
  
  final List<String> _wreathTypes = [
    'พวงรีดดอกไม้สด',
    'พวงรีดผ้า',
    'พวงรีดพัดลม',
    'พวงรีดนาฬิกา',
    'พวงรีดอื่นๆ',
  ];

  @override
  void initState() {
    super.initState();
    // อัปเดตค่า controller ด้วยตำแหน่งเริ่มต้น
    _updateLocationControllers();
  }

  void _updateLocationControllers() {
    setState(() {
      // อัปเดตค่าละติจูดและลองจิจูดในฟอร์ม
      _latitudeController.text = _selectedLocation.latitude.toString();
      _longitudeController.text = _selectedLocation.longitude.toString();
    });
  }

  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    
    try {
      final XFile? pickedImage = await picker.pickImage(
        source: ImageSource.gallery,
        // ลดขนาดรูปภาพเพื่อประหยัดพื้นที่และเวลาในการอัปโหลด
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (pickedImage != null) {
        if (kIsWeb) {
          // สำหรับ Web
          final Uint8List bytes = await pickedImage.readAsBytes();
          setState(() {
            _webImage = bytes;
            _imageFile = null;
            _hasImage = true;
          });
        } else {
          // สำหรับ Mobile
          setState(() {
            _imageFile = File(pickedImage.path);
            _webImage = null;
            _hasImage = true;
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

  Future<void> _pickGalleryImage() async {
    if (_galleryImages.length >= 8) {
      setState(() {
        _errorMessage = 'ไม่สามารถเพิ่มรูปภาพได้อีก (สูงสุด 8 รูป)';
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
            _galleryImages.add(bytes);
            _errorMessage = null;
          });
        } else {
          // สำหรับ Mobile
          setState(() {
            _galleryImages.add(File(pickedImage.path));
            _errorMessage = null;
          });
        }
      }
    } catch (e) {
      print('Error picking gallery image: $e');
      setState(() {
        _errorMessage = 'เกิดข้อผิดพลาดในการเลือกรูปภาพ: $e';
      });
    }
  }

  void _removeGalleryImage(int index) {
    setState(() {
      _galleryImages.removeAt(index);
    });
  }

  Future<String?> _uploadImage() async {
    if (!_hasImage) return null;
    
    try {
      print('Starting image upload to Cloudinary...');
      final String folderPath = 'wreath_shop/shop_images';
      
      if (kIsWeb && _webImage != null) {
        // อัปโหลดรูปภาพสำหรับ Web
        print('Uploading web image to Cloudinary...');
        return await CloudinaryService.uploadImage(_webImage, folderPath);
      } else if (_imageFile != null) {
        // อัปโหลดรูปภาพสำหรับ Mobile
        print('Uploading mobile image to Cloudinary...');
        return await CloudinaryService.uploadImage(_imageFile!.path, folderPath);
      } else {
        print('No image to upload');
        return null;
      }
    } catch (e) {
      print('Error in _uploadImage: $e');
      setState(() {
        _errorMessage = 'เกิดข้อผิดพลาดในการอัปโหลดรูปภาพ: $e';
      });
      return null;
    }
  }

  Future<List<String>> _uploadGalleryImages() async {
    List<String> uploadedUrls = [];
    
    if (_galleryImages.isEmpty) return uploadedUrls;
    
    final String folderPath = 'wreath_shop/gallery_images';
    
    for (var image in _galleryImages) {
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
        print('Error uploading gallery image: $e');
        // ทำต่อไปแม้จะมีรูปที่อัปโหลดไม่สำเร็จ
      }
    }
    
    return uploadedUrls;
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedWreathTypes.isEmpty) {
        setState(() {
          _errorMessage = 'กรุณาเลือกประเภทพวงรีดอย่างน้อย 1 ประเภท';
        });
        return;
      }
      
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      
      try {
        // อัปโหลดรูปภาพไปยัง Cloudinary (ถ้ามี)
        String? imageUrl;
        if (_hasImage) {
          try {
            imageUrl = await _uploadImage();
            print('Image uploaded successfully to Cloudinary: $imageUrl');
          } catch (e) {
            print('Error uploading image to Cloudinary: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('ไม่สามารถอัปโหลดรูปภาพได้ แต่จะบันทึกข้อมูลร้านต่อไป')),
              );
            }
          }
        }
        
        // อัปโหลดรูปภาพแกลเลอรี
        List<String> galleryUrls = [];
        if (_galleryImages.isNotEmpty) {
          try {
            galleryUrls = await _uploadGalleryImages();
            print('Gallery images uploaded successfully: ${galleryUrls.length} images');
          } catch (e) {
            print('Error uploading gallery images: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('ไม่สามารถอัปโหลดรูปภาพแกลเลอรีบางส่วนได้')),
              );
            }
          }
        }
        
        // สร้างข้อมูลร้านพวงหรีด
        final shop = Shop(
          id: DateTime.now().millisecondsSinceEpoch.toString(), // จะถูกแทนที่ด้วย ID จาก Firestore
          name: _nameController.text,
          description: _descriptionController.text,
          address: _addressController.text,
          phone: _phoneController.text,
          imageUrl: imageUrl,
          latitude: double.parse(_latitudeController.text),
          longitude: double.parse(_longitudeController.text),
          rating: 0.0, // เริ่มต้นที่ 0
          wreathTypes: _selectedWreathTypes,
          galleryImages: galleryUrls,
          priceRange: _priceRange,
        );
        
        // บันทึกข้อมูลลง Firestore
        print('Saving shop data to Firestore...');
        await FirebaseService.addShop(shop);
        print('Shop data saved successfully');
        
        // แจ้งเตือนว่าเพิ่มร้านสำเร็จ
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('เพิ่มร้านพวงหรีดสำเร็จ')),
          );
        }
        
        // เรียกฟังก์ชัน callback (ถ้ามี)
        if (widget.onShopAdded != null) {
          widget.onShopAdded!();
        }
        
        // กลับไปยังหน้าก่อนหน้า
        if (mounted) {
          Navigator.of(context).pop();
        }
      } catch (e) {
        print('Error submitting form: $e');
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('เพิ่มร้านพวงหรีด'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade800),
                        ),
                      ),
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _hasImage
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: kIsWeb
                                    ? _webImage != null
                                        ? Image.memory(
                                            _webImage!,
                                            fit: BoxFit.cover,
                                          )
                                        : const Icon(Icons.image, size: 50, color: Colors.grey)
                                    : _imageFile != null
                                        ? Image.file(
                                            _imageFile!,
                                            fit: BoxFit.cover,
                                          )
                                        : const Icon(Icons.image, size: 50, color: Colors.grey),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.add_a_photo, size: 50, color: Colors.grey),
                                  SizedBox(height: 8),
                                  Text('เพิ่มรูปภาพร้าน'),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'ชื่อร้าน',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'กรุณากรอกชื่อร้าน';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'รายละเอียดร้าน',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'กรุณากรอกรายละเอียดร้าน';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(
                        labelText: 'ที่อยู่',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'กรุณากรอกที่อยู่';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'เบอร์โทรศัพท์',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'กรุณากรอกเบอร์โทรศัพท์';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'เลือกตำแหน่งร้านบนแผนที่',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 300,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            center: _selectedLocation,
                            zoom: 13.0,
                            onTap: (tapPosition, latLng) {
                              setState(() {
                                _selectedLocation = latLng;
                                _updateLocationControllers();
                              });
                            },
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
                                  point: _selectedLocation,
                                  builder: (ctx) => const Icon(
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
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _latitudeController,
                            decoration: const InputDecoration(
                              labelText: 'ละติจูด',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'กรุณากรอกละติจูด';
                              }
                              return null;
                            },
                            onChanged: (value) {
                              if (value.isNotEmpty) {
                                try {
                                  final lat = double.parse(value);
                                  setState(() {
                                    _selectedLocation = LatLng(lat, _selectedLocation.longitude);
                                    _mapController.move(_selectedLocation, _mapController.zoom);
                                  });
                                } catch (e) {
                                  // ไม่ทำอะไรถ้าแปลงค่าไม่ได้
                                }
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _longitudeController,
                            decoration: const InputDecoration(
                              labelText: 'ลองจิจูด',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'กรุณากรอกลองจิจูด';
                              }
                              return null;
                            },
                            onChanged: (value) {
                              if (value.isNotEmpty) {
                                try {
                                  final lng = double.parse(value);
                                  setState(() {
                                    _selectedLocation = LatLng(_selectedLocation.latitude, lng);
                                    _mapController.move(_selectedLocation, _mapController.zoom);
                                  });
                                } catch (e) {
                                  // ไม่ทำอะไรถ้าแปลงค่าไม่ได้
                                }
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('ประเภทพวงรีด'),
                    Wrap(
                      spacing: 8,
                      children: _wreathTypes.map((type) {
                        final isSelected = _selectedWreathTypes.contains(type);
                        return FilterChip(
                          label: Text(type),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedWreathTypes.add(type);
                              } else {
                                _selectedWreathTypes.remove(type);
                              }
                            });
                          },
                          backgroundColor: Colors.grey[200],
                          selectedColor: Colors.blueGrey[100],
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    const Text('ระดับราคา'),
                    Slider(
                      value: _priceRange.toDouble(),
                      min: 1,
                      max: 3,
                      divisions: 2,
                      label: '฿' * _priceRange,
                      onChanged: (value) {
                        setState(() {
                          _priceRange = value.round();
                        });
                      },
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('ราคาประหยัด'),
                        Text('ราคาปานกลาง'),
                        Text('ราคาสูง'),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // เพิ่มส่วนจัดการแกลเลอรี
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'แกลเลอรี',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${_galleryImages.length}/8 รูป',
                          style: TextStyle(
                            color: _galleryImages.length >= 8 ? Colors.red : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey),
                      ),
                      child: _galleryImages.isEmpty
                          ? GestureDetector(
                              onTap: _pickGalleryImage,
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate, size: 40, color: Colors.grey),
                                  SizedBox(height: 8),
                                  Text('เพิ่มรูปภาพในแกลเลอรี'),
                                ],
                              ),
                            )
                          : ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _galleryImages.length + 1, // +1 สำหรับปุ่มเพิ่มรูปภาพ
                              padding: const EdgeInsets.all(8),
                              itemBuilder: (context, index) {
                                if (index == _galleryImages.length) {
                                  // ปุ่มเพิ่มรูปภาพ
                                  return GestureDetector(
                                    onTap: _galleryImages.length < 8 ? _pickGalleryImage : null,
                                    child: Container(
                                      width: 100,
                                      margin: const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                        color: _galleryImages.length < 8 ? Colors.grey[200] : Colors.grey[400],
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: _galleryImages.length < 8 ? Colors.blueGrey : Colors.grey,
                                          width: 2,
                                          style: BorderStyle.solid,
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.add_photo_alternate,
                                            color: _galleryImages.length < 8 ? Colors.blueGrey : Colors.grey,
                                            size: 32,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'เพิ่มรูป',
                                            style: TextStyle(
                                              color: _galleryImages.length < 8 ? Colors.blueGrey : Colors.grey,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }
                                
                                // แสดงรูปภาพที่เลือก
                                return Stack(
                                  children: [
                                    Container(
                                      width: 100,
                                      margin: const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.grey),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: kIsWeb
                                            ? _galleryImages[index] is Uint8List
                                                ? Image.memory(
                                                    _galleryImages[index],
                                                    fit: BoxFit.cover,
                                                    width: 100,
                                                    height: 100,
                                                  )
                                                : const Icon(Icons.broken_image, size: 40, color: Colors.grey)
                                            : _galleryImages[index] is File
                                                ? Image.file(
                                                    _galleryImages[index],
                                                    fit: BoxFit.cover,
                                                    width: 100,
                                                    height: 100,
                                                  )
                                                : const Icon(Icons.broken_image, size: 40, color: Colors.grey),
                                      ),
                                    ),
                                    Positioned(
                                      top: 4,
                                      right: 12,
                                      child: GestureDetector(
                                        onTap: () => _removeGalleryImage(index),
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.close,
                                            color: Colors.white,
                                            size: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _submitForm,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('บันทึกข้อมูลร้าน'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
