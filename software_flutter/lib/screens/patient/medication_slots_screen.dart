import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'medication_details_screen.dart';
import 'schedule_medication_screen.dart';
import 'medication_history_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';

class MedicationSlotsScreen extends StatefulWidget {
  final String? targetUserId;
  const MedicationSlotsScreen({super.key, this.targetUserId});

  @override
  State<MedicationSlotsScreen> createState() => _MedicationSlotsScreenState();
}

class _MedicationSlotsScreenState extends State<MedicationSlotsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
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

  String get effectiveUserId =>
      widget.targetUserId ?? _auth.currentUser?.uid ?? "";

  void _goHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _navigateToHistory() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MedicationHistoryScreen()),
    );
  }

  void _navigateToNotifications() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const NotificationsScreen()),
    );
  }

  void _navigateToProfile() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const ProfileScreen()),
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
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
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
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back,
                      color: Colors.white, size: 22),
                  onPressed: _goHome,
                ),
                const SizedBox(width: 8),
                Text(
                  "medication_slots".tr(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: _firestore
                  .collection('users')
                  .doc(effectiveUserId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFFEC4899)));
                }

                Map<String, dynamic> userData = {};
                if (snapshot.hasData && snapshot.data!.exists) {
                  userData = snapshot.data!.data() as Map<String, dynamic>;
                }

                DateTime now = DateTime.now();
                String currentTimeString = DateFormat('HH:mm').format(now);

                List<Map<String, dynamic>> displaySlots =
                    List.generate(4, (index) {
                  int slotNum = index + 1;
                  String slotKey = 'slot$slotNum';
                  dynamic slotData = userData[slotKey];

                  Map<String, dynamic>? slotInfo;
                  if (slotData != null && slotData is Map<String, dynamic>) {
                    slotInfo = Map<String, dynamic>.from(slotData);
                  }

                  if (slotInfo != null &&
                      slotInfo['time'] != null &&
                      slotInfo['date'] != null) {
                    try {
                      List<String> tP = slotInfo['time'].split(':');
                      List<String> dP = slotInfo['date'].split('/');
                      DateTime scheduled = DateTime(
                        int.parse(dP[2]),
                        int.parse(dP[1]),
                        int.parse(dP[0]),
                        int.parse(tP[0]),
                        int.parse(tP[1]),
                      );

                      if (currentTimeString == slotInfo['time']) {
                        slotInfo['status'] = 'alert';
                      }

                      if (now.isAfter(
                          scheduled.add(const Duration(seconds: 60)))) {
                        slotInfo = null;
                      }
                    } catch (e) {}
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
                      Text("manage_medication_slots".tr(),
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 15)),
                      const SizedBox(height: 20),
                      ...displaySlots
                          .map((med) => _buildMedicationCard(context, med)),
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
        child: const Icon(Icons.medical_services_outlined, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
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
              _buildNavItem(
                  Icons.history, "history".tr(), false, _navigateToHistory),
              const SizedBox(width: 40),
              _buildNavItem(Icons.notifications_outlined, "notification".tr(),
                  false, _navigateToNotifications),
              _buildNavItem(Icons.person_outline, "profile".tr(), false,
                  _navigateToProfile),
            ],
          ),
        ),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
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
                  if (med['status'] != 'empty') {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MedicationDetailsScreen(
                            selectedSlot: med['slot'],
                            targetUserId: effectiveUserId,
                          ),
                        ));
                  }
                },
                child: Text(
                    med['status'] == 'empty'
                        ? "slot_is_empty".tr()
                        : "tap_to_view_details".tr(),
                    style: const TextStyle(color: Colors.grey, fontSize: 14)),
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ScheduleMedicationScreen(
                          slotNumber: med['slot'],
                          targetUserId: effectiveUserId,
                        ),
                      ));
                },
                icon: const Icon(Icons.edit_outlined,
                    size: 18, color: Color(0xFFEC4899)),
                label: Text("edit".tr(),
                    style: const TextStyle(color: Color(0xFFEC4899))),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
      IconData icon, String label, bool isActive, VoidCallback onTap) {
    return Theme(
      data: ThemeData(
          splashColor: Colors.transparent, highlightColor: Colors.transparent),
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isActive ? const Color(0xFFEC4899) : Colors.grey),
            Text(label,
                style: TextStyle(
                  fontSize: 10,
                  color: isActive ? const Color(0xFFEC4899) : Colors.grey,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                )),
          ],
        ),
      ),
    );
  }
}
