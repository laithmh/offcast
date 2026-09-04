import 'package:flutter/material.dart';

/// Amber eye-line marker guide positioned near the camera lens for optimal presenter eye contact.
class PrompterEyeLineMarker extends StatelessWidget {
  const PrompterEyeLineMarker({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFFB300).withValues(alpha: 0.12),
          border: Border(
            top: BorderSide(
              color: const Color(0xFFFFB300).withValues(alpha: 0.6),
              width: 1.5,
            ),
            bottom: BorderSide(
              color: const Color(0xFFFFB300).withValues(alpha: 0.6),
              width: 1.5,
            ),
          ),
        ),
        child: const Row(
          children: [
            Icon(Icons.arrow_right_rounded, color: Color(0xFFFFB300), size: 22),
            SizedBox(width: 4),
            Text(
              'EYE LINE — KEEP GAZE HERE FOR LENS CONTACT',
              style: TextStyle(
                color: Color(0xFFFFB300),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            Spacer(),
            Icon(Icons.arrow_left_rounded, color: Color(0xFFFFB300), size: 22),
          ],
        ),
      ),
    );
  }
}
