import 'dart:io';
import 'dart:typed_data';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

class CloudinaryService {
  // Cloudinary credentials
  static const String cloudName = 'dxyattaiz';
  static const String uploadPreset = 'Reed Images';
  
  static final CloudinaryPublic _cloudinary = CloudinaryPublic(
    cloudName,
    uploadPreset,
    cache: false,
  );

  // อัปโหลดรูปภาพไปยัง Cloudinary
  static Future<String?> uploadImage(dynamic imageData, String folderPath) async {
    try {
      print('Starting Cloudinary image upload...');
      
      CloudinaryResponse response;
      
      if (kIsWeb) {
        // สำหรับ Web
        if (imageData is Uint8List) {
          print('Uploading web image to Cloudinary...');
          response = await _cloudinary.uploadFile(
            CloudinaryFile.fromBytesData(
              imageData,
              folder: folderPath,
              resourceType: CloudinaryResourceType.Image,
              identifier: 'unique_identifier', // Replace with a meaningful identifier
            ),
          );
        } else {
          throw Exception('รูปแบบข้อมูลรูปภาพไม่ถูกต้องสำหรับ Web');
        }
      } else {
        // สำหรับ Mobile
        if (imageData is String) {
          print('Uploading mobile image to Cloudinary...');
          final file = File(imageData);
          final fileName = path.basename(file.path);
          
          response = await _cloudinary.uploadFile(
            CloudinaryFile.fromFile(
              file.path,
              folder: folderPath,
              resourceType: CloudinaryResourceType.Image,
            ),
          );
        } else {
          throw Exception('รูปแบบข้อมูลรูปภาพไม่ถูกต้องสำหรับ Mobile');
        }
      }
      
      print('Image uploaded to Cloudinary successfully: ${response.secureUrl}');
      return response.secureUrl;
    } catch (e) {
      print('Error uploading image to Cloudinary: $e');
      return null;
    }
  }
  
  // ลบรูปภาพจาก Cloudinary (ต้องใช้ Admin API ซึ่งไม่ควรทำในแอปโดยตรง)
  // ในการใช้งานจริง ควรทำผ่าน backend server
  static Future<bool> deleteImage(String publicId) async {
    // ฟังก์ชันนี้เป็นตัวอย่างเท่านั้น ไม่ควรใช้ในแอปโดยตรง
    // เนื่องจากต้องใช้ API Key และ API Secret ซึ่งไม่ควรเก็บในแอป
    print('Warning: Deleting images should be done through a backend server');
    return false;
  }
  
  // ตรวจสอบการเชื่อมต่อกับ Cloudinary
  static Future<bool> checkConnection() async {
    try {
      // ทดสอบการเชื่อมต่อโดยการเรียกดู API ที่ไม่ต้องการการยืนยันตัวตน
      final response = await http.get(
        Uri.parse('https://res.cloudinary.com/$cloudName/image/upload/sample'),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('Error checking Cloudinary connection: $e');
      return false;
    }
  }
}
