class Product {
  const Product({required this.name, required this.barcode});
  final String name;
  final String barcode;
}

class ExpiryRecord {
  const ExpiryRecord({this.id, required this.name, required this.barcode, required this.expiryDate, required this.createdAt});
  final int? id;
  final String name;
  final String barcode;
  final String expiryDate; // ISO yyyy-MM-dd
  final String createdAt;

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'barcode': barcode,
    'expiry_date': expiryDate,
    'created_at': createdAt,
  };

  factory ExpiryRecord.fromMap(Map<String, Object?> map) => ExpiryRecord(
    id: map['id'] as int?,
    name: map['name'] as String,
    barcode: map['barcode'] as String,
    expiryDate: map['expiry_date'] as String,
    createdAt: map['created_at'] as String,
  );
}
