import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';

class LinkPatientScreen extends StatefulWidget {
  const LinkPatientScreen({super.key});

  @override
  State<LinkPatientScreen> createState() => _LinkPatientScreenState();
}

class _LinkPatientScreenState extends State<LinkPatientScreen> {
  final TextEditingController _patientIdController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLinking = false;

  @override
  void dispose() {
    _patientIdController.dispose();
    super.dispose();
  }

  // --- Logic: Link Caregiver and Patient ---
  Future<void> _handleLinkPatient() async {
    String patientIdInput = _patientIdController.text.trim();
    User? currentUser = _auth.currentUser;

    if (patientIdInput.isEmpty || currentUser == null) {
      return;
    }

    setState(() => _isLinking = true);
    FocusScope.of(context).unfocus();

    try {
      // Find the patient with the matching patientId
      QuerySnapshot patientQuery = await _firestore
          .collection('users')
          .where('patientId', isEqualTo: patientIdInput)
          .where('role', isEqualTo: 'Patient')
          .limit(1)
          .get();

      if (patientQuery.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("patient_id_not_found".tr())),
          );
        }
        setState(() => _isLinking = false);
        return;
      }

      DocumentReference patientDoc = patientQuery.docs.first.reference;
      String patientUid = patientQuery.docs.first.id;

      // Perform Atomic Update (Transaction) to link both accounts
      await _firestore.runTransaction((transaction) async {
        // Update Patient's document with Caregiver's UID
        transaction.update(patientDoc, {
          'linkedCaregiverId': currentUser.uid,
        });

        // Update Caregiver's document with the Patient's UID
        transaction
            .update(_firestore.collection('users').doc(currentUser.uid), {
          'linkedPatientId': patientUid,
        });
      });

      if (mounted) {
        Navigator.pop(context); // Return to Profile Screen
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("${'error'.tr()}: ${e.toString()}"),
            backgroundColor: const Color(0xFF323232),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLinking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
          // --- HEADER ---
          Container(
            padding: const EdgeInsets.only(top: 40, bottom: 10, left: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFEC4899),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                Text(
                  "link_patient".tr(),
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
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  const CircleAvatar(
                    radius: 60,
                    backgroundColor: Color(0xFFFCE7F3),
                    child: Icon(
                      Icons.person_add_alt_1,
                      size: 64,
                      color: Color(0xFFEC4899),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "link_a_patient".tr(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      "enter_patient_id_description".tr(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // --- PATIENT ID INPUT CARD ---
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade100),
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
                        const Row(
                          children: [
                            Icon(Icons.person_add_alt_1,
                                color: Color(0xFFEC4899), size: 20),
                            SizedBox(width: 10),
                          ],
                        ),
                        SizedBox(
                          width: 100,
                          child: Text(
                            "patient_id".tr(),
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 15),
                        TextField(
                          controller: _patientIdController,
                          enabled: !_isLinking,
                          decoration: InputDecoration(
                            hintText: "enter_patient_id_hint".tr(),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 15, vertical: 15),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                  color: Color(0xFFEC4899), width: 2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "ask_patient_for_id".tr(),
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // --- LINK PATIENT BUTTON ---
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isLinking ? null : _handleLinkPatient,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEC4899),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 4,
                      ),
                      child: _isLinking
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              "link_patient".tr(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
