import 'dart:convert';
// import 'dart:io'; // Remove dart:io as it causes issues on Web
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class ImgBBService {
  // TODO: Replace this with your actual ImgBB API key
  // You can get it by signing up at https://api.imgbb.com/
  static const String _apiKey = '76765f436cd5e133f71b6c6f75e74355';
  static const String _apiUrl = 'https://api.imgbb.com/1/upload';

  /// Picks an image from the gallery or camera and uploads it to ImgBB.
  /// Returns the image URL if successful, otherwise returns null.
  Future<String?> pickAndUploadImage({
    ImageSource source = ImageSource.gallery,
  }) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 70, // Compress image to save bandwidth
      );

      if (image == null) return null; // User canceled

      return await uploadImage(image);
    } catch (e) {
      print('Error picking/uploading image: $e');
      return null;
    }
  }

  /// Uploads a given [XFile] to ImgBB and returns the URL.
  Future<String?> uploadImage(XFile imageFile) async {
    try {
      // Read bytes and encode to base64
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      // Use standard http.post with base64 string to avoid Multipart/Web CORS issues
      final response = await http.post(
        Uri.parse('$_apiUrl?key=$_apiKey'),
        body: {
          'image': base64Image,
        },
      );

      final jsonResponse = jsonDecode(response.body);

      if (response.statusCode == 200 && jsonResponse['success'] == true) {
        // Return the direct URL to the image
        return jsonResponse['data']['url'];
      } else {
        print('ImgBB Upload Failed: ${jsonResponse['error']?['message'] ?? 'Unknown Error'}');
        return null;
      }
    } catch (e) {
      print('Error uploading image to ImgBB: $e');
      return null;
    }
  }
}
