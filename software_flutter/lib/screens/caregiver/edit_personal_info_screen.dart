import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:easy_localization/easy_localization.dart';

class CaregiverEditPersonalInfoScreen extends StatefulWidget {
  const CaregiverEditPersonalInfoScreen({super.key});

  @override
  State<CaregiverEditPersonalInfoScreen> createState() =>
      _CaregiverEditPersonalInfoScreenState();
}

class _CaregiverEditPersonalInfoScreenState
    extends State<CaregiverEditPersonalInfoScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  String? _profileImageUrl;
  String _fullName = "";
  bool _isLoading = false;
  bool _isImageUploading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // --- Logic: Fetch existing data ---
  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(user.uid).get();

      if (userDoc.exists && mounted) {
        Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _fullName = data['fullName'] ?? data['name'] ?? "Caregiver";
          _profileImageUrl = data['profileImageUrl'];
        });
      }
    } catch (e) {
      debugPrint("Error loading data: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- Logic: Image Picker and Upload ---
  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 50,
      );

      if (image == null) return;

      setState(() => _isImageUploading = true);

      String uid = _auth.currentUser!.uid;
      File file = File(image.path);

      // Upload to Firebase Storage
      Reference ref = _storage.ref().child('profile_images').child('$uid.jpg');
      UploadTask uploadTask = ref.putFile(file);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      // Update Firestore immediately
      await _firestore.collection('users').doc(uid).update({
        'profileImageUrl': downloadUrl,
      });

      if (mounted) {
        setState(() {
          _profileImageUrl = downloadUrl;
        });
      }
    } catch (e) {
      debugPrint("Image Error: $e");
    } finally {
      if (mounted) setState(() => _isImageUploading = false);
    }
  }

  void _handleSave() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
          // --- HEADER ---
          Container(
            padding: const EdgeInsets.only(top: 40, bottom: 10, left: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFEC4899),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                Text(
                  "edit_personal_info".tr(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // --- MAIN CONTENT ---
          Expanded(
            child: _isLoading && _fullName.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFEC4899)))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        // Profile Picture Card
                        _buildInputCard(
                          title: "profile_picture".tr(),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                GestureDetector(
                                  onTap: _isImageUploading ? null : _pickImage,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      CircleAvatar(
                                        radius: 50,
                                        backgroundColor:
                                            const Color(0xFFFCE7F3),
                                        backgroundImage: _profileImageUrl !=
                                                null
                                            ? NetworkImage(_profileImageUrl!)
                                            : null,
                                        child: (_profileImageUrl == null &&
                                                !_isImageUploading)
                                            ? const Icon(Icons.person,
                                                size: 60,
                                                color: Color(0xFFEC4899))
                                            : null,
                                      ),
                                      if (_isImageUploading)
                                        const SizedBox(
                                          width: 100,
                                          height: 100,
                                          child: CircularProgressIndicator(
                                            color: Color(0xFFEC4899),
                                            strokeWidth: 3,
                                          ),
                                        ),
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFEC4899),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.camera_alt,
                                              color: Colors.white, size: 18),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  "tap_to_change_picture".tr(),
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Name Input
                        _buildInputCard(
                          title: "name".tr(),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            child: Text(
                              _fullName,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 40),

                        // Save Button
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            onPressed: _handleSave,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEC4899),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              elevation: 2,
                            ),
                            child: Text(
                              "save_changes".tr(),
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // --- UI Helpers ---

  Widget _buildInputCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          child,
        ],
      ),
    );
  }
}
