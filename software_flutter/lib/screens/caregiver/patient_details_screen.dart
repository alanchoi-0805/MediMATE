import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'medication_history_screen.dart';

class PatientDetailsScreen extends StatelessWidget {
  final String patientId;

  const PatientDetailsScreen({super.key, required this.patientId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(patientId)
            .snapshots(),
        builder: (context, patientSnapshot) {
          if (patientSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFFEC4899)));
          }

          if (!patientSnapshot.hasData || !patientSnapshot.data!.exists) {
            return Center(child: Text("patient_data_not_found".tr()));
          }

          final pData =
              patientSnapshot.data!.data() as Map<String, dynamic>? ?? {};

          final String patientName = pData['fullName'] ?? 'Patient';
          final String patientAge = (pData['age'] ?? "--").toString();
          final String patientGender = pData['gender'] ?? 'Not set';
          final String patientHeight = "${pData['height'] ?? '--'} m";
          final String patientWeight = "${pData['weight'] ?? '--'} kg";
          final String phone = pData['phone'] ?? 'Not set';
          final String medicalNotes =
              pData['medicalNotes'] ?? 'No notes available';

          return Column(
            children: [
              // --- HEADER SECTION ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 40, bottom: 20),
                decoration: const BoxDecoration(
                  color: Color(0xFFEC4899),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back,
                                color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                          Text(
                            "patient_details".tr(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    const CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.person_outline,
                          size: 60, color: Color(0xFFEC4899)),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      patientName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "$patientAge ${"years_old".tr()}",
                      style: const TextStyle(
                          color: Color(0xFFFCE7F3), fontSize: 16),
                    ),
                  ],
                ),
              ),

              // --- CONTENT SECTION ---
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // 1. Last Medication Status Card
                      _buildLastMedicationCard(context, patientId),

                      const SizedBox(height: 20),

                      // 2. Personal Information Card
                      _buildDetailCard(
                        title: "personal_info".tr(),
                        child: Column(
                          children: [
                            _buildInfoRow(
                                Icons.phone_outlined, "phone".tr(), phone),
                            const Divider(height: 24, color: Color(0xFFF3F4F6)),
                            _buildInfoRow(Icons.calendar_today_outlined,
                                "age".tr(), "$patientAge ${"years".tr()}"),
                            const Divider(height: 24, color: Color(0xFFF3F4F6)),
                            _buildInfoRow(Icons.person_outline, "gender".tr(),
                                patientGender.toLowerCase().tr()),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 3. Health Information Card
                      _buildDetailCard(
                        title: "health_information".tr(),
                        child: Column(
                          children: [
                            _buildInfoRow(
                                Icons.straighten, "height".tr(), patientHeight),
                            const Divider(height: 24, color: Color(0xFFF3F4F6)),
                            _buildInfoRow(Icons.monitor_weight_outlined,
                                "weight".tr(), patientWeight),
                            const Divider(height: 24, color: Color(0xFFF3F4F6)),
                            _buildInfoRow(Icons.description_outlined,
                                "medical_notes".tr(), medicalNotes),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _getRelativeDate(String dateStr) {
    if (dateStr.isEmpty) return "";

    List<String> formatsToTry = [
      "MMMM dd, yyyy",
      "MMM dd, yyyy",
      "yyyy-MM-dd",
      "dd/MM/yyyy",
      "d/M/yyyy",
      "MM/dd/yyyy",
    ];

    DateTime? entryDate;

    for (String format in formatsToTry) {
      try {
        entryDate = DateFormat(format).parse(dateStr);
        break;
      } catch (_) {
        continue;
      }
    }

    if (entryDate == null) return dateStr;

    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    DateTime yesterday = today.subtract(const Duration(days: 1));
    DateTime entryDay =
        DateTime(entryDate.year, entryDate.month, entryDate.day);

    if (entryDay == today) return "today".tr();
    if (entryDay == yesterday) return "yesterday".tr();

    return dateStr;
  }

  Widget _buildLastMedicationCard(BuildContext context, String patientId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(patientId)
          .collection('history')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        String medicineName = "no_history".tr();
        String displaySubtitle = "no_doses_recorded_yet".tr();
        bool isMissed = false;

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          var lastDoc =
              snapshot.data!.docs.first.data() as Map<String, dynamic>;
          medicineName = lastDoc['medicineName'] ?? "medicine".tr();

          String status = (lastDoc['status'] ?? "").toString().toLowerCase();
          isMissed = status == 'missed';

          if (lastDoc['timestamp'] != null) {
            // --- FIX FOR ESP32 INT TIMESTAMP ---
            DateTime tsDate;
            dynamic rawTs = lastDoc['timestamp'];
            if (rawTs is Timestamp) {
              tsDate = rawTs.toDate();
            } else if (rawTs is int) {
              tsDate = DateTime.fromMillisecondsSinceEpoch(rawTs * 1000);
            } else {
              tsDate = DateTime.now();
            }

            String relativeDate =
                _getRelativeDate(DateFormat('MMMM dd, yyyy').format(tsDate));
            String time = lastDoc['time'] ?? DateFormat('HH:mm').format(tsDate);
            displaySubtitle = "$relativeDate, $time";
          } else {
            String rawDate = lastDoc['date'] ?? "";
            String relativeDate = _getRelativeDate(rawDate);
            String time = lastDoc['time'] ?? "";
            displaySubtitle =
                relativeDate.isNotEmpty ? "$relativeDate, $time" : time;
          }
        }

        return _buildDetailCard(
          title: "last_medication_status".tr(),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isMissed
                          ? const Color(0xFFFEE2E2)
                          : const Color(0xFFDCFCE7),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isMissed
                          ? Icons.highlight_off
                          : Icons.check_circle_outline,
                      color: isMissed ? Colors.red : Colors.green,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          medicineName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          displaySubtitle,
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            MedicationHistoryScreen(patientId: patientId),
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFFFF1F2),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.history,
                      color: Color(0xFFEC4899), size: 20),
                  label: Text(
                    "view_full_history".tr(),
                    style: TextStyle(
                        color: Color(0xFFEC4899), fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937)),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.grey.shade400, size: 22),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF374151)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
