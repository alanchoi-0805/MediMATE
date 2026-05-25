import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'medication_slots_screen.dart';
import 'medication_history_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';

class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({super.key});

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {
  late DateTime _currentTime;
  late Timer _timer;
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? "";

  @override
  void initState() {
    super.initState();
    _currentTime = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  // --- Logic Helpers ---

  DateTime? _parseSlotDateTime(dynamic slot) {
    if (slot == null) return null;
    try {
      String dateStr =
          (slot['date'] ?? slot['intakeDate'] ?? "01/01/2000").toString();
      String timeStr =
          (slot['time'] ?? slot['intakeTime'] ?? "00:00").toString();

      List<String> dP = dateStr.split('/');
      List<String> tP = timeStr.split(':');

      return DateTime(
        int.parse(dP[2]), // Year
        int.parse(dP[1]), // Month
        int.parse(dP[0]), // Day
        int.parse(tP[0]), // Hour
        int.parse(tP[1]), // Minute
      );
    } catch (e) {
      return null;
    }
  }

  String _getMedicationStatus(List<dynamic> slots) {
    if (slots.isEmpty) return "no_schedule_set";
    DateTime now = DateTime.now();

    List<dynamic> sortedSlots = List.from(slots);
    sortedSlots.sort((a, b) {
      DateTime dtA = _parseSlotDateTime(a) ?? DateTime(2000);
      DateTime dtB = _parseSlotDateTime(b) ?? DateTime(2000);
      return dtA.compareTo(dtB);
    });

    for (var slot in sortedSlots) {
      DateTime? slotTime = _parseSlotDateTime(slot);
      if (slotTime == null) continue;

      if (now.year == slotTime.year &&
          now.month == slotTime.month &&
          now.day == slotTime.day &&
          now.hour == slotTime.hour &&
          now.minute == slotTime.minute) {
        return "action_required_take_dose";
      }

      if (slotTime.isAfter(now)) {
        return "waiting_for_next_dose";
      }
    }

    return "all_doses_completed";
  }

  Map<String, dynamic> _getStatusTheme(String statusKey) {
    if (statusKey == "waiting_for_next_dose") {
      return {
        "icon": Icons.access_time,
        "color": Colors.blue,
        "bg": const Color(0xFFDBEAFE),
        "border": const Color(0xFFBFDBFE),
      };
    } else if (statusKey == "action_required_take_dose") {
      return {
        "icon": Icons.notifications_active,
        "color": Colors.orange,
        "bg": const Color(0xFFFFF7ED),
        "border": const Color(0xFFFFEDD5),
      };
    } else {
      return {
        "icon": Icons.hourglass_empty,
        "color": Colors.grey,
        "bg": const Color(0xFFF3F4F6),
        "border": const Color(0xFFE5E7EB),
      };
    }
  }

  // --- Navigation Helpers ---

  void _navigateToMedication() {
    Navigator.push(context,
        MaterialPageRoute(builder: (context) => const MedicationSlotsScreen()));
  }

  void _navigateToHistory() {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => const MedicationHistoryScreen()));
  }

  void _navigateToNotifications() {
    Navigator.push(context,
        MaterialPageRoute(builder: (context) => const NotificationsScreen()));
  }

  void _navigateToProfile() {
    Navigator.push(context,
        MaterialPageRoute(builder: (context) => const ProfileScreen()));
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
            if (!snapshot.hasData) {
              return const Center(
                  child: CircularProgressIndicator(color: Color(0xFFEC4899)));
            }

            var userData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
            String fullName = userData['fullName'] ?? "User";
            String deviceId = userData['deviceId'] ?? "";

            // --- 4-SLOT INDEPENDENT COLLECTION ---
            List<dynamic> rawSlots = [];

            // Check legacy array first
            if (userData['medicationSlots'] != null) {
              rawSlots.addAll(userData['medicationSlots']);
            }

            // Check independent slot fields
            for (int i = 1; i <= 4; i++) {
              if (userData['slot$i'] != null) {
                var slotData = userData['slot$i'];
                rawSlots.add(slotData);
              }
            }

            // --- AUTO-CLEAR / DISAPPEAR LOGIC ---
            List medicationSlots = rawSlots.where((slot) {
              DateTime? slotTime = _parseSlotDateTime(slot);
              if (slotTime == null) return false;

              // Dose expires 1 minute (59 seconds) after the scheduled time
              DateTime expiryTime = slotTime.add(const Duration(seconds: 60));
              return _currentTime.isBefore(expiryTime);
            }).toList();

            // --- FEATURE: SORT BY DATE AND TIME ---
            medicationSlots.sort((a, b) {
              DateTime dtA = _parseSlotDateTime(a) ?? DateTime(2000);
              DateTime dtB = _parseSlotDateTime(b) ?? DateTime(2000);
              return dtA.compareTo(dtB);
            });

            String statusKey = _getMedicationStatus(medicationSlots);
            String statusText = statusKey.tr();
            Map<String, dynamic> theme = _getStatusTheme(statusKey);

            return Column(
              children: [
                // --- TOP BAR ---
                Container(
                  padding: const EdgeInsets.only(
                      top: 50, left: 24, right: 24, bottom: 20),
                  decoration: const BoxDecoration(
                    color: Color(0xFFEC4899),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "hello_name".tr(args: [fullName]),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold),
                          ),
                          Text(
                            "manage_medication".tr(),
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                      _buildDeviceStatusIndicator(deviceId),
                    ],
                  ),
                ),

                // --- SCROLLABLE MIDDLE CONTENT ---
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildWhiteCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today,
                                      color: Color(0xFFEC4899), size: 24),
                                  const SizedBox(width: 8),
                                  Text("todays_schedule".tr(),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                  DateFormat(
                                          'EEEE, MMMM d, yyyy',
                                          Localizations.localeOf(context)
                                              .toString())
                                      .format(_currentTime),
                                  style: const TextStyle(color: Colors.grey)),
                              Text(DateFormat('HH:mm:ss').format(_currentTime),
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // CURRENT STATUS CARD
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: theme['bg'],
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: theme['border']),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.white,
                                child:
                                    Icon(theme['icon'], color: theme['color']),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("current_status".tr(),
                                      style: const TextStyle(
                                          color: Colors.black54)),
                                  Text(statusText,
                                      style: TextStyle(
                                          color: theme['color'],
                                          fontWeight: FontWeight.bold)),
                                ],
                              )
                            ],
                          ),
                        ),

                        const SizedBox(height: 30),
                        Text("quick_actions".tr(),
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildActionButton(
                                Icons.medical_services_outlined,
                                "medication".tr(),
                                const Color(0xFFFCE7F3),
                                const Color(0xFFEC4899),
                                onTap: _navigateToMedication,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildActionButton(
                                Icons.history,
                                "history".tr(),
                                const Color(0xFFDBEAFE),
                                Colors.blue,
                                onTap: _navigateToHistory,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 30),
                        Text("next_doses".tr(),
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),

                        if (medicationSlots.isEmpty)
                          Text("no_doses_scheduled".tr(),
                              style: const TextStyle(color: Colors.grey))
                        else
                          ...medicationSlots.map((slot) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _buildDoseTile(
                                    slot['medicineName'] ??
                                        slot['name'] ??
                                        "medicine".tr(),
                                    "${slot['date'] ?? slot['intakeDate'] ?? ''} ${'at'.tr()} ${slot['time'] ?? slot['intakeTime'] ?? '--:--'}"),
                              )),

                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
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
        notchMargin: 8,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildNavItem(Icons.home, "home".tr(), true, onTap: () {}),
              _buildNavItem(Icons.history, "history".tr(), false,
                  onTap: _navigateToHistory),
              const SizedBox(width: 40),
              _buildNavItem(
                  Icons.notifications_outlined, "notification".tr(), false,
                  onTap: _navigateToNotifications),
              _buildNavItem(Icons.person_outline, "profile".tr(), false,
                  onTap: _navigateToProfile),
            ],
          ),
        ),
      ),
    );
  }

  // --- Device Status Indicator ---
  Widget _buildDeviceStatusIndicator(String deviceId) {
    if (deviceId.isEmpty) return _statusBadge("no_device".tr(), Colors.grey);

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('devices')
          .doc(deviceId)
          .snapshots(),
      builder: (context, snapshot) {
        bool isOnline = false;
        if (snapshot.hasData && snapshot.data!.exists) {
          var data = snapshot.data!.data() as Map<String, dynamic>;
          isOnline = data['status'] == "online";
        }
        return _statusBadge(isOnline ? "online".tr() : "offline".tr(),
            isOnline ? Colors.green : Colors.white);
      },
    );
  }

  Widget _statusBadge(String label, Color iconColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi, color: iconColor, size: 14),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildWhiteCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
        ],
      ),
      child: child,
    );
  }

  Widget _buildActionButton(
      IconData icon, String label, Color bg, Color iconColor,
      {VoidCallback? onTap}) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.black12),
          ),
          child: Column(
            children: [
              CircleAvatar(
                  backgroundColor: bg, child: Icon(icon, color: iconColor)),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDoseTile(String title, String time) {
    return _buildWhiteCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(time,
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
          const Icon(Icons.access_time, color: Colors.blue),
        ],
      ),
    );
  }

  // UPDATED: This now removes the grey splash/highlight box on click
  Widget _buildNavItem(IconData icon, String label, bool isSelected,
      {VoidCallback? onTap}) {
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
            Icon(icon,
                color: isSelected ? const Color(0xFFEC4899) : Colors.grey),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? const Color(0xFFEC4899) : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
