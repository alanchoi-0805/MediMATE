import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'patient/home_screen.dart';
import 'caregiver/home_screen.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  bool _isLoading = false;

  // --- CHECK FOR EXISTING ROLE FIRST ---
  Future<void> _updateRole(String role) async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDocRef =
          FirebaseFirestore.instance.collection('users').doc(user.uid);
      final userDoc = await userDocRef.get();

      if (userDoc.exists && userDoc.data() != null) {
        Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;

        if (data.containsKey('role') &&
            data['role'] != null &&
            data['role'] != "") {
          _navigateToHome(data['role']);
          return;
        }
      }

      final usersRef = FirebaseFirestore.instance.collection('users');
      final querySnapshot = await usersRef.where('role', isEqualTo: role).get();
      int count = querySnapshot.docs.length + 1;

      String prefix = role == "Patient" ? "PT" : "CG";
      String generatedId = "$prefix-${count.toString().padLeft(3, '0')}";

      await userDocRef.update({
        'role': role,
        'patientId':
            role == "Patient" ? generatedId : (userDoc.get('patientId') ?? ""),
        'caregiverId': role == "Caregiver"
            ? generatedId
            : (userDoc.get('caregiverId') ?? ""),
        'isFirstLogin': false,
      });

      debugPrint("New ID Assigned: $generatedId");
      _navigateToHome(role);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Error: ${e.toString()}"),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Helper function for navigation
  void _navigateToHome(String role) {
    if (!mounted) return;

    Widget nextScreen = role == "Patient"
        ? const PatientHomeScreen()
        : const CaregiverHomeScreen();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => nextScreen),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF1F2), Colors.white],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/images/logo.png', width: 200),
                  const SizedBox(height: 24),
                  const Text(
                    "Welcome to MediMATE",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text("Please select your role",
                      style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 48),
                  _buildRoleCard(
                    title: "I am a Patient",
                    subtitle: "Manage my medication schedule",
                    icon: Icons.person_outline,
                    onTap: () => _updateRole("Patient"),
                  ),
                  const SizedBox(height: 20),
                  _buildRoleCard(
                    title: "I am a Caregiver",
                    subtitle: "Monitor patient medication",
                    icon: Icons.favorite_border,
                    onTap: () => _updateRole("Caregiver"),
                  ),
                ],
              ),
              if (_isLoading)
                Container(
                  color: Colors.black45,
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFCE7F3), width: 2),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFFDF2F8),
                radius: 28,
                child: Icon(icon, color: const Color(0xFFEC4899), size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(subtitle,
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
