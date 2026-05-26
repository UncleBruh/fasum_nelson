import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shimmer/shimmer.dart';

class AddPostScreen extends StatefulWidget {
  const AddPostScreen({super.key});

  @override
  State<AddPostScreen> createState() => _AddPostScreenState();
}

class _AddPostScreenState extends State<AddPostScreen> {
  Uint8List? _imageBytes;
  String? _base64Image;

  final TextEditingController _descriptionController = TextEditingController();

  final ImagePicker _picker = ImagePicker();

  bool _isUploading = false;

  double? _latitude;
  double? _longitude;

  String? _aiCategory;
  String? _aiDescription;

  bool _isGeneratingAI = false;

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
    'Fasilitas Umum Rusak',
    'Pipa Bocor',
    'Vadalisme',
    'Banjir',
    'Lainnya',
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(source: source);

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();

        setState(() {
          _imageBytes = bytes;
          _aiCategory = null;
          _aiDescription = null;
          _descriptionController.clear();
        });

        await _compressAndEncodeImage();
        await _generateDescriptionAI();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
      }
    }
  }

  Future<void> _compressAndEncodeImage() async {
    if (_imageBytes == null) return;

    try {
      setState(() {
        _base64Image = base64Encode(_imageBytes!);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error encoding image: $e')));
      }
    }
  }

  Future<void> _generateDescriptionAI() async {
    if (_imageBytes == null) return;

    setState(() => _isGeneratingAI = true);

    try {
      final base64Image = base64Encode(_imageBytes!);
      const apiKey = 'AIzaSyCtM1pq7nVLAmB7GAJIAIJCygq9iaG6uP8';
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

        debugPrint("AI TEXT: $text");

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
      if (mounted) {
        setState(() => _isGeneratingAI = false);
      }
    }
  }

  Future<void> _getLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Layanan lokasi tidak diaktifkan.')),
        );

        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();

        if (permission == LocationPermission.deniedForever ||
            permission == LocationPermission.denied) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Izin lokasi ditolak.')));

          return;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 10));

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
    } catch (e) {
      debugPrint('Failed to get location: $e');

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal mendapatkan lokasi: $e')));

      setState(() {
        _latitude = null;
        _longitude = null;
      });
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Pilih sumber gambar',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (!kIsWeb)
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Ambil Foto'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                )
              else
                ListTile(
                  leading: const Icon(Icons.camera_alt, color: Colors.grey),
                  title: const Text('Ambil Foto (tidak tersedia di Web)'),
                  enabled: false,
                ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Pilih dari galeri'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.cancel),
                title: const Text('Batal'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submitPost() async {
    if (_base64Image == null || _descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add an image and description')),
      );

      return;
    }

    setState(() => _isUploading = true);

    final now = DateTime.now().toIso8601String();

    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      setState(() => _isUploading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User not found. please Sign In")),
      );

      return;
    }

    try {
      await _getLocation();

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      final fullName = userDoc.data()?['fullName'] ?? 'Anonymous';

      await FirebaseFirestore.instance.collection('posts').add({
        'image': _base64Image,
        'description': _descriptionController.text,
        'category': _aiCategory ?? 'Tidak Diketahui',
        'createdAt': now,
        'latitude': _latitude,
        'longitude': _longitude,
        'fullName': fullName,
        'userId': uid,
      });

      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Post Upload Successfully')));
    } catch (e) {
      debugPrint('Upload Failed: $e');

      if (!mounted) return;

      setState(() => _isUploading = false);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to upload post: $e')));
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Post')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              onTap: _showImageSourceDialog,
              child: Container(
                height: 250,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _imageBytes != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          _imageBytes!,
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

            Text('Kategori', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _aiCategory,
              isExpanded: true,
              onChanged: (value) {
                setState(() {
                  _aiCategory = value;
                });
              },
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                hintText: 'Pilih kategori laporan',
              ),
              items: _categories.map((category) {
                return DropdownMenuItem<String>(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            if (_isGeneratingAI)
              Shimmer.fromColors(
                baseColor: Colors.grey[300]!,
                highlightColor: Colors.grey[100]!,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 20,
                      width: 100,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      margin: const EdgeInsets.only(bottom: 12),
                    ),
                    Container(
                      height: 80,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ],
                ),
              ),

            Offstage(
              offstage: _isGeneratingAI,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _descriptionController,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Add a brief description',
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
                      width: 40,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Post', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}