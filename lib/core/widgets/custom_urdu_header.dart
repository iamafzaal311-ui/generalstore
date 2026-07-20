import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/global_providers.dart';
import '../utils/text_helper.dart';

class CustomUrduHeader extends ConsumerWidget {
  const CustomUrduHeader({super.key});

  TextStyle _getStyle(
    String text, {
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
  }) {
    final isUrdu = TextHelper.isUrdu(text);
    return isUrdu
        ? GoogleFonts.notoNastaliqUrdu(
            fontSize: fontSize,
            fontWeight: fontWeight,
            color: color,
            height: height ?? 1.5,
          )
        : GoogleFonts.poppins(
            fontSize: fontSize != null
                ? fontSize * 0.75
                : null, // Poppins is naturally larger than Nastaliq
            fontWeight: fontWeight,
            color: color,
            height: height ?? 1.2,
          );
  }

  TextDirection _getDirection(String text) {
    return TextHelper.isUrdu(text) ? TextDirection.rtl : TextDirection.ltr;
  }

  Color? _hexToColor(String? hexString) {
    if (hexString == null || hexString.isEmpty) return null;
    final hex = hexString.replaceFirst('#', '');
    if (hex.length == 6) {
      return Color(int.parse('FF$hex', radix: 16));
    } else if (hex.length == 8) {
      return Color(int.parse(hex, radix: 16));
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(storeProfileProvider);
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    final mainColor = _hexToColor(profile?.headerColor) ?? Colors.blue.shade800;
    final titleColor = _hexToColor(profile?.headerTextColor) ?? Colors.red.shade700;

    final storeName = (profile?.storeName ?? '').isNotEmpty
        ? profile!.storeName
        : '';
    final tagline = (profile?.tagline ?? '').isNotEmpty
        ? profile!.tagline
        : '';
    final phone = (profile?.phone ?? '').isNotEmpty
        ? profile!.phone
        : '';
    final address = (profile?.address ?? '').isNotEmpty
        ? profile!.address
        : '';

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
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 16,
              children: [
                // Left Side: Name and Phone
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (tagline.isNotEmpty)
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'Proprietor: ',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: mainColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextSpan(
                              text: tagline,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: mainColor,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (tagline.isNotEmpty && phone.isNotEmpty)
                      const SizedBox(height: 2),
                    if (phone.isNotEmpty)
                      SizedBox(
                        width: 250,
                        child: Text(
                          'Ph: ${phone.replaceAll(',', ' -')}',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.grey.shade800,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ),
                  ],
                ),
                // Right Side: Store Name
                SizedBox(
                  width: isMobile ? double.infinity : null,
                  child: Text(
                    storeName,
                    textAlign: isMobile ? TextAlign.center : TextAlign.right,
                    style: _getStyle(
                      storeName,
                      fontSize: isMobile ? 32 : 48,
                      color: titleColor,
                      fontWeight: FontWeight.bold,
                    ),
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
              color: mainColor,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Text(
              address,
              textAlign: TextAlign.center,
              style: _getStyle(
                address,
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
              textDirection: _getDirection(address),
            ),
          ),
        ],
      ),
    );
  }
}
