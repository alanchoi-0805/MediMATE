import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:easy_localization/easy_localization.dart';
import 'home_screen.dart';
import 'medication_history_screen.dart';
import 'patient_medications_screen.dart';
import 'profile_screen.dart';

class CaregiverNotificationsScreen extends StatefulWidget {
  final String patientId;

  const CaregiverNotificationsScreen({super.key, required this.patientId});

  @override
  State<CaregiverNotificationsScreen> createState() =>
      _CaregiverNotificationsScreenState();
}

class _CaregiverNotificationsScreenState
    extends State<CaregiverNotificationsScreen> {
  StreamSubscription? _bellSubscription;
  final AudioPlayer _audioPlayer = AudioPlayer();
  String _patientName = "Patient";

  // Helper to determine if a patient is valid
  bool get _isNotLinked =>
      widget.patientId == "Not Linked" || widget.patientId.isEmpty;

  @override
  void initState() {
    super.initState();
    if (!_isNotLinked) {
      _fetchPatientName();
      _setupInAppBellListener();
      _checkInitialUnread();
    }
  }

  @override
  void dispose() {
    _bellSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  // --- Alert Logic ---

  void _playBell() {
    print("🔔 Caregiver Bell Triggered");
    _audioPlayer.play(AssetSource('audio/bell.mp3'));
    HapticFeedback.heavyImpact();
  }

  Future<void> _fetchPatientName() async {
    var doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.patientId)
        .get();
    if (doc.exists) {
      setState(() {
        _patientName = doc.data()?['fullName'] ?? "Patient";
      });
    }
  }

  Future<void> _checkInitialUnread() async {
    var snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.patientId)
        .collection('history')
        .where('isReadCaregiver', isEqualTo: false)
        .get();

    if (snapshot.docs.isNotEmpty) {
      _playBell();
    }
  }

  void _setupInAppBellListener() {
    _bellSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.patientId)
        .collection('history')
        .where('isReadCaregiver', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          _playBell();
        }
      }
    });
  }

  // --- Firestore Helpers ---

  Future<void> _markAsRead(String docId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.patientId)
        .collection('history')
        .doc(docId)
        .update({'isReadCaregiver': true});
  }

  Future<void> _markAllRead() async {
    var collection = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.patientId)
        .collection('history')
        .where('isReadCaregiver', isEqualTo: false);

    var querySnapshots = await collection.get();
    WriteBatch batch = FirebaseFirestore.instance.batch();
    for (var doc in querySnapshots.docs) {
      batch.update(doc.reference, {'isReadCaregiver': true});
    }
    await batch.commit();
  }

  // --- Navigation Helpers ---

  void _goHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const CaregiverHomeScreen()),
    );
  }

  void _navigateToHistory() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) =>
            MedicationHistoryScreen(patientId: widget.patientId),
      ),
    );
  }

  void _navigateToMedication() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) =>
            PatientMedicationsScreen(patientId: widget.patientId),
      ),
    );
  }

  void _navigateToProfile() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) =>
            CaregiverProfileScreen(patientId: widget.patientId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
          // --- HEADER ---
          Container(
            padding: const EdgeInsets.only(top: 10, bottom: 15),
            decoration: const BoxDecoration(
              color: Color(0xFFEC4899),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: _goHome,
                    ),
                    Text(
                      'notification'.tr(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    if (!_isNotLinked)
                      TextButton(
                        onPressed: _markAllRead,
                        child: Text(
                          'mark_all_read'.tr(),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          Expanded(
            child: _isNotLinked
                ? _buildLinkedWarning()
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(widget.patientId)
                        .collection('history')
                        .where('isReadCaregiver', isEqualTo: false)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                            child: CircularProgressIndicator(
                                color: Color(0xFFEC4899)));
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return _buildEmptyState();
                      }

                      // Manual sort by timestamp
                      var docs = snapshot.data!.docs.toList();
                      docs.sort((a, b) {
                        var dataA = a.data() as Map<String, dynamic>;
                        var dataB = b.data() as Map<String, dynamic>;
                        DateTime tA = DateTime.fromMillisecondsSinceEpoch(
                            dataA['timestamp'] * 1000);
                        DateTime tB = DateTime.fromMillisecondsSinceEpoch(
                            dataB['timestamp'] * 1000);
                        return tB.compareTo(tA);
                      });

                      return ListView.builder(
                        padding: const EdgeInsets.all(24),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          var doc = docs[index];
                          var data = doc.data() as Map<String, dynamic>;
                          return GestureDetector(
                            onTap: () => _markAsRead(doc.id),
                            child: _buildNotificationCard(doc.id, data),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
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
        notchMargin: 8,
        elevation: 10,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildNavItem(Icons.home_outlined, 'home'.tr(), false, _goHome),
              _buildNavItem(
                  Icons.history, 'history'.tr(), false, _navigateToHistory),
              const SizedBox(width: 40),
              _buildNavItem(
                  Icons.notifications, 'notification'.tr(), true, () {}),
              _buildNavItem(Icons.person_outline, 'profile'.tr(), false,
                  _navigateToProfile),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLinkedWarning() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.link_off, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'please_link_patient_in_profile'.tr(),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 16),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _navigateToProfile,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEC4899),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('go_to_profile'.tr(),
                style: const TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('no_doses_scheduled'.tr(),
              style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(String docId, Map<String, dynamic> data) {
    IconData iconData;
    Color iconColor;
    Color iconBg;
    Color cardBorder = const Color(0xFFF3F4F6);
    Color cardBg = Colors.white;

    String status = data['status']?.toString().toLowerCase() ?? 'missed';
    bool isRead =
        data['isReadCaregiver'] is bool ? data['isReadCaregiver'] : false;
    String medicine = data['medicineName']?.toString() ?? "Medication";
    String slot = data['slot']?.toString() ?? "1";
    String time = data['time']?.toString() ?? "";

    // --- Smart Date Logic ---
    String displayDate = "";
    if (data['timestamp'] is Timestamp) {
      DateTime dateTime = (data['timestamp'] as Timestamp).toDate();
      final now = DateTime.now();

      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final checkDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

      if (checkDate.isAtSameMomentAs(today)) {
        displayDate = 'today'.tr();
      } else if (checkDate.isAtSameMomentAs(yesterday)) {
        displayDate = 'yesterday'.tr();
      } else {
        displayDate = DateFormat('dd/MM/yyyy').format(dateTime);
      }
    } else {
      displayDate = data['date']?.toString() ?? "";
    }

    String displayTitle;
    String displayMessage;

    if (status == 'taken') {
      displayTitle = 'taken'.tr();
      displayMessage = 'medication_taken_caregiver_message'.tr(namedArgs: {
        'medicine': medicine,
        'slot': slot,
        'time': time,
      });
      iconData = Icons.check_circle_outline;
      iconColor = Colors.green;
      iconBg = const Color(0xFFDCFCE7);
    } else {
      displayTitle = 'missed'.tr();
      displayMessage = 'medication_missed_caregiver_message'.tr(namedArgs: {
        'medicine': medicine,
        'slot': slot,
        'time': time,
      });
      iconData = Icons.error_outline;
      iconColor = Colors.red;
      iconBg = const Color(0xFFFEE2E2);
      if (!isRead) {
        cardBg = const Color(0xFFFFF7FA);
        cardBorder = const Color(0xFFFCE7F3);
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: isRead ? const Color(0xFFF3F4F6) : cardBorder),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: iconBg,
            child: Icon(iconData, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(displayTitle,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                        Text(_patientName,
                            style: const TextStyle(
                                color: Color(0xFFEC4899),
                                fontSize: 13,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                    if (!isRead) _unreadDot(),
                  ],
                ),
                const SizedBox(height: 4),
                Text(displayMessage,
                    style: const TextStyle(
                        color: Color(0xFF6B7280), fontSize: 13)),
                const SizedBox(height: 8),
                Text("$displayDate • $time",
                    style: const TextStyle(
                        color: Color(0xFF9CA3AF), fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _unreadDot() {
    return Container(
      width: 8,
      height: 8,
      decoration:
          const BoxDecoration(color: Color(0xFFEC4899), shape: BoxShape.circle),
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
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isActive ? const Color(0xFFEC4899) : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
