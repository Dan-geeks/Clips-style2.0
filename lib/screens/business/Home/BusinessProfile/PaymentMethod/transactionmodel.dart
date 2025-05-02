import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class WalletTransaction {
  final String id;
  final String name;
  final double amount;
  final String? imageUrl;
  final String type; // 'credit' or 'debit'
  final String? description;
  final Timestamp timestamp; // Use Firestore Timestamp

  WalletTransaction({
    required this.id,
    required this.name,
    required this.amount,
    this.imageUrl,
    required this.type,
    this.description,
    required this.timestamp,
  });

  // Getters for formatting
  String get formattedDate => DateFormat('dd/MM/yyyy').format(timestamp.toDate());
  String get formattedTime => DateFormat('h:mm a').format(timestamp.toDate());

  factory WalletTransaction.fromMap(Map<String, dynamic> map, String id) {
    return WalletTransaction(
      id: id,
      name: map['name'] ?? 'N/A',
      amount: (map['amount'] ?? 0.0).toDouble(),
      imageUrl: map['imageUrl'],
      type: map['type'] ?? 'unknown',
      description: map['description'],
      timestamp: (map['timestamp'] is Timestamp ? map['timestamp'] : Timestamp.now()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'amount': amount,
      'imageUrl': imageUrl,
      'type': type,
      'description': description,
      'timestamp': timestamp, // Store the actual timestamp
    };
  }
}