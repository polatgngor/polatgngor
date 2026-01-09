class StringUtils {
  static String maskName(String fullName) {
    if (fullName.isEmpty) return 'Kullanıcı'; // Fallback
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '';
    
    // If only one name is provided, show it fully (e.g. "Murat")
    if (parts.length == 1) return parts.first;

    // Show all names except the last one fully
    final lastName = parts.last;
    final firstNames = parts.take(parts.length - 1).join(' ');
    
    // Mask last name to "G."
    final maskedLast = lastName.isNotEmpty ? '${lastName[0]}.' : '';
    
    return '$firstNames $maskedLast';
  }
}
