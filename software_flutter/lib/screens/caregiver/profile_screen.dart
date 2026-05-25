import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'home_screen.dart';
import 'medication_history_screen.dart';
import 'patient_medications_screen.dart';
import 'notifications_screen.dart';
import 'edit_personal_info_screen.dart';
import 'link_patient_screen.dart';
import 'about_us_screen.dart';
import '../login_screen.dart';

class CaregiverProfileScreen extends StatefulWidget {
  final String patientId;

  const CaregiverProfileScreen({super.key, required this.patientId});

  @override
  State<CaregiverProfileScreen> createState() => _CaregiverProfileScreenState();
}

class _CaregiverProfileScreenState extends State<CaregiverProfileScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // --- Navigation Helpers ---

  void _goHome() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const CaregiverHomeScreen()),
      (route) => false,
    );
  }

  void _navigateToHistory(String? currentId) {
    if (currentId == null || currentId.isEmpty) {
      return;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MedicationHistoryScreen(
          patientId: currentId,
          patientName: "Patient",
        ),
      ),
    );
  }

  void _navigateToMedication(String? currentId) {
    if (currentId == null || currentId.isEmpty) {
      return;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PatientMedicationsScreen(patientId: currentId),
      ),
    );
  }

  void _navigateToNotifications(String? currentId) {
    if (currentId == null || currentId.isEmpty) {
      return;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) =>
              CaregiverNotificationsScreen(patientId: currentId)),
    );
  }

  // --- Unlink Patient ---
  Future<void> _handleRemovePatient(String patientUid) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("unlink_patient".tr()),
        content: Text("confirm_unlink_patient".tr()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("cancel".tr())),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _executeUnlink(patientUid);
            },
            child: Text("unlink".tr(),
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _executeUnlink(String patientUid) async {
    final String? caregiverUid = _auth.currentUser?.uid;
    if (caregiverUid == null) return;

    try {
      WriteBatch batch = _firestore.batch();

      batch.update(_firestore.collection('users').doc(patientUid), {
        'linkedCaregiverId': FieldValue.delete(),
      });

      batch.update(_firestore.collection('users').doc(caregiverUid), {
        'linkedPatientId': FieldValue.delete(),
      });

      await batch.commit();

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint("Unlink Error: $e");
    }
  }

  // --- Settings Actions ---

  void _showLanguageSelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("language".tr(),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              _buildLanguageOption("English"),
              _buildLanguageOption("Bahasa Melayu"),
              _buildLanguageOption("中文"),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLanguageOption(String lang) {
    Locale locale;
    if (lang == "English")
      locale = const Locale('en');
    else if (lang == "Bahasa Melayu")
      locale = const Locale('ms');
    else
      locale = const Locale('zh');
    bool isSelected = context.locale.languageCode == locale.languageCode;

    return ListTile(
      title: Text(lang, textAlign: TextAlign.center),
      selected: isSelected,
      selectedTileColor: const Color(0xFFFCE7F3),
      onTap: () {
        context.setLocale(locale);
        Navigator.pop(context);
      },
    );
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("logout".tr()),
        content: Text("confirm_logout".tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("cancel".tr(),
                style:
                    const TextStyle(color: Color.fromARGB(255, 134, 132, 132))),
          ),
          TextButton(
            onPressed: () async {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            child: Text("logout".tr(),
                style: const TextStyle(
                    color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String? userId = _auth.currentUser?.uid;

    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('users').doc(userId).snapshots(),
      builder: (context, snapshot) {
        String fullName = "Loading...";
        String caregiverIdDisplay = "...";
        String email = "...";
        String phone = "...";
        String? profileImageUrl;
        String? currentPatientId;

        if (snapshot.hasData && snapshot.data!.exists) {
          var data = snapshot.data!.data() as Map<String, dynamic>;
          fullName = data['fullName'] ?? "No Name";
          caregiverIdDisplay = data['caregiverId'] ?? "N/A";
          email = data['email'] ?? "No Email";
          phone = data['phone'] ?? "No Phone";
          profileImageUrl = data['profileImageUrl'];
          currentPatientId = data['linkedPatientId'];
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF9FAFB),
          body: Column(
            children: [
              // --- HEADER & AVATAR ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 40, bottom: 20),
                decoration: const BoxDecoration(
                  color: Color(0xFFEC4899),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back,
                                color: Colors.white),
                            onPressed: _goHome,
                          ),
                          Text(
                            "profile".tr(),
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    CircleAvatar(
                      radius: 45,
                      backgroundColor: Colors.white,
                      backgroundImage: profileImageUrl != null
                          ? NetworkImage(profileImageUrl)
                          : null,
                      child: profileImageUrl == null
                          ? const Icon(Icons.person,
                              size: 50, color: Color(0xFFEC4899))
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      fullName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "caregiver".tr(),
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),

              // --- MAIN CONTENT ---
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      _buildInfoCard(
                        title: "personal_info".tr(),
                        onEdit: () {
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    const CaregiverEditPersonalInfoScreen()),
                          );
                        },
                        items: [
                          _buildInfoRow(Icons.description_outlined,
                              "caregiver_id".tr(), caregiverIdDisplay),
                          _buildInfoRow(
                              Icons.mail_outline, "email".tr(), email),
                          _buildInfoRow(
                              Icons.phone_outlined, "phone".tr(), phone),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildInfoCard(
                        title: "linked_patient".tr(),
                        onRemove: currentPatientId != null
                            ? () => _handleRemovePatient(currentPatientId!)
                            : null,
                        onAdd: currentPatientId == null
                            ? () {
                                ScaffoldMessenger.of(context)
                                    .hideCurrentSnackBar();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const LinkPatientScreen()),
                                );
                              }
                            : null,
                        items: [
                          currentPatientId == null
                              ? _buildInfoRow(Icons.person_outline,
                                  "patient_id".tr(), "not_linked".tr())
                              : _buildLinkedPatientItem(currentPatientId),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildSettingsCard(),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _navigateToMedication(currentPatientId),
            backgroundColor: const Color(0xFFEC4899),
            shape: const CircleBorder(),
            child: const Icon(Icons.medical_services_outlined,
                color: Colors.white),
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,
          bottomNavigationBar: BottomAppBar(
            color: const Color.fromARGB(255, 246, 229, 230),
            shape: const CircularNotchedRectangle(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildNavItem(
                      Icons.home_outlined, "home".tr(), false, _goHome),
                  _buildNavItem(Icons.history, "history".tr(), false,
                      () => _navigateToHistory(currentPatientId)),
                  const SizedBox(width: 40),
                  _buildNavItem(
                      Icons.notifications_outlined,
                      "notification".tr(),
                      false,
                      () => _navigateToNotifications(currentPatientId)),
                  _buildNavItem(Icons.person, "profile".tr(), true, () {}),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --- UI Components ---

  Widget _buildInfoCard({
    required String title,
    VoidCallback? onEdit,
    VoidCallback? onAdd,
    VoidCallback? onRemove,
    required List<Widget> items,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF374151))),
              if (onEdit != null)
                GestureDetector(
                  onTap: onEdit,
                  child: Row(
                    children: [
                      const Icon(Icons.edit,
                          size: 16, color: Color(0xFFEC4899)),
                      const SizedBox(width: 4),
                      Text("edit".tr(),
                          style: const TextStyle(
                              color: Color(0xFFEC4899), fontSize: 13)),
                    ],
                  ),
                ),
              if (onAdd != null)
                GestureDetector(
                  onTap: onAdd,
                  child: Row(
                    children: [
                      const Icon(Icons.add, size: 16, color: Color(0xFFEC4899)),
                      const SizedBox(width: 4),
                      Text("add".tr(),
                          style: const TextStyle(
                              color: Color(0xFFEC4899), fontSize: 13)),
                    ],
                  ),
                ),
              if (onRemove != null)
                GestureDetector(
                  onTap: onRemove,
                  child: const Icon(Icons.person_remove_outlined,
                      size: 18, color: Colors.red),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ...items,
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.grey, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
                Text(value,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1F2937))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkedPatientItem(String patientUid) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('users').doc(patientUid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Text("Loading patient data...",
              style: TextStyle(color: Colors.grey, fontSize: 13));
        }

        var data = snapshot.data!.data() as Map<String, dynamic>;
        String name = data['fullName'] ?? "patient".tr();
        String age = data['age']?.toString() ?? "--";
        String genderRaw = data['gender'] ?? "--";
        String gender =
            (genderRaw == "--") ? "--" : genderRaw.toLowerCase().tr();
        String height = data['height']?.toString() ?? "--";
        String weight = data['weight']?.toString() ?? "--";
        String notes = data['medicalNotes'] ?? "none".tr();

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                  color: Color(0xFFFCE7F3), shape: BoxShape.circle),
              child:
                  const Icon(Icons.person, color: Color(0xFFEC4899), size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF1F2937))),
                  Text("$age ${"years".tr()}, $gender",
                      style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 8),
                  Text(
                      "${"height".tr()}: $height m | ${"weight".tr()}: $weight kg",
                      style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text("${"medical_notes".tr()}: $notes",
                      style: const TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSettingsCard() {
    final currentLocale = context.locale;
    String langDisplay = "English";
    if (currentLocale.languageCode == 'ms') langDisplay = "Bahasa Melayu";
    if (currentLocale.languageCode == 'zh') langDisplay = "中文";

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: [
          _buildSettingsItem(Icons.language, "language".tr(),
              subtitle: langDisplay, onTap: _showLanguageSelector),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          _buildSettingsItem(Icons.info_outline, "about_us".tr(), onTap: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            Navigator.push(context,
                MaterialPageRoute(builder: (context) => const AboutUsScreen()));
          }),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          _buildSettingsItem(Icons.logout, "logout".tr(),
              isDestructive: true, onTap: _handleLogout),
        ],
      ),
    );
  }

  Widget _buildSettingsItem(IconData icon, String title,
      {String? subtitle, bool isDestructive = false, VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: isDestructive ? Colors.red : Colors.grey),
      title: Text(title,
          style: TextStyle(
              color: isDestructive ? Colors.red : const Color(0xFF1F2937),
              fontWeight: FontWeight.w500)),
      subtitle: subtitle != null
          ? Text(subtitle, style: const TextStyle(color: Color(0xFFEC4899)))
          : null,
      trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
      onTap: onTap,
    );
  }

  Widget _buildNavItem(
      IconData icon, String label, bool isActive, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: isActive ? const Color(0xFFEC4899) : Colors.grey),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: isActive ? const Color(0xFFEC4899) : Colors.grey,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}
