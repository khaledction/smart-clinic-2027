import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../../features/patients/patient_detail_screen.dart';

/// Use in display contexts. Patient selectors remain selectors, not navigation.
class PatientLink extends StatelessWidget {
  const PatientLink({
    super.key,
    required this.patientId,
    required this.name,
    this.style,
  });
  final int patientId;
  final String name;
  final TextStyle? style;
  @override
  Widget build(BuildContext context) => InkWell(
    mouseCursor: SystemMouseCursors.click,
    borderRadius: BorderRadius.circular(6),
    hoverColor: AppColors.hoverTint,
    highlightColor: AppColors.hoverTint,
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PatientDetailScreen(patientId: patientId, name: name),
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
      child: Text(
        name,
        style: (style ?? const TextStyle()).copyWith(
          decoration: TextDecoration.underline,
        ),
      ),
    ),
  );
}
