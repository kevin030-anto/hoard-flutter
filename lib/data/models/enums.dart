// Domain enums for FinFlow. Serialized by Enum.name; parsed with a safe
// fallback so a corrupt/old backup never crashes the app.

enum AccountType { cash, bank }

enum PaymentModeType { cash, digital }

enum CategoryKind { expense, income, both }

enum TxnType { income, expense, transfer }

enum TxnSource { manual, autopay, pending, sms }

enum PendingKind { toPay, toReceive, todo }

enum PendingStatus { pending, done }

enum RepeatType { none, daily, weekly, monthly, yearly }

enum FlowType { income, expense }

T enumFromName<T extends Enum>(List<T> values, String? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}
