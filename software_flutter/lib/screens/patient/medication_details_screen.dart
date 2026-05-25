import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';

class MedicationDetailsScreen extends StatefulWidget {
  final int selectedSlot;
  final String? targetUserId;

  const MedicationDetailsScreen({
    super.key,
    required this.selectedSlot,
    this.targetUserId,
  });

  @override
  State<MedicationDetailsScreen> createState() =>
      _MedicationDetailsScreenState();
}

class _MedicationDetailsScreenState extends State<MedicationDetailsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get effectiveUserId =>
      widget.targetUserId ?? _auth.currentUser?.uid ?? "";

  String _getIconPath(String? type) {
    switch (type?.toLowerCase()) {
      case 'pills':
        return 'assets/icons/pills.svg';
      case 'drops':
        return 'assets/icons/drops.svg';
      case 'syrup':
        return 'assets/icons/syrup.svg';
      case 'injection':
        return 'assets/icons/injection.svg';
      default:
        return 'assets/icons/pills.svg';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('users').doc(effectiveUserId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFFEC4899)));
          }

          Map<String, dynamic>? medication;
          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;

            String slotKey = 'slot${widget.selectedSlot}';
            if (data.containsKey(slotKey) && data[slotKey] != null) {
              medication = Map<String, dynamic>.from(data[slotKey]);
              medication['slot'] = widget.selectedSlot;
            }
          }

          final bool hasData = medication != null &&
              (medication['medicineName'] != null ||
                  medication['name'] != null);

          return Column(
            children: [
              // --- HEADER ---
              Container(
                padding: const EdgeInsets.only(
                    top: 25, left: 8, right: 24, bottom: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFFEC4899),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: Colors.white, size: 22),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "medication_details".tr(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // --- MAIN CONTENT ---
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: hasData
                      ? _buildDetailsView(medication)
                      : _buildEmptyView(context),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDetailsView(Map<String, dynamic> med) {
    final String type = med['medicationType'] ?? med['type'] ?? 'Pills';
    final String name = med['medicineName'] ?? med['name'] ?? 'Unknown';
    final String date = med['date'] ?? med['intakeDate'] ?? '--/--/----';
    final String time = med['time'] ?? med['intakeTime'] ?? '--:--';
    final String slotDisplay =
        med['slot']?.toString() ?? widget.selectedSlot.toString();

    final String iconPath = _getIconPath(type);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
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
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFCE7F3),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: SvgPicture.asset(
                        iconPath,
                        width: 28,
                        height: 28,
                        colorFilter: const ColorFilter.mode(
                          Color(0xFFEC4899),
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("slot_number".tr(),
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 14)),
                      Text(
                        "slot_label".tr(args: [slotDisplay]),
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  )
                ],
              ),
              const SizedBox(height: 24),
              _buildDetailItem(
                iconPath,
                "medication_type".tr(),
                type.toLowerCase().tr(),
                isSvg: true,
              ),
              _buildDetailItem(
                '',
                "medicine_name".tr(),
                name,
                useIcon: Icons.medication_outlined,
              ),
              _buildDetailItem(
                '',
                "intake_date".tr(),
                date,
                useIcon: Icons.calendar_today_outlined,
              ),
              _buildDetailItem(
                '',
                "intake_time".tr(),
                time,
                useIcon: Icons.access_time,
                isLast: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // --- ALERT INFO BOX ---
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFDBEAFE)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline,
                  color: Color(0xFF3B82F6), size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "medimate_alert_info".tr(),
                  style: const TextStyle(
                      color: Color(0xFF1E40AF),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyView(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 80),
        Container(
          width: 96,
          height: 96,
          decoration: const BoxDecoration(
              color: Color(0xFFF3F4F6), shape: BoxShape.circle),
          child: const Icon(Icons.medical_services_outlined,
              color: Colors.grey, size: 40),
        ),
        const SizedBox(height: 24),
        Text("no_records_found".tr(),
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937))),
        const SizedBox(height: 8),
        Text(
          "empty_slot_message".tr(),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildDetailItem(String assetPath, String label, String value,
      {bool isLast = false, bool isSvg = false, IconData? useIcon}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          isSvg
              ? SvgPicture.asset(
                  assetPath,
                  width: 20,
                  height: 20,
                  colorFilter:
                      const ColorFilter.mode(Colors.grey, BlendMode.srcIn),
                )
              : Icon(useIcon ?? Icons.info_outline,
                  color: Colors.grey, size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 15)),
            ],
          ),
        ],
      ),
    );
  }
}
