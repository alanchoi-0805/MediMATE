import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'medication_details_screen.dart';
import 'schedule_medication_screen.dart';
import 'medication_history_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';

class PatientMedicationsScreen extends StatefulWidget {
  final String patientId;

  const PatientMedicationsScreen({super.key, required this.patientId});

  @override
  State<PatientMedicationsScreen> createState() =>
      _PatientMedicationsScreenState();
}

class _PatientMedicationsScreenState extends State<PatientMedicationsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Timer? _expiryRefreshTimer;

  @override
  void initState() {
    super.initState();
    _expiryRefreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _expiryRefreshTimer?.cancel();
    super.dispose();
  }

  void _goHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _navigateToHistory(String name) {
    if (widget.patientId == "Not Linked" || widget.patientId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MedicationHistoryScreen(
          patientId: widget.patientId,
          patientName: name,
        ),
      ),
    );
  }

  void _navigateToNotifications() {
    if (widget.patientId == "Not Linked" || widget.patientId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            CaregiverNotificationsScreen(patientId: widget.patientId),
      ),
    );
  }

  void _navigateToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            CaregiverProfileScreen(patientId: widget.patientId),
      ),
    );
  }

  Map<String, dynamic> getStatusConfig(String status) {
    switch (status) {
      case 'taken':
        return {
          'icon': Icons.check_circle_outline,
          'text': 'taken',
          'color': Colors.green,
          'bg': const Color(0xFFDCFCE7),
          'border': const Color(0xFFBBF7D0),
        };
      case 'alert':
        return {
          'icon': Icons.notifications_active_outlined,
          'text': 'alert',
          'color': Colors.orange,
          'bg': const Color(0xFFFFEDD5),
          'border': const Color(0xFFFED7AA),
        };
      case 'waiting':
        return {
          'icon': Icons.access_time,
          'text': 'waiting',
          'color': Colors.blue,
          'bg': const Color(0xFFE0F2FE),
          'border': const Color(0xFFBAE6FD),
        };
      case 'empty':
      default:
        return {
          'icon': Icons.hourglass_empty,
          'text': 'empty',
          'color': Colors.grey,
          'bg': const Color(0xFFF3F4F6),
          'border': const Color(0xFFE5E7EB),
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isNotLinked =
        widget.patientId == "Not Linked" || widget.patientId.isEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
          // Header
          Container(
            padding:
                const EdgeInsets.only(top: 20, left: 8, right: 24, bottom: 15),
            decoration: const BoxDecoration(
              color: Color(0xFFEC4899),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back,
                        color: Colors.white, size: 22),
                    onPressed: _goHome,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "patient_medications".tr(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: isNotLinked
                ? _buildNotLinkedMessage()
                : StreamBuilder<DocumentSnapshot>(
                    stream: _firestore
                        .collection('users')
                        .doc(widget.patientId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                            child: CircularProgressIndicator(
                                color: Color(0xFFEC4899)));
                      }

                      if (!snapshot.hasData || !snapshot.data!.exists) {
                        return Center(
                            child: Text("patient_data_not_found".tr()));
                      }

                      Map<String, dynamic> userData =
                          snapshot.data?.data() as Map<String, dynamic>? ?? {};
                      String patientName = userData['fullName'] ?? "Patient";
                      DateTime now = DateTime.now();
                      String currentTimeString =
                          DateFormat('HH:mm').format(now);

                      List<Map<String, dynamic>> displaySlots =
                          List.generate(4, (index) {
                        int slotNum = index + 1;
                        String slotKey = 'slot$slotNum';
                        dynamic slotData = userData[slotKey];
                        Map<String, dynamic>? slotInfo;
                        if (slotData != null &&
                            slotData is Map<String, dynamic>) {
                          slotInfo = Map<String, dynamic>.from(slotData);
                        }

                        if (slotInfo != null && slotInfo['time'] != null) {
                          String scheduledTime = slotInfo['time'];
                          if (currentTimeString == scheduledTime &&
                              slotInfo['status'] != 'taken') {
                            slotInfo['status'] = 'alert';
                          } else if (currentTimeString
                                      .compareTo(scheduledTime) >
                                  0 &&
                              slotInfo['status'] != 'taken') {
                            slotInfo = null;
                          }
                        }

                        return slotInfo != null
                            ? {
                                'slot': slotNum,
                                'name': slotInfo['medicineName'] ?? 'Unknown',
                                'time': slotInfo['time'] ?? '--:--',
                                'status': slotInfo['status'] ?? 'waiting',
                              }
                            : {
                                'slot': slotNum,
                                'name': 'empty_slot'.tr(),
                                'time': '--:--',
                                'status': 'empty'
                              };
                      });

                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "medication_slots_for".tr(args: [patientName]),
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 15),
                            ),
                            const SizedBox(height: 20),
                            ...displaySlots.map(
                                (med) => _buildMedicationCard(context, med)),
                            const SizedBox(height: 80),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: const Color(0xFFEC4899),
        shape: const CircleBorder(),
        elevation: 4,
        child: const Icon(Icons.medical_services_outlined, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: isNotLinked
          ? _buildBottomBar(
              "Patient") // Clean UI without stream when not linked
          : StreamBuilder<DocumentSnapshot>(
              stream: _firestore
                  .collection('users')
                  .doc(widget.patientId)
                  .snapshots(),
              builder: (context, snapshot) {
                Map<String, dynamic> bottomData =
                    snapshot.data?.data() as Map<String, dynamic>? ?? {};
                String pName = bottomData['fullName'] ?? "Patient";
                return _buildBottomBar(pName);
              },
            ),
    );
  }

  Widget _buildBottomBar(String pName) {
    return BottomAppBar(
      color: const Color.fromARGB(255, 246, 229, 230),
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      elevation: 10,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildNavItem(Icons.home_outlined, "home".tr(), false, _goHome),
            _buildNavItem(Icons.history, "history".tr(), false,
                () => _navigateToHistory(pName)),
            const SizedBox(width: 40),
            _buildNavItem(Icons.notifications_outlined, "notification".tr(),
                false, _navigateToNotifications),
            _buildNavItem(Icons.person_outline, "profile".tr(), false,
                _navigateToProfile),
          ],
        ),
      ),
    );
  }

  Widget _buildNotLinkedMessage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.person_search_outlined,
              size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            "please_link_patient_in_profile".tr(),
            style: const TextStyle(
                fontSize: 18, color: Colors.grey, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _navigateToProfile,
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEC4899)),
            child: Text("go_to_profile".tr(),
                style: const TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  Widget _buildMedicationCard(BuildContext context, Map<String, dynamic> med) {
    final config = getStatusConfig(med['status']);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: config['border'], width: 2),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: config['bg'],
                    radius: 22,
                    child: Icon(Icons.medical_services_outlined,
                        color: config['color']),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("slot_label".tr(args: [med['slot'].toString()]),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(med['name'],
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 14)),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Icon(config['icon'], size: 16, color: config['color']),
                      const SizedBox(width: 4),
                      Text(config['text'].toString().tr(),
                          style: TextStyle(
                              color: config['color'],
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Text(med['time'], style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: () {
                  if (med['status'] != 'empty' && widget.patientId.isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MedicationDetailsScreen(
                          selectedSlot: med['slot'],
                          targetUserId: widget.patientId,
                        ),
                      ),
                    );
                  }
                },
                child: Text(
                  med['status'] == 'empty'
                      ? "slot_is_empty".tr()
                      : "tap_to_view_details".tr(),
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  if (widget.patientId.isNotEmpty &&
                      widget.patientId != "Not Linked") {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ScheduleMedicationScreen(
                          slotNumber: med['slot'],
                          targetUserId: widget.patientId,
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.edit_outlined,
                    size: 18, color: Color(0xFFEC4899)),
                label: Text("edit".tr(),
                    style: const TextStyle(
                        color: Color(0xFFEC4899), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
      IconData icon, String label, bool isActive, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: isActive ? const Color(0xFFEC4899) : Colors.grey),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: isActive ? const Color(0xFFEC4899) : Colors.grey)),
        ],
      ),
    );
  }
}
