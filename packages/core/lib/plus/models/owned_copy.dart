enum CopyFormat {
  physical('physical'),
  digital('digital');

  const CopyFormat(this.value);

  final String value;

  static CopyFormat fromString(String? value) =>
      value == digital.value ? digital : physical;
}

enum CopyCondition {
  sealed('sealed'),
  mint('mint'),
  good('good'),
  fair('fair'),
  poor('poor');

  const CopyCondition(this.value);

  final String value;

  static CopyCondition? tryFromString(String? value) {
    for (final CopyCondition c in CopyCondition.values) {
      if (c.value == value) return c;
    }
    return null;
  }
}

/// One copy the user owns: a boxed edition, a digital purchase, a signed
/// first print. An item can have several, each with its own loan.
class OwnedCopy {
  const OwnedCopy({
    required this.id,
    required this.itemId,
    required this.format,
    required this.createdAt,
    required this.updatedAt,
    this.edition,
    this.condition,
    this.pricePaid,
    this.currency,
    this.purchasedAt,
    this.store,
    this.notes,
    this.loanedTo,
    this.loanedAt,
    this.loanDueAt,
  });

  factory OwnedCopy.fromDb(Map<String, dynamic> row) {
    return OwnedCopy(
      id: row['id'] as int,
      itemId: row['item_id'] as int,
      format: CopyFormat.fromString(row['format'] as String?),
      edition: row['edition'] as String?,
      condition: CopyCondition.tryFromString(row['condition'] as String?),
      pricePaid: (row['price_paid'] as num?)?.toDouble(),
      currency: row['currency'] as String?,
      purchasedAt: _date(row['purchased_at']),
      store: row['store'] as String?,
      notes: row['notes'] as String?,
      loanedTo: row['loaned_to'] as String?,
      loanedAt: _date(row['loaned_at']),
      loanDueAt: _date(row['loan_due_at']),
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
    );
  }

  static DateTime? _date(Object? ms) =>
      ms is int ? DateTime.fromMillisecondsSinceEpoch(ms) : null;

  final int id;
  final int itemId;
  final CopyFormat format;
  final String? edition;
  final CopyCondition? condition;
  final double? pricePaid;

  /// ISO 4217 code as typed ("EUR"); totals are kept per currency.
  final String? currency;
  final DateTime? purchasedAt;
  final String? store;
  final String? notes;
  final String? loanedTo;
  final DateTime? loanedAt;
  final DateTime? loanDueAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isLoaned => loanedTo?.trim().isNotEmpty ?? false;

  bool isOverdue(DateTime now) {
    final DateTime? due = loanDueAt;
    return isLoaned && due != null && now.isAfter(due);
  }

  Map<String, dynamic> toDb() {
    return <String, dynamic>{
      if (id != 0) 'id': id,
      'item_id': itemId,
      'format': format.value,
      'edition': edition,
      'condition': condition?.value,
      'price_paid': pricePaid,
      'currency': currency?.trim().toUpperCase(),
      'purchased_at': purchasedAt?.millisecondsSinceEpoch,
      'store': store,
      'notes': notes,
      'loaned_to': loanedTo,
      'loaned_at': loanedAt?.millisecondsSinceEpoch,
      'loan_due_at': loanDueAt?.millisecondsSinceEpoch,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  OwnedCopy copyWith({
    int? id,
    CopyFormat? format,
    String? edition,
    bool clearEdition = false,
    CopyCondition? condition,
    bool clearCondition = false,
    double? pricePaid,
    bool clearPrice = false,
    String? currency,
    bool clearCurrency = false,
    DateTime? purchasedAt,
    bool clearPurchasedAt = false,
    String? store,
    bool clearStore = false,
    String? notes,
    bool clearNotes = false,
    String? loanedTo,
    DateTime? loanedAt,
    DateTime? loanDueAt,
    bool clearLoan = false,
    DateTime? updatedAt,
  }) {
    return OwnedCopy(
      id: id ?? this.id,
      itemId: itemId,
      format: format ?? this.format,
      edition: clearEdition ? null : (edition ?? this.edition),
      condition: clearCondition ? null : (condition ?? this.condition),
      pricePaid: clearPrice ? null : (pricePaid ?? this.pricePaid),
      currency: clearCurrency ? null : (currency ?? this.currency),
      purchasedAt: clearPurchasedAt ? null : (purchasedAt ?? this.purchasedAt),
      store: clearStore ? null : (store ?? this.store),
      notes: clearNotes ? null : (notes ?? this.notes),
      loanedTo: clearLoan ? null : (loanedTo ?? this.loanedTo),
      loanedAt: clearLoan ? null : (loanedAt ?? this.loanedAt),
      loanDueAt: clearLoan ? null : (loanDueAt ?? this.loanDueAt),
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
