import 'package:intl/intl.dart';

final _maxSqliteInteger = BigInt.parse('9223372036854775807');

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
  final whole = BigInt.tryParse(wholePart);
  final minor = whole == null
      ? null
      : whole * BigInt.from(multiplier) + BigInt.from(fraction);
  if (minor == null || minor > _maxSqliteInteger) {
    throw const FormatException('Amount is too large.');
  }
  if (allowZero ? minor < BigInt.zero : minor <= BigInt.zero) {
    throw FormatException(
      allowZero ? 'Amount cannot be negative.' : 'Amount must be greater than zero.',
    );
  }
  return minor.toInt();
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
