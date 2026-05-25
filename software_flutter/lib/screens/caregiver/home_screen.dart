import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';

import 'patient_details_screen.dart';
import 'patient_medications_screen.dart';
import 'medication_history_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';

class CaregiverHomeScreen extends StatefulWidget {
  const CaregiverHomeScreen({super.key});

  @override
  State<CaregiverHomeScreen> createState() => _CaregiverHomeScreenState();
}

class _CaregiverHomeScreenState extends State<CaregiverHomeScreen> {
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
      String dateStr = (slot['date'] ??
              slot['intakeDate'] ??
              DateFormat('dd/MM/yyyy').format(_currentTime))
          .toString();
      String timeStr =
          (slot['time'] ?? slot['intakeTime'] ?? "00:00").toString();

      List<String> dP = dateStr.split('/');
      List<String> tP = timeStr.split(':');

      return DateTime(int.parse(dP[2]), int.parse(dP[1]), int.parse(dP[0]),
          int.parse(tP[0]), int.parse(tP[1]));
    } catch (e) {
      return null;
    }
  }

  // --- Navigation Helpers ---

  void _navigateTo(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
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
        builder: (context, caregiverSnapshot) {
          if (!caregiverSnapshot.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFFEC4899)));
          }

          var caregiverData =
              caregiverSnapshot.data!.data() as Map<String, dynamic>? ?? {};
          String caregiverName = caregiverData['fullName'] ?? "caregiver".tr();
          String linkedPatientId = caregiverData['linkedPatientId'] ?? "";

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
                          "hello_name".tr(args: [caregiverName]),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "monitor_patient".tr(),
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 13),
                        ),
                      ],
                    ),
                    _buildLinkedDeviceStatus(linkedPatientId),
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
                                Text("todays_overview".tr(),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                                DateFormat('EEEE, MMMM d, y',
                                        context.locale.toString())
                                    .format(_currentTime),
                                style: const TextStyle(color: Colors.grey)),
                            Text(DateFormat('HH:mm:ss').format(_currentTime),
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // SUMMARY ROW
                      if (linkedPatientId.isNotEmpty)
                        _buildDailyStats(linkedPatientId)
                      else
                        Row(
                          children: [
                            Expanded(
                                child: Text("no_patient_linked".tr(),
                                    style:
                                        const TextStyle(color: Colors.grey))),
                          ],
                        ),

                      const SizedBox(height: 30),
                      Text("my_patient".tr(),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),

                      // PATIENT INFO CARD
                      if (linkedPatientId.isNotEmpty)
                        _buildPatientInfoStream(linkedPatientId)
                      else
                        _buildWhiteCard(
                            child: Text("link_patient_prompt".tr())),

                      const SizedBox(height: 30),
                      Text("next_doses".tr(),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),

                      // NEXT DOSES
                      if (linkedPatientId.isNotEmpty)
                        _buildNextDosesStream(linkedPatientId)
                      else
                        Text("no_doses_scheduled".tr(),
                            style: const TextStyle(color: Colors.grey)),

                      const SizedBox(height: 80), // Padding for FAB
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),

      // --- CENTERED ACTION BUTTON ---
      floatingActionButton: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(_uid)
              .snapshots(),
          builder: (context, snapshot) {
            String pId = "";
            if (snapshot.hasData) {
              pId = (snapshot.data!.data()
                      as Map<String, dynamic>?)?['linkedPatientId'] ??
                  "";
            }
            return FloatingActionButton(
              onPressed: () {
                if (pId.isNotEmpty) {
                  _navigateTo(PatientMedicationsScreen(patientId: pId));
                }
              },
              backgroundColor: const Color(0xFFEC4899),
              shape: const CircleBorder(),
              child: const Icon(Icons.medical_services_outlined,
                  color: Colors.white),
            );
          }),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // --- BOTTOM NAVIGATION BAR ---
      bottomNavigationBar: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(_uid)
              .snapshots(),
          builder: (context, snapshot) {
            String pId = "";
            if (snapshot.hasData) {
              var data = snapshot.data!.data() as Map<String, dynamic>?;
              pId = data?['linkedPatientId'] ?? "";
            }

            return BottomAppBar(
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
                        onTap: () {
                      if (pId.isNotEmpty) {
                        _navigateTo(MedicationHistoryScreen(
                          patientId: pId,
                          patientName: "patient".tr(),
                        ));
                      }
                    }),
                    const SizedBox(width: 40), // Space for FAB
                    _buildNavItem(Icons.notifications_outlined,
                        "notification".tr(), false, onTap: () {
                      if (pId.isNotEmpty) {
                        _navigateTo(
                            CaregiverNotificationsScreen(patientId: pId));
                      }
                    }),
                    _buildNavItem(Icons.person_outline, "profile".tr(), false,
                        onTap: () {
                      _navigateTo(CaregiverProfileScreen(patientId: pId));
                    }),
                  ],
                ),
              ),
            );
          }),
    );
  }

  // --- Logic Implementations ---

  Widget _buildLinkedDeviceStatus(String patientId) {
    if (patientId.isEmpty) return _statusBadge("no_patient".tr(), Colors.grey);
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(patientId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return _statusBadge("...", Colors.white);
        }
        var data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        String deviceId = data['deviceId'] ?? "";
        if (deviceId.isEmpty) {
          return _statusBadge("no_device".tr(), Colors.grey);
        }

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('devices')
              .doc(deviceId)
              .snapshots(),
          builder: (context, devSnap) {
            bool isOnline = devSnap.hasData &&
                devSnap.data!.exists &&
                (devSnap.data!.data() as Map<String, dynamic>?)?['status'] ==
                    "online";
            return _statusBadge(isOnline ? "online".tr() : "offline".tr(),
                isOnline ? Colors.green : Colors.white);
          },
        );
      },
    );
  }

  Widget _buildDailyStats(String patientId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(patientId)
          .collection('history')
          .snapshots(),
      builder: (context, snapshot) {
        int taken = 0;
        int missed = 0;

        if (snapshot.hasData) {
          DateTime now = DateTime.now();
          String todayStr = DateFormat('dd/MM/yyyy').format(now);

          for (var doc in snapshot.data!.docs) {
            var data = doc.data() as Map<String, dynamic>;

            bool isToday = false;
            if (data['date'] == todayStr) {
              isToday = true;
            } else if (data['timestamp'] != null) {
              DateTime docDate;
              dynamic ts = data['timestamp'];
              if (ts is Timestamp) {
                docDate = ts.toDate();
              } else if (ts is int) {
                docDate = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
              } else {
                docDate = DateTime.now();
              }
              if (docDate.year == now.year &&
                  docDate.month == now.month &&
                  docDate.day == now.day) {
                isToday = true;
              }
            }

            if (isToday) {
              String status = (data['status'] ?? "").toString().toLowerCase();
              if (status == 'taken') taken++;
              if (status == 'missed') missed++;
            }
          }
        }

        return Row(
          children: [
            Expanded(
              child: _buildSummaryBox(
                  "missed_today".tr(),
                  "$missed ${"doses".tr()}",
                  const Color(0xFFFEF2F2),
                  const Color(0xFFEF4444),
                  Icons.warning_amber_rounded),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryBox(
                  "taken_today".tr(),
                  "$taken ${"doses".tr()}",
                  const Color(0xFFF0FDF4),
                  const Color(0xFF22C55E),
                  Icons.check_circle_outline),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPatientInfoStream(String patientId) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(patientId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        var data = snapshot.data!.data() as Map<String, dynamic>? ?? {};

        String name = data['fullName'] ?? "patient".tr();
        String rawAge = data['age']?.toString() ?? "";
        String ageStr =
            rawAge.isEmpty ? "age_not_set".tr() : "$rawAge ${"years".tr()}";

        return _buildPatientCard(name, ageStr, patientId);
      },
    );
  }

  Widget _buildNextDosesStream(String patientId) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(patientId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        var data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        List<dynamic> rawSlots = [];
        for (int i = 1; i <= 4; i++) {
          if (data['slot$i'] != null &&
              data['slot$i']['medicineName'] != null) {
            rawSlots.add(data['slot$i']);
          }
        }

        List medicationSlots = rawSlots.where((slot) {
          DateTime? slotTime = _parseSlotDateTime(slot);
          if (slotTime == null) return false;
          return _currentTime
              .isBefore(slotTime.add(const Duration(seconds: 60)));
        }).toList();

        if (medicationSlots.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text("no_doses_scheduled".tr(),
                style: const TextStyle(color: Colors.grey)),
          );
        }

        medicationSlots.sort((a, b) => (_parseSlotDateTime(a) ?? DateTime(2000))
            .compareTo(_parseSlotDateTime(b) ?? DateTime(2000)));

        return Column(
          children: medicationSlots.map((slot) {
            String displayDate =
                slot['date'] ?? DateFormat('dd/MM/yyyy').format(_currentTime);
            String displayTime = slot['time'] ?? '--:--';

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildDoseTile(
                slot['medicineName'] ?? "medicine".tr(),
                "$displayDate ${"at".tr()} $displayTime",
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // --- Helper UI Widgets ---

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

  Widget _buildSummaryBox(
      String label, String value, Color bg, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(label,
              style: TextStyle(
                  color: color.withOpacity(0.8),
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildPatientCard(String name, String age, String patientId) {
    return _buildWhiteCard(
      child: Column(
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFFFFF1F2),
                child: Icon(Icons.person, color: Color(0xFFEC4899)),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  Text(age,
                      style: const TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: () =>
                    _navigateTo(PatientDetailsScreen(patientId: patientId)),
                child: Text("view_details".tr(),
                    style: const TextStyle(
                        color: Color(0xFFEC4899),
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ),
            ],
          )
        ],
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
              Text(time, style: const TextStyle(color: Colors.grey)),
            ],
          ),
          const Icon(Icons.access_time, color: Colors.blue),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isSelected,
      {VoidCallback? onTap}) {
    return Theme(
      data: ThemeData(
          splashColor: Colors.transparent, highlightColor: Colors.transparent),
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: isSelected ? const Color(0xFFEC4899) : Colors.grey),
            const SizedBox(height: 4),
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
