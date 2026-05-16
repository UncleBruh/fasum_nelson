import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:io';
import 'package:shimmer/shimmer.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
class AddPostScreen extends StatefulWidget {
  const AddPostScreen({super.key});

  @override
  State<AddPostScreen> createState() => _AddPostScreenState();
}

class _AddPostScreenState extends State<AddPostScreen> {
  File? _imageFile;
  String? _base64Image;
  final TextEditingController _descriptionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  double? _longitude;
  double? _latitude;
  String? _aiCategory;
  String? _aiDescription;
  bool _isGenerating = false;
  List<String> _categories = [
    'Jalan Rusak',
    'Marka Pudar',
    'Lampu Mati',
    'Trotoar Rusak',
    'Rambu Rusak',
    'Jembatan Rusak',
    'Sampah Menumpuk',
    'Saluran Tersumbat',
    'Sungai Tercemar',
    'Sampah Sungai',
    'Pohon Tumbang',
    'Taman Rusak',
    'Fasilitas Rusak',
    'Pipa Bocor',
    'Vandalisme',
    'Banjir',
    'Lainnya',
  ];

  void _showCategorySelection() {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (BuildContext context) {
      return ListView(
        shrinkWrap: true,
        children: 
          _categories.map((category) {
            return ListTile(
              title: Text(category),
              onTap: () {
                setState(() {
                  _aiCategory =
                      category; // Ganti AI category dengan pilihan user
                });
                Navigator.pop(context);
              }
            );
          }).toList(), // Bagian .toList() dan kurung tutup lainnya tidak terlihat penuh, tapi ini adalah kelanjutan logisnya
      );
    }
  );
}

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
          _aiCategory = null;
          _aiDescription = null;
          _descriptionController.clear();
        });
        await _compressAndEncodeImage();
        await _generateDescriptionWithAI();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }
  
  Future<void> _compressAndEncodeImage() async {
    if(_imageFile == null) return;
    try {
      final compressedImage = await FlutterImageCompress.compressWithFile(
        _imageFile!.path,
        quality: 50,
      );
      if (compressedImage != null) {
        setState(() {
          _base64Image = base64Encode(compressedImage);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error compressing image: $e')),
        );
      }
    }
  }
  
  Future<void> _generateDescriptionWithAI() async {
    if (_imageFile == null) return;
    setState(() => _isGenerating = true);
    try {
      final imageBytes = await _imageFile!.readAsBytes();
      final base64Image = base64Encode(imageBytes);
      const apiKey = 'AIzaSyCtM1pq7nVLAmB7GAJIAIJCygq9iaG6uP8'; // ganti dengan API key kamu
      const url =
          'https://generativelanguage.googleapis.com/v1/models/'
          'gemini-2.0-flash:generateContent?key=$apiKey';
      final body = jsonEncode({
        "contents": [
          {
            "parts": [
              {
                "inlineData": {"mimeType": "image/jpeg", "data": base64Image},
              },
              {
                "text":
                    "Berdasarkan foto ini, identifikasi satu kategori utama kerusakan fasilitas umum "
                    "dari daftar berikut: Jalan Rusak, Marka Pudar, Lampu Mati, Trotoar Rusak, "
                    "Rambu Rusak, Jembatan Rusak, Sampah Menumpuk, Saluran Tersumbat, Sungai Tercemar, "
                    "Sampah Sungai, Pohon Tumbang, Taman Rusak, Fasilitas Rusak, Pipa Bocor, "
                    "Vandalisme, Banjir, dan Lainnya. "
                    "Pilih kategori yang paling dominan atau paling mendesak untuk dilaporkan. "
                    "Buat deskripsi singkat untuk laporan perbaikan, dan tambahkan permohonan perbaikan. "
                    "Fokus pada kerusakan yang terlihat dan hindari spekulasi.\n\n"
                    "Format output yang diinginkan:\n"
                    "Kategori: [satu kategori yang dipilih]\n"
                    "Deskripsi: [deskripsi singkat]",
              },
            ],
          },
        ],
      });
      final headers = {'Content-Type': 'application/json'};
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final text =
            jsonResponse['candidates'][0]['content']['parts'][0]['text'];
        print("AI TEXT: $text");
        if (text != null && text.isNotEmpty) {
          final lines = text.trim().split('\n');
          String? category;
          String? description;
          for (var line in lines) {
            final lower = line.toLowerCase();
            if (lower.startsWith('kategori:')) {
              category = line.substring(9).trim();
            } else if (lower.startsWith('deskripsi:')) {
              description = line.substring(10).trim();
            } else if (lower.startsWith('keterangan:')) {
              description = line.substring(11).trim();
            }
          }
          description ??= text.trim();
          setState(() {
            _aiCategory = category ?? 'Tidak diketahui';
            _aiDescription = description!;
            _descriptionController.text = _aiDescription!;
          });
        }
      } else {
        debugPrint('Request failed: ${response.body}');
      }
    } catch (e) {
      debugPrint('Failed to generate AI description: $e');
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }
  
  Future<void> _getLocation() async {
    try{
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if(!serviceEnabled){
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled. Please enable them in settings.')),
        );
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied. Please grant permission to get location.')),
          );
          return;
        }
      final position = await Geolocator.getCurrentPosition(
        locationSettings:  const LocationSettings(
          accuracy: LocationAccuracy.high
        ),
      ).timeout(const Duration(seconds: 10));
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
      }
    } catch (e){
      debugPrint('Failed to get location: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to get location. Please try again.')),
      );
      setState((){
        _latitude = null;
        _longitude = null;
      });
    }
  }

  void _showImageSourceDialog() {
        showModalBottomSheet(
      context: context,
      builder: (BuildContext context){
        return SafeArea(child: Wrap(
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.cancel),
              title: const Text('Cancel'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ]
        ));
      });
  }

  Future<void> _submitPost() async {
    if(_base64Image == null || _descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide an image and description.')),
      );
      return;
    }
    setState(() => _isUploading = true);
    final now = DateTime.now().toIso8601String();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null){}
    try{
      await _getLocation();
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final fullName = userDoc.data()?['fullName'] ?? 'Anonymous';
      await FirebaseFirestore.instance.collection('posts').add({
        'UserID': uid,
        'fullName': fullName,
        'description': _descriptionController.text,
        'image': _base64Image,
        'category': _aiCategory ?? 'Uncategorized',
        'latitude': _latitude,
        'longitude': _longitude,
        'timestamp': now,
      });
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post submitted successfully.')),
      );
    } catch (e){
      debugPrint('upload failed: $e');
      if (!mounted) return;
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to upload post. $e')));
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Post'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              onTap: _showImageSourceDialog,
              child: Container(
                height: 250,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _imageFile != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _imageFile!,
                          height: 250,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      )
                    : const Center(
                        child: Icon(
                          Icons.add_a_photo,
                          size: 50,
                          color: Colors.grey,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            if (_isGenerating)
              Shimmer.fromColors(
                baseColor: Colors.grey[300]!,
                highlightColor: Colors.grey[100]!,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height:20,
                      width:100,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      margin: const EdgeInsets.only(bottom: 12),
                    ),
                    Container(
                      height: 20,
                      width: 100,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                      ),
                    )
                  ],
                ),
              ),
            if (_aiCategory != null && !_isGenerating)
              Padding(
                padding: const EdgeInsetsGeometry.only(bottom: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: _showCategorySelection,
                      child: Chip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_aiCategory!),
                            const SizedBox(width: 4),
                            const Icon(Icons.edit, size: 16)
                          ]
                        ),
                      ),
                    ),
                    if (_imageFile != null)
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        tooltip: 'Generate another description',
                        onPressed: _generateDescriptionWithAI,
                      ),
                  ],
                ),
              ),
          Offstage(
            offstage: _isGenerating,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                TextField(
                  controller: _descriptionController,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    hintText: 'Add a brief description...',
                    border: OutlineInputBorder(),
                  ), 
                ), 
              ],
            ), 
          ), 
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isUploading ? null : _submitPost,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 16),
                backgroundColor: Colors.green,
              ),
              child: _isUploading
              ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
              )
            : const Text('Post',style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }
}