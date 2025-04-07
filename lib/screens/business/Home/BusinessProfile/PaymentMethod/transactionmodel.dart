class WalletTransaction {
  final String id;
  final String name;
  final String date;
  final String time;
  final double amount;
  final String? imageUrl;
  final String type; // 'credit' or 'debit'
  final String? description;
  
  WalletTransaction({
    required this.id,
    required this.name,
    required this.date,
    required this.time,
    required this.amount,
    this.imageUrl,
    required this.type,
    this.description,
  });
  
  factory WalletTransaction.fromMap(Map<String, dynamic> map, String id) {
    return WalletTransaction(
      id: id,
      name: map['name'] ?? '',
      date: map['date'] ?? '',
      time: map['time'] ?? '',
      amount: (map['amount'] ?? 0.0).toDouble(),
      imageUrl: map['imageUrl'],
      type: map['type'] ?? 'credit',
      description: map['description'],
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'date': date,
      'time': time,
      'amount': amount,
      'imageUrl': imageUrl,
      'type': type,
      'description': description,
    };
  }
}