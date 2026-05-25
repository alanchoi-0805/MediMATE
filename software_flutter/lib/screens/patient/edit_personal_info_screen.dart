import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:easy_localization/easy_localization.dart';

class EditPersonalInfoScreen extends StatefulWidget {
  const EditPersonalInfoScreen({super.key});

  @override
  State<EditPersonalInfoScreen> createState() => _EditPersonalInfoScreenState();
}

class _EditPersonalInfoScreenState extends State<EditPersonalInfoScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  // Controllers
  late TextEditingController _ageController;
  String _selectedGender = 'female';
  String? _profileImageUrl;
  String _fullName = "";

  bool _isLoading = false;
  bool _isImageUploading = false;
  final List<String> _genderOptions = ['female', 'male', 'other'];

  @override
  void initState() {
    super.initState();
    _ageController = TextEditingController();
    _loadUserData();
  }

  // --- Fetch existing data ---
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
          _fullName = data['fullName'] ?? data['name'] ?? "";
          _ageController.text = data['age']?.toString() ?? "";
          _selectedGender = _genderKeyFromValue(data['gender']?.toString());
          _profileImageUrl = data['profileImageUrl'];
        });
      }
    } catch (e) {
      debugPrint("Error loading data: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _genderKeyFromValue(String? value) {
    if (value == null || value.isEmpty) return 'female';
    final normalized = value.trim().toLowerCase();
    if (['female', 'perempuan', '女'].contains(normalized)) return 'female';
    if (['male', 'lelaki', '男'].contains(normalized)) return 'male';
    if (['other', 'lain-lain', '其他'].contains(normalized)) return 'other';
    if (normalized.contains('female') ||
        normalized.contains('perempuan') ||
        normalized.contains('女')) return 'female';
    if (normalized.contains('male') ||
        normalized.contains('lelaki') ||
        normalized.contains('男')) return 'male';
    if (normalized.contains('other') ||
        normalized.contains('lain') ||
        normalized.contains('其他')) return 'other';
    return 'female';
  }

  @override
  void dispose() {
    _ageController.dispose();
    super.dispose();
  }

  // --- Image Picker and Upload ---
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

      Reference ref = _storage.ref().child('profile_images').child('$uid.jpg');
      UploadTask uploadTask = ref.putFile(file);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

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

  // --- Save Text Data to Firebase ---
  Future<void> _handleSave() async {
    final ageString = _ageController.text.trim();

    setState(() => _isLoading = true);
    try {
      String uid = _auth.currentUser!.uid;

      await _firestore.collection('users').doc(uid).set({
        'age': int.tryParse(ageString) ?? 0,
        'gender': _selectedGender,
      }, SetOptions(merge: true));

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Error saving: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
                  style: const TextStyle(
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
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Name Display (NOW READ-ONLY)
                        _buildInputCard(
                          title: "name".tr(),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
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

                        const SizedBox(height: 20),

                        // Age Input
                        _buildInputCard(
                          title: "age".tr(),
                          child: TextField(
                            controller: _ageController,
                            keyboardType: TextInputType.number,
                            decoration: _inputDecoration("enter_your_age".tr()),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Gender Dropdown
                        _buildInputCard(
                          title: "gender".tr(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedGender,
                                icon: const Icon(Icons.arrow_drop_down,
                                    color: Color(0xFFEC4899)),
                                isExpanded: true,
                                items: _genderOptions.map((String value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(value.tr()),
                                  );
                                }).toList(),
                                onChanged: (newValue) {
                                  setState(() {
                                    _selectedGender = newValue!;
                                  });
                                },
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 30),

                        // Save Button
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleSave,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEC4899),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              elevation: 2,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2),
                                  )
                                : Text(
                                    "save_changes".tr(),
                                    style: const TextStyle(
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

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFEC4899), width: 2),
      ),
    );
  }
}
