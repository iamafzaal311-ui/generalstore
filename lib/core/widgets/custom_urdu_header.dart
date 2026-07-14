import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CustomUrduHeader extends StatelessWidget {
  const CustomUrduHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 800),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Left Side: Name and Phone
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'علی عباس',
                      style: GoogleFonts.notoNastaliqUrdu(
                        fontSize: 24,
                        color: Colors.blue.shade800,
                        height: 1.5,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.phone, size: 16, color: Colors.grey.shade700),
                        const SizedBox(width: 4),
                        Text(
                          '0307-4217267',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // Right Side: Store Name
                Text(
                  'حسنین ٹریڈرز',
                  style: GoogleFonts.notoNastaliqUrdu(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                    height: 1.5,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ],
            ),
          ),
          // Bottom Bar: Address
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.blue.shade800,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Text(
              'ایڈریس: غوثیہ مارکیٹ سکندر چوک پاک پتن',
              textAlign: TextAlign.center,
              style: GoogleFonts.notoNastaliqUrdu(
                fontSize: 18,
                color: Colors.white,
                height: 1.5,
              ),
              textDirection: TextDirection.rtl,
            ),
          ),
        ],
      ),
    );
  }
}
