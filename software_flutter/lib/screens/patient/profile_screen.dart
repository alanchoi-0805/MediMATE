import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'medication_slots_screen.dart';
import 'medication_history_screen.dart';
import 'notifications_screen.dart';
import 'edit_personal_info_screen.dart';
import 'edit_health_info_screen.dart';
import 'link_device_screen.dart';
import 'about_us_screen.dart';
import '../login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;

  // --- Navigation Helpers ---
  void _goHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _navigateToHistory() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MedicationHistoryScreen()),
    );
  }

  void _navigateToMedication() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MedicationSlotsScreen()),
    );
  }

  void _navigateToNotifications() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const NotificationsScreen()),
    );
  }

  Future<void> _handlePairing(
      String requestId, String caregiverUid, bool accept) async {
    try {
      if (accept) {
        await FirebaseFirestore.instance.collection('users').doc(_uid).update({
          'linkedCaregiverId': caregiverUid,
        });
        await FirebaseFirestore.instance
            .collection('users')
            .doc(caregiverUid)
            .update({
          'linkedPatientId': _uid,
        });
        await FirebaseFirestore.instance
            .collection('pairing_requests')
            .doc(requestId)
            .update({'status': 'accepted'});
      } else {
        await FirebaseFirestore.instance
            .collection('pairing_requests')
            .doc(requestId)
            .delete();
      }
    } catch (e) {
      debugPrint("Pairing Error: $e");
    }
  }

  // --- Device Unlinking Logic ---
  Future<void> _handleUnlinkDevice(String deviceId) async {
    bool confirm = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text("unlink_device".tr()),
            content: Text("unlink_device_confirmation".tr()),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text("cancel".tr())),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text("unlink".tr(),
                    style: const TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    try {
      WriteBatch batch = FirebaseFirestore.instance.batch();

      batch.update(FirebaseFirestore.instance.collection('users').doc(_uid), {
        'deviceId': "",
      });

      batch.update(
          FirebaseFirestore.instance.collection('devices').doc(deviceId), {
        'isLinked': false,
        'ownerId': FieldValue.delete(),
      });

      await batch.commit();
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
              _buildLanguageOption("English", const Locale('en')),
              _buildLanguageOption("Bahasa Melayu", const Locale('ms')),
              _buildLanguageOption("中文", const Locale('zh')),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLanguageOption(String label, Locale locale) {
    bool isSelected = context.locale == locale;

    return ListTile(
      title: Text(label, textAlign: TextAlign.center),
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
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(_uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text("user_data_not_found".tr()));
          }

          var userData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          String? linkedDeviceId = userData['deviceId'];

          String displayName =
              userData['fullName'] ?? userData['name'] ?? "User Name";
          if (displayName.isEmpty) displayName = "User Name";

          String ageValue = userData['age']?.toString() ?? "";
          String ageDisplay =
              (ageValue == "" || ageValue == "0") ? "" : "$ageValue years";

          String genderDisplay = userData['gender'] ?? "";
          if (genderDisplay == "Not Set") {
            genderDisplay = "";
          } else {
            final genderKey = genderDisplay.toLowerCase();
            if (genderKey == 'male' ||
                genderKey == 'lelaki' ||
                genderKey == '男') {
              genderDisplay = 'male'.tr();
            } else if (genderKey == 'female' ||
                genderKey == 'perempuan' ||
                genderKey == '女') {
              genderDisplay = 'female'.tr();
            } else if (genderKey == 'other' ||
                genderKey == 'lain-lain' ||
                genderKey == '其他') {
              genderDisplay = 'other'.tr();
            }
          }

          String heightValue = userData['height']?.toString() ?? "";
          String heightDisplay =
              (heightValue == "" || heightValue == "0" || heightValue == "0.0")
                  ? ""
                  : "$heightValue m";

          String weightValue = userData['weight']?.toString() ?? "";
          String weightDisplay = (weightValue == "" || weightValue == "0")
              ? ""
              : "$weightValue kg";

          String medicalNotesDisplay = userData['medicalNotes'] ?? "";
          if (medicalNotesDisplay == "No notes provided") {
            medicalNotesDisplay = "";
          }

          return Column(
            children: [
              // --- HEADER & AVATAR ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 40, bottom: 20),
                decoration: const BoxDecoration(
                  color: Color(0xFFEC4899),
                  borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30)),
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
                              onPressed: _goHome),
                          Text("profile".tr(), // Translated
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    CircleAvatar(
                      radius: 45,
                      backgroundColor: Colors.white,
                      backgroundImage: userData['profileImageUrl'] != null
                          ? NetworkImage(userData['profileImageUrl'])
                          : null,
                      child: userData['profileImageUrl'] == null
                          ? const Icon(Icons.person,
                              size: 50, color: Color(0xFFEC4899))
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      displayName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold),
                    ),
                    Text("patient".tr(),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 14)),
                  ],
                ),
              ),

              // --- MAIN CONTENT ---
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      _buildPendingRequests(userData['patientId'] ?? ""),

                      // --- PERSONAL INFO ---
                      _buildInfoCard(
                        title: "personal_info".tr(), // Translated
                        onEdit: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    const EditPersonalInfoScreen())),
                        items: [
                          _buildInfoRow(Icons.description_outlined,
                              "patient_id".tr(), userData['patientId'] ?? ""),
                          _buildInfoRow(Icons.mail_outline, "email".tr(),
                              userData['email'] ?? ""),
                          _buildInfoRow(Icons.phone_outlined, "phone".tr(),
                              userData['phone'] ?? ""),
                          _buildInfoRow(Icons.calendar_today_outlined,
                              "age".tr(), ageDisplay),
                          _buildInfoRow(Icons.person_outline, "gender".tr(),
                              genderDisplay),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // --- HEALTH INFO ---
                      _buildInfoCard(
                        title: "health_information".tr(),
                        onEdit: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    const EditHealthInfoScreen())),
                        items: [
                          _buildInfoRow(
                              Icons.straighten, "height".tr(), heightDisplay),
                          _buildInfoRow(Icons.monitor_weight_outlined,
                              "weight".tr(), weightDisplay),
                          _buildInfoRow(Icons.assignment_outlined,
                              "medical_notes".tr(), medicalNotesDisplay),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // --- CAREGIVER SECTION ---
                      _buildCaregiverSection(userData['linkedCaregiverId']),
                      const SizedBox(height: 16),

                      // --- DEVICE SECTION ---
                      _buildInfoCard(
                        title:
                            (linkedDeviceId == null || linkedDeviceId.isEmpty)
                                ? "link_device".tr()
                                : "linked_device".tr(),
                        onAdd:
                            (linkedDeviceId == null || linkedDeviceId.isEmpty)
                                ? () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            const LinkDeviceScreen()))
                                : null,
                        addLabel: "link_device".tr(),
                        onRemove: (linkedDeviceId != null &&
                                linkedDeviceId.isNotEmpty)
                            ? () => _handleUnlinkDevice(linkedDeviceId)
                            : null,
                        items: [
                          _buildInfoRow(
                              Icons.memory,
                              "device_id".tr(),
                              (linkedDeviceId == null || linkedDeviceId.isEmpty)
                                  ? "not_linked".tr()
                                  : linkedDeviceId),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // --- SETTINGS ---
                      _buildSettingsCard(),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),

      // --- BOTTOM NAVIGATION ---
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToMedication,
        backgroundColor: const Color(0xFFEC4899),
        shape: const CircleBorder(),
        child: const Icon(Icons.medical_services_outlined, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: const Color.fromARGB(255, 246, 229, 230),
        shape: const CircularNotchedRectangle(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildNavItem(Icons.home_outlined, "home".tr(), false, _goHome),
              _buildNavItem(
                  Icons.history, "history".tr(), false, _navigateToHistory),
              const SizedBox(width: 40),
              _buildNavItem(Icons.notifications_outlined, "notification".tr(),
                  false, _navigateToNotifications),
              _buildNavItem(Icons.person, "profile".tr(), true, () {}),
            ],
          ),
        ),
      ),
    );
  }

  // --- Helpers ---

  Widget _buildPendingRequests(String patientId) {
    if (patientId.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('pairing_requests')
          .where('toPatientId', isEqualTo: patientId)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        var request = snapshot.data!.docs.first;
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.blue.shade100)),
          child: Column(
            children: [
              Text(
                  "pairing_request_from"
                      .tr(args: [request['fromCaregiverName']]),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                      onPressed: () => _handlePairing(
                          request.id, request['fromCaregiverUid'], false),
                      child: Text("decline".tr(),
                          style: const TextStyle(color: Colors.red))),
                  ElevatedButton(
                      onPressed: () => _handlePairing(
                          request.id, request['fromCaregiverUid'], true),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue),
                      child: Text("accept".tr(),
                          style: const TextStyle(color: Colors.white))),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildCaregiverSection(String? caregiverId) {
    if (caregiverId == null || caregiverId.isEmpty) {
      return _buildInfoCard(title: "linked_caregiver".tr(), items: [
        Text("no_caregiver_linked".tr(),
            style: const TextStyle(color: Colors.grey, fontSize: 13))
      ]);
    }
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(caregiverId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        if (!snapshot.data!.exists) {
          return _buildInfoCard(title: "linked_caregiver".tr(), items: [
            Text("caregiver_data_not_found".tr(),
                style: const TextStyle(color: Colors.grey, fontSize: 13))
          ]);
        }

        var cgData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        String cgName = cgData['fullName'] ?? cgData['name'] ?? "Unknown";
        String cgIdStr = cgData['caregiverId'] ?? "N/A";
        String cgPhone = cgData['phone'] ?? "N/A";

        return _buildCaregiverCard(cgName, cgIdStr, cgPhone);
      },
    );
  }

  Widget _buildInfoCard(
      {required String title,
      VoidCallback? onEdit,
      VoidCallback? onAdd,
      String? addLabel,
      VoidCallback? onRemove,
      required List<Widget> items}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade100)),
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
                TextButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit,
                        size: 16, color: Color(0xFFEC4899)),
                    label: Text("edit".tr(),
                        style: const TextStyle(
                            color: Color(0xFFEC4899), fontSize: 13))),
              if (onAdd != null)
                TextButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add,
                        size: 16, color: Color(0xFFEC4899)),
                    label: Text(addLabel ?? "add".tr(),
                        style: const TextStyle(
                            color: Color(0xFFEC4899), fontSize: 13))),
              if (onRemove != null)
                TextButton.icon(
                    onPressed: onRemove,
                    icon:
                        const Icon(Icons.link_off, size: 16, color: Colors.red),
                    label: Text("remove".tr(),
                        style:
                            const TextStyle(color: Colors.red, fontSize: 13))),
            ],
          ),
          const SizedBox(height: 8),
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

  Widget _buildCaregiverCard(String name, String id, String phone) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade100)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("linked_caregiver".tr(),
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                    color: Color(0xFFFCE7F3), shape: BoxShape.circle),
                child: const Icon(Icons.person,
                    color: Color(0xFFEC4899), size: 28),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  Text(id,
                      style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  Text(phone,
                      style: const TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            ],
          ),
        ],
      ),
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
          border: Border.all(color: Colors.grey.shade100)),
      child: Column(
        children: [
          _buildSettingsItem(Icons.language, "language".tr(),
              subtitle: langDisplay, onTap: _showLanguageSelector),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          _buildSettingsItem(Icons.info_outline, "about_us".tr(),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const AboutUsScreen()))),
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
