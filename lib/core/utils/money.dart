import 'package:intl/intl.dart';

int currencyFractionDigits(String currencyCode) {
  return switch (currencyCode.toUpperCase()) {
    'UGX' || 'KES' || 'TZS' || 'JPY' => 0,
    _ => 2,
  };
}

int parseMinorUnits(
  String value,
  String currencyCode, {
  bool allowZero = false,
}) {
  final normalized = value.replaceAll(',', '').trim();
  final scale = currencyFractionDigits(currencyCode);
  final parts = normalized.split('.');
  if (parts.length > 2 ||
      parts.any((part) => part.isNotEmpty && int.tryParse(part) == null)) {
    throw const FormatException('Enter a valid amount.');
  }
  final wholePart = parts.first.isEmpty ? '0' : parts.first;
  final fractionPart = parts.length == 1 ? '' : parts[1];
  if (fractionPart.length > scale &&
      fractionPart.substring(scale).split('').any((digit) => digit != '0')) {
    throw FormatException(
      '$currencyCode supports at most $scale decimal places.',
    );
  }
  final fraction = scale == 0
      ? 0
      : int.parse(
          (fractionPart.length > scale
                  ? fractionPart.substring(0, scale)
                  : fractionPart)
              .padRight(scale, '0'),
        );
  final multiplier = scale == 0 ? 1 : 100;
  final whole = int.tryParse(wholePart);
  const maximumExactInteger = 9007199254740991;
  if (whole == null || whole > (maximumExactInteger - fraction) ~/ multiplier) {
    throw const FormatException('Amount is too large.');
  }
  final minor = whole * multiplier + fraction;
  if (allowZero ? minor < 0 : minor <= 0) {
    throw FormatException(
      allowZero ? 'Amount cannot be negative.' : 'Amount must be greater than zero.',
    );
  }
  return minor;
}

String formatMinorUnits(int amountMinor, String currencyCode) {
  final scale = currencyFractionDigits(currencyCode);
  final multiplier = scale == 0 ? 1 : 100;
  final absolute = amountMinor.abs();
  final whole = absolute ~/ multiplier;
  final fraction = absolute % multiplier;
  final formattedWhole = NumberFormat.decimalPattern().format(whole);
  final amount = scale == 0
      ? formattedWhole
      : '$formattedWhole.${fraction.toString().padLeft(scale, '0')}';
  return '${amountMinor < 0 ? '-' : ''}$currencyCode $amount';
}
