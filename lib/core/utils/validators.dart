class Validators {
  const Validators._();

  static String? required(String? value, String field) {
    if (value == null || value.trim().isEmpty) return '$field is required.';
    return null;
  }

  static String? email(String? value) {
    final email = value?.trim() ?? '';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.length < 8) {
      return 'Use at least 8 characters.';
    }
    if (!RegExp(r'[A-Za-z]').hasMatch(value) ||
        !RegExp(r'[0-9]').hasMatch(value)) {
      return 'Include letters and numbers.';
    }
    return null;
  }
}
