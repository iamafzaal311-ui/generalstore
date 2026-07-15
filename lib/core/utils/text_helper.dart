class TextHelper {
  /// Detects if the given text contains any Urdu characters.
  static bool isUrdu(String text) {
    // Range for Arabic/Urdu Unicode characters
    final RegExp urduRegex = RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]');
    return urduRegex.hasMatch(text);
  }
}
