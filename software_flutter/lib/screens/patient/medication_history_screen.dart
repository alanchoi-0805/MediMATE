import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'medication_slots_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';

class MedicationHistoryScreen extends StatefulWidget {
  const MedicationHistoryScreen({super.key});

  @override
  State<MedicationHistoryScreen> createState() =>
      _MedicationHistoryScreenState();
}

class _MedicationHistoryScreenState extends State<MedicationHistoryScreen> {
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? "";

  // --- Navigation Helpers ---

  void _navigateToMedication() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MedicationSlotsScreen()),
    );
  }

  void _goHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF9FAFB),
        body: Column(
          children: [
            // --- HEADER & TABS ---
            Container(
              padding: const EdgeInsets.only(top: 25, bottom: 20),
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
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back,
                              color: Colors.white, size: 22),
                          onPressed: _goHome,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "medication_history".tr(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    height: 45,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TabBar(
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      indicator: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      labelColor: const Color(0xFFEC4899),
                      unselectedLabelColor: Colors.white,
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                      tabs: [
                        Tab(text: "all".tr()),
                        Tab(text: "taken".tr()),
                        Tab(text: "missed".tr()),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // --- LIST CONTENT ---
            Expanded(
              child: TabBarView(
                children: [
                  _buildHistoryList('all'),
                  _buildHistoryList('taken'),
                  _buildHistoryList('missed'),
                ],
              ),
            ),
          ],
        ),

        // --- BOTTOM NAVIGATION ---
        floatingActionButton: FloatingActionButton(
          onPressed: _navigateToMedication,
          backgroundColor: const Color(0xFFEC4899),
          shape: const CircleBorder(),
          child:
              const Icon(Icons.medical_services_outlined, color: Colors.white),
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
                _buildNavItem(Icons.history, "history".tr(), true, () {}),
                const SizedBox(width: 40),
                _buildNavItem(Icons.notifications_outlined, "notification".tr(),
                    false, _navigateToNotifications),
                _buildNavItem(Icons.person_outline, "profile".tr(), false,
                    _navigateToProfile),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryList(String filter) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('history')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFFEC4899)));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
              child: Text("no_records_found".tr(),
                  style: const TextStyle(color: Colors.grey)));
        }

        List<Map<String, dynamic>> historyData = snapshot.data!.docs
            .map((doc) {
              Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

              DateTime dateTime;
              if (data['timestamp'] is Timestamp) {
                dateTime = (data['timestamp'] as Timestamp).toDate();
              } else {
                dateTime = DateTime.now();
              }

              // --- FIXED SMART DATE LOGIC ---
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              final checkDate =
                  DateTime(dateTime.year, dateTime.month, dateTime.day);

              if (checkDate.isAtSameMomentAs(today)) {
                return {
                  'day': 'today'.tr(),
                  'slot':
                      'slot_label'.tr(args: [data['slot']?.toString() ?? '1']),
                  'desc': data['medicineName'] ?? 'medicine'.tr(),
                  'time': data['time'] ?? '--:--',
                  'status':
                      data['status']?.toString().toLowerCase() ?? 'missed',
                };
              } else {
                return null;
              }
            })
            .where((item) => item != null)
            .cast<Map<String, dynamic>>()
            .toList();

        final filteredData = filter == 'all'
            ? historyData
            : historyData.where((item) => item['status'] == filter).toList();

        if (filteredData.isEmpty) {
          return Center(
              child: Text("no_records_found".tr(),
                  style: const TextStyle(color: Colors.grey)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: filteredData.length,
          itemBuilder: (context, index) {
            final item = filteredData[index];
            bool showHeader =
                index == 0 || filteredData[index - 1]['day'] != item['day'];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showHeader)
                  Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 12),
                    child: Text(
                      item['day'],
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF374151)),
                    ),
                  ),
                _buildHistoryCard(item),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> item) {
    bool isTaken = item['status'] == 'taken';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color:
                    isTaken ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                shape: BoxShape.circle),
            child: Icon(
                isTaken ? Icons.check_circle_outline : Icons.cancel_outlined,
                color: isTaken ? Colors.green : Colors.red,
                size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['slot'],
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                Text(item['desc'],
                    style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(item['time'],
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isTaken
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isTaken ? "taken".tr() : "missed".tr(),
                  style: TextStyle(
                      color: isTaken ? Colors.green : Colors.red,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
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
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isActive ? const Color(0xFFEC4899) : Colors.grey),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isActive ? const Color(0xFFEC4899) : Colors.grey,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
