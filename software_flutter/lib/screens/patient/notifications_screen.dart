import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:easy_localization/easy_localization.dart';
import 'medication_history_screen.dart';
import 'medication_slots_screen.dart';
import 'profile_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? "";
  StreamSubscription? _bellSubscription;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _setupInAppBellListener();
    _checkInitialUnread();
  }

  @override
  void dispose() {
    _bellSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  // --- Alert Logic ---

  void _playBell() {
    debugPrint("🔔 Patient Bell Triggered");
    _audioPlayer.play(AssetSource('audio/bell.mp3'));
    HapticFeedback.heavyImpact();
  }

  Future<void> _checkInitialUnread() async {
    var snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('history')
        .where('isReadPatient', isEqualTo: false)
        .get();

    if (snapshot.docs.isNotEmpty) {
      _playBell();
    }
  }

  void _setupInAppBellListener() {
    _bellSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('history')
        .where('isReadPatient', isEqualTo: false)
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
        .doc(_uid)
        .collection('history')
        .doc(docId)
        .update({'isReadPatient': true});
  }

  Future<void> _markAllRead() async {
    var collection = FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('history')
        .where('isReadPatient', isEqualTo: false);

    var querySnapshots = await collection.get();
    WriteBatch batch = FirebaseFirestore.instance.batch();
    for (var doc in querySnapshots.docs) {
      batch.update(doc.reference, {'isReadPatient': true});
    }
    await batch.commit();
  }

  // --- Navigation Helpers ---

  void _goHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _navigateToHistory() {
    Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (context) => const MedicationHistoryScreen()));
  }

  void _navigateToMedication() {
    Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (context) => const MedicationSlotsScreen()));
  }

  void _navigateToProfile() {
    Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (context) => const ProfileScreen()));
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
                        onPressed: _goHome),
                    Text("notification".tr(),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    const Spacer(),
                    TextButton(
                        onPressed: _markAllRead,
                        child: Text("mark_all_read".tr(),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 14))),
                  ],
                ),
              ),
            ),
          ),

          // --- REAL-TIME NOTIFICATION LIST ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(_uid)
                  .collection('history')
                  .where('isReadPatient', isEqualTo: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFFEC4899)));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

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
              _buildNavItem(Icons.home_outlined, "home".tr(), false, _goHome),
              _buildNavItem(
                  Icons.history, "history".tr(), false, _navigateToHistory),
              const SizedBox(width: 40),
              _buildNavItem(
                  Icons.notifications, "notification".tr(), true, () {}),
              _buildNavItem(Icons.person_outline, "profile".tr(), false,
                  _navigateToProfile),
            ],
          ),
        ),
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
          Text("no_new_notifications".tr(),
              style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(String docId, Map<String, dynamic> data) {
    IconData iconData;
    Color iconColor;
    Color iconBg;
    Color cardBg = Colors.white;

    String status = data['status']?.toString().toLowerCase() ?? 'missed';
    bool isRead = data['isReadPatient'] is bool ? data['isReadPatient'] : false;
    String medicine = data['medicineName']?.toString() ?? "medicine".tr();
    String slot = data['slot']?.toString() ?? "1";
    String time = data['time']?.toString() ?? "";

    // --- SMART DATE LOGIC ---
    String displayDate = "";
    if (data['timestamp'] is Timestamp) {
      DateTime dateTime = (data['timestamp'] as Timestamp).toDate();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final checkDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

      if (checkDate.isAtSameMomentAs(today)) {
        displayDate = "today".tr();
      } else if (checkDate.isAtSameMomentAs(yesterday)) {
        displayDate = "yesterday".tr();
      } else {
        displayDate = DateFormat('dd/MM/yyyy').format(dateTime);
      }
    } else {
      displayDate = data['date']?.toString() ?? "";
    }

    String displayTitle;
    String displayMessage;

    if (status == 'taken') {
      displayTitle = "medication_taken".tr();
      displayMessage = "medication_taken_message".tr(namedArgs: {
        'medicine': medicine,
        'slot': slot,
        'time': time,
      });
      iconData = Icons.check_circle_outline;
      iconColor = const Color(0xFF10B981);
      iconBg = const Color(0xFFDCFCE7);
    } else {
      displayTitle = "missed_dose_alert".tr();
      displayMessage = "missed_dose_message".tr(namedArgs: {
        'medicine': medicine,
        'slot': slot,
        'time': time,
      });
      iconData = Icons.error_outline;
      iconColor = const Color(0xFFEF4444);
      iconBg = const Color(0xFFFEE2E2);
      if (!isRead) cardBg = const Color(0xFFFFF7FA);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 15,
              offset: const Offset(0, 8))
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(iconData, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(displayTitle,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: Color(0xFF1F2937))),
                    if (!isRead) _unreadDot(),
                  ],
                ),
                const SizedBox(height: 6),
                Text(displayMessage,
                    style: const TextStyle(
                        color: Color(0xFF6B7280), fontSize: 14, height: 1.4)),
                const SizedBox(height: 12),
                Text("$displayDate • $time",
                    style: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _unreadDot() {
    return Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
            color: Color(0xFFEC4899), shape: BoxShape.circle));
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
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: isActive ? const Color(0xFFEC4899) : Colors.grey)),
          ],
        ),
      ),
    );
  }
}
