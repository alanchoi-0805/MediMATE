import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
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
                  "about_us_title".tr(),
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
                  // Logo and Version Section
                  Column(
                    children: [
                      Image.asset(
                        'assets/images/logo.png',
                        height: 70,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.medication_liquid_rounded,
                            size: 80,
                            color: Color(0xFFEC4899),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "medimate".tr(),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      Text(
                        "tagline".tr(),
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "version".tr(),
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // About Description Card
                  _buildSectionCard(
                    title: "about_medimate".tr(),
                    child: Text(
                      "about_description".tr(),
                      style: TextStyle(
                        color: Color(0xFF4B5563),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Features Card
                  _buildSectionCard(
                    title: "key_features".tr(),
                    child: Column(
                      children: [
                        _buildFeatureRow(Icons.smartphone, "smart_pillbox".tr(),
                            "smart_pillbox_desc".tr()),
                        _buildFeatureRow(
                            Icons.favorite,
                            "real_time_reminders".tr(),
                            "real_time_reminders_desc".tr()),
                        _buildFeatureRow(
                            Icons.people,
                            "caregiver_connection".tr(),
                            "caregiver_connection_desc".tr()),
                        _buildFeatureRow(Icons.shield, "secure_reliable".tr(),
                            "secure_reliable_desc".tr()),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Contact Card
                  _buildSectionCard(
                    title: "contact_us".tr(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildContactText("email".tr(), "support@medimate.com"),
                        const SizedBox(height: 8),
                        _buildContactText("website".tr(), "www.medimate.com"),
                        const SizedBox(height: 8),
                        _buildContactText("support_hours".tr(), "24/7"),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Copyright Section
                  Text(
                    "copyright".tr(),
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  Text(
                    "developed_with_love".tr(),
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- UI Helpers ---

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
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
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 15),
          child,
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFCE7F3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFFEC4899), size: 20),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactText(String label, String value) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(color: Color(0xFF4B5563), fontSize: 14),
        children: [
          TextSpan(
              text: "$label: ", style: const TextStyle(color: Colors.grey)),
          TextSpan(text: value),
        ],
      ),
    );
  }
}
