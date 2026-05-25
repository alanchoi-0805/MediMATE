import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'home_screen.dart';
import 'patient_medications_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';

class MedicationHistoryScreen extends StatefulWidget {
  final String patientName;
  final String patientId;

  const MedicationHistoryScreen({
    super.key,
    this.patientName = "Patient",
    required this.patientId,
  });

  @override
  State<MedicationHistoryScreen> createState() =>
      _MedicationHistoryScreenState();
}

class _MedicationHistoryScreenState extends State<MedicationHistoryScreen> {
  String selectedSlot = 'all_slots';

  // Helper to determine if a patient is valid
  bool get _isNotLinked =>
      widget.patientId == "Not Linked" || widget.patientId.isEmpty;

  // --- Navigation Helpers ---
  void _goBack() => Navigator.of(context).pop();

  void _navigateToMedication() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
          builder: (context) =>
              PatientMedicationsScreen(patientId: widget.patientId)),
    );
  }

  void _goHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const CaregiverHomeScreen()),
    );
  }

  void _navigateToNotifications() {
    if (_isNotLinked) return; // Prevent navigation if not linked
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
          builder: (context) =>
              CaregiverNotificationsScreen(patientId: widget.patientId)),
    );
  }

  void _navigateToProfile() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
          builder: (context) =>
              CaregiverProfileScreen(patientId: widget.patientId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // --- If no patient is linked ---
    if (_isNotLinked) {
      return Scaffold(
        backgroundColor: const Color(0xFFF9FAFB),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: const Color(0xFFF13E94),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: _goBack,
          ),
          title: Text("medication_history".tr(),
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.history, size: 80, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                "please_link_patient_in_profile".tr(),
                style: const TextStyle(
                    fontSize: 18,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _navigateToProfile,
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF13E94)),
                child: Text("go_to_profile".tr(),
                    style: const TextStyle(color: Colors.white)),
              )
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _navigateToMedication,
          backgroundColor: const Color(0xFFEC4899),
          shape: const CircleBorder(),
          child:
              const Icon(Icons.medical_services_outlined, color: Colors.white),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: _buildStaticBottomNav(),
      );
    }

    // --- ORIGINAL UI (Only runs if patientId is valid) ---
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF9FAFB),
        body: Column(
          children: [
            // --- HEADER SECTION ---
            Container(
              padding: const EdgeInsets.only(top: 25, bottom: 20),
              decoration: const BoxDecoration(
                color: Color(0xFFF13E94),
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
                          icon:
                              const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: _goBack,
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "medication_history".tr(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            StreamBuilder<DocumentSnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(widget.patientId)
                                  .snapshots(),
                              builder: (context, snapshot) {
                                String displayName = widget.patientName;
                                if (snapshot.hasData && snapshot.data!.exists) {
                                  var data = snapshot.data!.data()
                                      as Map<String, dynamic>;
                                  displayName =
                                      data['fullName'] ?? widget.patientName;
                                }
                                return Text(
                                  displayName,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: TabBar(
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      indicator: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      labelColor: const Color(0xFFF13E94),
                      unselectedLabelColor: Colors.white,
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                      tabs: [
                        Tab(text: 'all'.tr()),
                        Tab(text: 'taken'.tr()),
                        Tab(text: 'missed'.tr()),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        'all_slots',
                        'slot_1',
                        'slot_2',
                        'slot_3',
                        'slot_4'
                      ].map((slotKey) {
                        bool isSelected = selectedSlot == slotKey;
                        final slotLabel = slotKey == 'all_slots'
                            ? 'all_slots'.tr()
                            : tr('slot_label', args: [slotKey.split('_').last]);
                        return GestureDetector(
                          onTap: () => setState(() => selectedSlot = slotKey),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              slotLabel,
                              style: TextStyle(
                                color: isSelected
                                    ? const Color(0xFFF13E94)
                                    : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
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
        floatingActionButton: FloatingActionButton(
          onPressed: _navigateToMedication,
          backgroundColor: const Color(0xFFEC4899),
          shape: const CircleBorder(),
          child:
              const Icon(Icons.medical_services_outlined, color: Colors.white),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: _buildStaticBottomNav(),
      ),
    );
  }

  Widget _buildStaticBottomNav() {
    return BottomAppBar(
      color: const Color.fromARGB(255, 246, 229, 230),
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildNavItem(Icons.home_outlined, 'home'.tr(), false, _goHome),
            _buildNavItem(Icons.history, 'history'.tr(), true, () {}),
            const SizedBox(width: 40),
            _buildNavItem(Icons.notifications_outlined, 'notification'.tr(),
                false, _navigateToNotifications),
            _buildNavItem(Icons.person_outline, 'profile'.tr(), false,
                _navigateToProfile),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList(String statusFilter) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.patientId)
          .collection('history')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFFF13E94)));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
              child: Text("no_records_found".tr(),
                  style: const TextStyle(color: Colors.grey)));
        }

        List<Map<String, dynamic>> historyData = snapshot.data!.docs.map((doc) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

          // --- TYPE FIX START ---
          DateTime dateTime;
          dynamic ts = data['timestamp'];
          if (ts is Timestamp) {
            dateTime = ts.toDate();
          } else if (ts is int) {
            // Converts Unix integer from ESP32 to DateTime
            dateTime = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
          } else {
            dateTime = DateTime.now();
          }
          // --- TYPE FIX END ---

          String dayLabel;
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final yesterday = DateTime(now.year, now.month, now.day - 1);
          final checkDate =
              DateTime(dateTime.year, dateTime.month, dateTime.day);

          if (checkDate == today) {
            dayLabel = 'Today';
          } else if (checkDate == yesterday) {
            dayLabel = 'Yesterday';
          } else {
            dayLabel = DateFormat('dd/MM/yyyy').format(dateTime);
          }

          final slotNumber = data['slot']?.toString() ?? '1';
          return {
            'day': dayLabel,
            'slot': 'slot_$slotNumber',
            'title': data['medicineName'] ?? 'Medication',
            'time': data['time'] ?? '--:--',
            'status': data['status']?.toString().toLowerCase() ?? 'missed',
          };
        }).toList();

        final filteredData = historyData.where((item) {
          bool statusMatch =
              statusFilter == 'all' || item['status'] == statusFilter;
          bool slotMatch =
              selectedSlot == 'all_slots' || item['slot'] == selectedSlot;
          return statusMatch && slotMatch;
        }).toList();

        if (filteredData.isEmpty) {
          return Center(
              child: Text("no_records_found".tr(),
                  style: const TextStyle(color: Colors.grey)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
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
                    padding: const EdgeInsets.only(top: 10, bottom: 15),
                    child: Text(
                      _translateDayLabel(item['day']),
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4B5563)),
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
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color:
                  isTaken ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isTaken ? Icons.check_circle_outline : Icons.cancel_outlined,
              color: isTaken ? Colors.green : Colors.red,
              size: 24,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_translateSlotLabel(item['slot']),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                Text(item['title'],
                    style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                item['time'],
                style: const TextStyle(
                  color: Color(0xFF1F2937),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isTaken
                      ? const Color(0xFFE8F5E9)
                      : const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isTaken ? 'taken'.tr() : 'missed'.tr(),
                  style: TextStyle(
                    color: isTaken ? Colors.green : Colors.red,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _translateDayLabel(String dayLabel) {
    if (dayLabel == 'Today') return 'today'.tr();
    if (dayLabel == 'Yesterday') return 'yesterday'.tr();
    return dayLabel;
  }

  String _translateSlotLabel(String slot) {
    if (slot == 'all_slots') return 'all_slots'.tr();
    final slotNumber = slot.split('_').last;
    return tr('slot_label', args: [slotNumber]);
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
          Icon(icon, color: isActive ? const Color(0xFFF13E94) : Colors.grey),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isActive ? const Color(0xFFF13E94) : Colors.grey,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
