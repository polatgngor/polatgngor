class StringUtils {
  static String maskName(String fullName) {
    if (fullName.isEmpty) return 'Sürücü'; // Fallback
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '';
    
    if (parts.length == 1) return parts.first;

    final lastName = parts.last;
    final firstNames = parts.take(parts.length - 1).join(' ');
    
    final maskedLast = lastName.isNotEmpty ? '${lastName[0]}.' : '';
    
    return '$firstNames $maskedLast';
  }
}
