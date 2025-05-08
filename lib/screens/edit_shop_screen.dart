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

class EditShopScreen extends StatefulWidget {
  final Shop shop;
  final Function? onShopUpdated;
  
  const EditShopScreen({
    Key? key, 
    required this.shop,
    this.onShopUpdated,
  }) : super(key: key);

  @override
  _EditShopScreenState createState() => _EditShopScreenState();
}

class _EditShopScreenState extends State<EditShopScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  late TextEditingController _latitudeController;
  late TextEditingController _longitudeController;
  
  late LatLng _selectedLocation;
  final MapController _mapController = MapController();
  
  late List<String> _selectedWreathTypes;
  late int _priceRange;
  
  // ตัวแปรสำหรับเก็บรูปภาพที่เลือก
  File? _imageFile;
  Uint8List? _webImage;
  bool _hasImage = false;
  bool _imageChanged = false;
  
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
    // กำหนดค่าเริ่มต้นจากข้อมูลร้านที่ส่งมา
    _nameController = TextEditingController(text: widget.shop.name);
    _descriptionController = TextEditingController(text: widget.shop.description);
    _addressController = TextEditingController(text: widget.shop.address);
    _phoneController = TextEditingController(text: widget.shop.phone);
    _selectedLocation = LatLng(widget.shop.latitude, widget.shop.longitude);
    _latitudeController = TextEditingController(text: widget.shop.latitude.toString());
    _longitudeController = TextEditingController(text: widget.shop.longitude.toString());
    _selectedWreathTypes = List.from(widget.shop.wreathTypes);
    _priceRange = widget.shop.priceRange;
    
    // ตรวจสอบว่ามีรูปภาพเดิมหรือไม่
    _hasImage = widget.shop.imageUrl != null;
  }

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

  void _updateLocationControllers() {
    setState(() {
      _latitudeController.text = _selectedLocation.latitude.toString();
      _longitudeController.text = _selectedLocation.longitude.toString();
    });
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
          _imageChanged = true;
        });
        
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

  Future<String?> _uploadImage() async {
    if (!_hasImage || !_imageChanged) return widget.shop.imageUrl;
    
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
        print('No new image to upload');
        return widget.shop.imageUrl;
      }
    } catch (e) {
      print('Error in _uploadImage: $e');
      setState(() {
        _errorMessage = 'เกิดข้อผิดพลาดในการอัปโหลดรูปภาพ: $e';
      });
      return widget.shop.imageUrl;
    }
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
        // อัปโหลดรูปภาพไปยัง Cloudinary (ถ้ามีการเปลี่ยนแปลง)
        String? imageUrl = widget.shop.imageUrl;
        if (_imageChanged) {
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
        
        // สร้างข้อมูลร้านพวงหรีดที่อัปเดต
        final updatedShop = Shop(
          id: widget.shop.id,
          name: _nameController.text,
          description: _descriptionController.text,
          address: _addressController.text,
          phone: _phoneController.text,
          imageUrl: imageUrl,
          latitude: double.parse(_latitudeController.text),
          longitude: double.parse(_longitudeController.text),
          rating: widget.shop.rating, // คงค่าเดิม
          wreathTypes: _selectedWreathTypes,
          galleryImages: widget.shop.galleryImages, // คงค่าเดิม
          priceRange: _priceRange,
          ownerId: widget.shop.ownerId, // คงค่าเดิม
        );
        
        // บันทึกข้อมูลลง Firestore
        print('Updating shop data in Firestore...');
        await FirebaseService.updateShop(widget.shop.id, updatedShop);
        print('Shop data updated successfully');
        
        // แจ้งเตือนว่าอัปเดตร้านสำเร็จ
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('อัปเดตร้านพวงหรีดสำเร็จ')),
          );
        }
        
        // เรียกฟังก์ชัน callback (ถ้ามี)
        if (widget.onShopUpdated != null) {
          widget.onShopUpdated!();
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
        title: const Text('แก้ไขร้านพวงหรีด'),
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
                                child: _imageChanged
                                    ? (kIsWeb
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
                                            : const Icon(Icons.image, size: 50, color: Colors.grey))
                                    : (widget.shop.imageUrl != null
                                        ? Image.network(
                                            widget.shop.imageUrl!,
                                            fit: BoxFit.cover,
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
                                              return const Icon(Icons.broken_image, size: 50, color: Colors.grey);
                                            },
                                          )
                                        : const Icon(Icons.image, size: 50, color: Colors.grey)),
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
                    ElevatedButton(
                      onPressed: _submitForm,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('บันทึกการแก้ไข'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
