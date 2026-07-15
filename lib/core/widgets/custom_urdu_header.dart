import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/global_providers.dart';
import '../utils/text_helper.dart';

class CustomUrduHeader extends ConsumerWidget {
  const CustomUrduHeader({super.key});

  TextStyle _getStyle(String text, {double? fontSize, FontWeight? fontWeight, Color? color, double? height}) {
    final isUrdu = TextHelper.isUrdu(text);
    return isUrdu
        ? GoogleFonts.notoNastaliqUrdu(
            fontSize: fontSize,
            fontWeight: fontWeight,
            color: color,
            height: height ?? 1.5,
          )
        : GoogleFonts.poppins(
            fontSize: fontSize != null ? fontSize * 0.75 : null, // Poppins is naturally larger than Nastaliq
            fontWeight: fontWeight,
            color: color,
            height: height ?? 1.2,
          );
  }

  TextDirection _getDirection(String text) {
    return TextHelper.isUrdu(text) ? TextDirection.rtl : TextDirection.ltr;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(storeProfileProvider);

    final storeName = (profile?.storeName ?? '').isNotEmpty ? profile!.storeName : 'حسنین ٹریڈرز';
    final tagline = (profile?.tagline ?? '').isNotEmpty ? profile!.tagline : 'علی عباس';
    final phone = (profile?.phone ?? '').isNotEmpty ? profile!.phone : '0307-4217267';
    final address = (profile?.address ?? '').isNotEmpty ? profile!.address : 'ایڈریس: غوثیہ مارکیٹ سکندر چوک پاک پتن';

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 800),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
                      tagline,
                      style: _getStyle(tagline, fontSize: 24, color: Colors.blue.shade800, fontWeight: FontWeight.bold),
                      textDirection: _getDirection(tagline),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.phone, size: 16, color: Colors.grey.shade700),
                        const SizedBox(width: 4),
                        Text(
                          phone,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
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
                Expanded(
                  child: Text(
                    storeName,
                    textAlign: TextAlign.right,
                    style: _getStyle(storeName, fontSize: 48, color: Colors.red.shade700, fontWeight: FontWeight.bold),
                    textDirection: _getDirection(storeName),
                  ),
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
              address,
              textAlign: TextAlign.center,
              style: _getStyle(address, fontSize: 18, color: Colors.white, fontWeight: FontWeight.w500),
              textDirection: _getDirection(address),
            ),
          ),
        ],
      ),
    );
  }
}
