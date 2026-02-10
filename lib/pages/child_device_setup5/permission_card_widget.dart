import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PermissionCardWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool isGranted;
  final VoidCallback onGrantPressed;
  final bool showButton;

  const PermissionCardWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.isGranted,
    required this.onGrantPressed,
    this.showButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: isGranted ? const Color(0xFFE8F5E9) : Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: isGranted ? const Color(0xFF58C16D) : const Color(0xFFE0E0E0),
          width: isGranted ? 2.0 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48.0,
                height: 48.0,
                decoration: BoxDecoration(
                  color: isGranted
                      ? const Color(0xFF58C16D)
                      : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Icon(
                  icon,
                  color: isGranted ? Colors.white : const Color(0xFF757575),
                  size: 24.0,
                ),
              ),
              const SizedBox(width: 16.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: GoogleFonts.inter(
                              fontSize: 16.0,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1A1A1A),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 4.0,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEBEE),
                            borderRadius: BorderRadius.circular(4.0),
                          ),
                          child: Text(
                            'Required',
                            style: GoogleFonts.inter(
                              fontSize: 11.0,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFFD32F2F),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12.0),
          Text(
            description,
            style: GoogleFonts.inter(
              fontSize: 14.0,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF757575),
              height: 1.5,
            ),
          ),
          if (isGranted) ...[
            const SizedBox(height: 12.0),
            Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Color(0xFF58C16D),
                  size: 16.0,
                ),
                const SizedBox(width: 8.0),
                Text(
                  'Permission Granted',
                  style: GoogleFonts.inter(
                    fontSize: 14.0,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF58C16D),
                  ),
                ),
              ],
            ),
          ] else if (showButton) ...[
            const SizedBox(height: 16.0),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onGrantPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Grant Permission',
                  style: GoogleFonts.inter(
                    fontSize: 14.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
