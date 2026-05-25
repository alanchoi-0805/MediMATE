import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';

class ScheduleMedicationScreen extends StatefulWidget {
  final int slotNumber;
  final String? targetUserId;

  const ScheduleMedicationScreen({
    super.key,
    required this.slotNumber,
    this.targetUserId,
  });

  @override
  State<ScheduleMedicationScreen> createState() =>
      _ScheduleMedicationScreenState();
}

class TimeInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text;
    if (newValue.selection.baseOffset == 0) return newValue;
    var buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      var nonZeroIndex = i + 1;
      if (nonZeroIndex == 2 && nonZeroIndex != text.length) {
        buffer.write(':');
      }
    }
    var string = buffer.toString();
    return newValue.copyWith(
        text: string,
        selection: TextSelection.collapsed(offset: string.length));
  }
}

class _ScheduleMedicationScreenState extends State<ScheduleMedicationScreen> {
  String _selectedType = 'pills';
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get effectiveUserId =>
      widget.targetUserId ?? _auth.currentUser?.uid ?? "";

  final List<Map<String, dynamic>> _medicationTypes = [
    {'label': 'pills', 'iconPath': 'assets/icons/pills.svg'},
    {'label': 'drops', 'iconPath': 'assets/icons/drops.svg'},
    {'label': 'syrup', 'iconPath': 'assets/icons/syrup.svg'},
    {'label': 'injection', 'iconPath': 'assets/icons/injection.svg'},
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFEC4899),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      setState(() {
        _dateController.text = DateFormat('dd/MM/yyyy').format(pickedDate);
      });
    }
  }

  bool _isValid24hTime(String time) {
    if (time.length != 5) return false;
    final parts = time.split(':');
    if (parts.length != 2) return false;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return false;
    return hour >= 0 && hour < 24 && minute >= 0 && minute < 60;
  }

  Future<void> _saveMedicationData() async {
    if (_nameController.text.isEmpty || _timeController.text.isEmpty) {
      return;
    }

    if (!_isValid24hTime(_timeController.text)) {
      return;
    }

    try {
      WriteBatch batch = _firestore.batch();

      DocumentReference userDoc =
          _firestore.collection('users').doc(effectiveUserId);

      Map<String, dynamic> medicationData = {
        'slot': widget.slotNumber,
        'medicineName': _nameController.text,
        'medicationType': _selectedType,
        'date': _dateController.text,
        'time': _timeController.text,
        'status': 'waiting',
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      batch.update(userDoc, {
        'slot${widget.slotNumber}': medicationData,
        'medicineName': _nameController.text,
        'time': _timeController.text,
        'date': _dateController.text,
        'status': 'waiting',
      });

      DocumentReference deviceDoc =
          _firestore.collection('devices').doc('ESP32-001');

      batch.set(
          deviceDoc,
          {
            'ownerId': effectiveUserId,
            'slot${widget.slotNumber}_time': _timeController.text,
          },
          SetOptions(merge: true));

      await batch.commit();

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint("Save error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
          Container(
            padding:
                const EdgeInsets.only(top: 25, left: 8, right: 24, bottom: 10),
            decoration: const BoxDecoration(color: Color(0xFFEC4899)),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back,
                      color: Colors.white, size: 22),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 8),
                Text(
                  "schedule_medication".tr(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade100),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("setting_up".tr(),
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 14)),
                        Text(
                            "slot_label"
                                .tr(args: [widget.slotNumber.toString()]),
                            style: const TextStyle(
                                color: Color(0xFFEC4899),
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text("medication_type".tr(),
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 16)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: _medicationTypes
                        .map((type) => _buildTypeButton(type))
                        .toList(),
                  ),
                  const SizedBox(height: 24),
                  Text("medicine_name".tr(),
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 16)),
                  const SizedBox(height: 8),
                  _buildTextField(_nameController, "example_aspirin".tr()),
                  const SizedBox(height: 24),
                  Text("intake_date".tr(),
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 16)),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _selectDate,
                    child: IgnorePointer(
                      child: _buildTextField(
                          _dateController, "date_format".tr(),
                          icon: Icons.calendar_today_outlined),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text("intake_time".tr(),
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 16)),
                  const SizedBox(height: 8),
                  _buildTextField(
                    _timeController,
                    "time_format".tr(),
                    icon: Icons.access_time,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(5),
                      FilteringTextInputFormatter.digitsOnly,
                      TimeInputFormatter(),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFDBEAFE)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline,
                            color: Color(0xFF3B82F6), size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "medimate_alert_info".tr(),
                            style: const TextStyle(
                                color: Color(0xFF1E40AF),
                                fontSize: 14,
                                height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _saveMedicationData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEC4899),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      icon:
                          const Icon(Icons.save_outlined, color: Colors.white),
                      label: Text(
                        "save_reminder".tr(),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
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

  Widget _buildTypeButton(Map<String, dynamic> type) {
    bool isSelected = _selectedType == type['label'];
    return InkWell(
      onTap: () => setState(() => _selectedType = type['label']),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 75,
        height: 85,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFCE7F3) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFFEC4899) : Colors.grey.shade200,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              type['iconPath'],
              width: 28,
              height: 28,
              colorFilter: ColorFilter.mode(
                isSelected ? const Color(0xFFEC4899) : Colors.grey,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              type['label'].toString().tr(),
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? const Color(0xFFEC4899) : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint,
      {IconData? icon,
      TextInputType? keyboardType,
      List<TextInputFormatter>? inputFormatters}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
        prefixIcon:
            icon != null ? Icon(icon, color: Colors.grey, size: 20) : null,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEC4899), width: 2),
        ),
      ),
    );
  }
}
