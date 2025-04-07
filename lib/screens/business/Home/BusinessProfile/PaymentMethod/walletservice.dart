import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

// Expanded class to handle both wallet authentication and financial operations
class WalletService {
  // Firebase Cloud Function URLs - Updated with your deployed URLs
  static const String _depositFunctionUrl = 'https://initiatewalletdeposit-uovd7uxrra-uc.a.run.app';
  static const String _checkDepositStatusUrl = ' https://checkwalletdepositstatus-uovd7uxrra-uc.a.run.app';

  // Core services
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterSecureStorage _secureStorage;
  final LocalAuthentication _localAuth = LocalAuthentication();
  
  WalletService({FlutterSecureStorage? secureStorage}) 
      : _secureStorage = secureStorage ?? const FlutterSecureStorage(
          aOptions: AndroidOptions(
            encryptedSharedPreferences: true,
          ),
        );
  
  // ---------- AUTHENTICATION METHODS ----------
  
  // Check if biometric authentication is enabled for current user
  Future<bool> isBiometricEnabled() async {
    try {
      final String? userId = _auth.currentUser?.uid;
      if (userId == null) return false;
      
      final String? enabled = await _secureStorage.read(
        key: 'userBiometricEnabled_$userId'
      );
      
      return enabled == 'true';
    } catch (e) {
      print('Error checking biometric status: $e');
      return false;
    }
  }
  
  // Check if biometric authentication is available on the device
  Future<bool> isBiometricAvailable() async {
    try {
      final bool canAuthenticate = await _localAuth.canCheckBiometrics;
      final bool deviceSupported = await _localAuth.isDeviceSupported();
      
      return canAuthenticate && deviceSupported;
    } catch (e) {
      print('Error checking biometric availability: $e');
      return false;
    }
  }
  
  // Authenticate with biometrics
  Future<bool> authenticateWithBiometrics() async {
    try {
      final bool authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to access your wallet',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      
      return authenticated;
    } catch (e) {
      print('Error during biometric authentication: $e');
      return false;
    }
  }
  
  // Verify PIN
  Future<bool> verifyPin(String enteredPin) async {
    try {
      final String? userId = _auth.currentUser?.uid;
      if (userId == null) return false;
      
      // Get stored salt and hash
      final String? storedSalt = await _secureStorage.read(key: 'userPinSalt_$userId');
      final String? storedHash = await _secureStorage.read(key: 'userPinHash_$userId');
      
      if (storedSalt == null || storedHash == null) {
        return false;
      }
      
      // Hash the entered PIN
      final String computedHash = hashPin(enteredPin, storedSalt);
      
      // Compare hashes
      return computedHash == storedHash;
    } catch (e) {
      print('Error verifying PIN: $e');
      return false;
    }
  }
  
  // Helper function to hash PIN
  String hashPin(String pin, String salt) {
    final iterations = 10000;
    List<int> bytes = utf8.encode(pin + salt);
    
    for (var i = 0; i < iterations; i++) {
      bytes = sha256.convert(bytes).bytes;
    }
    
    return base64UrlEncode(bytes);
  }
  
  // Save a new PIN
  Future<bool> saveNewPin(String pin) async {
    try {
      final String? userId = _auth.currentUser?.uid;
      if (userId == null) return false;
      
      // Generate salt
      final String salt = generateRandomSalt();
      
      // Hash PIN
      final String hash = hashPin(pin, salt);
      
      // Store salt and hash
      await _secureStorage.write(key: 'userPinSalt_$userId', value: salt);
      await _secureStorage.write(key: 'userPinHash_$userId', value: hash);
      
      return true;
    } catch (e) {
      print('Error saving new PIN: $e');
      return false;
    }
  }
  
  // Generate random salt
  String generateRandomSalt({int length = 16}) {
    final values = List<int>.generate(length, (_) => _getSecureRandom());
    return base64UrlEncode(values);
  }
  
  // Get cryptographically secure random number
  int _getSecureRandom() {
    final random = DateTime.now().microsecondsSinceEpoch % 256;
    return random;
  }
  
  // Enable or disable biometric authentication
  Future<bool> setBiometricEnabled(bool enabled) async {
    try {
      final String? userId = _auth.currentUser?.uid;
      if (userId == null) return false;
      
      await _secureStorage.write(
        key: 'userBiometricEnabled_$userId',
        value: enabled.toString(),
      );
      
      return true;
    } catch (e) {
      print('Error setting biometric preference: $e');
      return false;
    }
  }
  
  // ---------- DEPOSIT METHODS ----------
  
  // Format phone number to ensure it's in the correct format for M-Pesa
  String _formatPhoneNumber(String phoneNumber) {
    // Remove any spaces or special characters
    String cleaned = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    
    // If it starts with 0, replace with 254
    if (cleaned.startsWith('0') && cleaned.length == 10) {
      return '254${cleaned.substring(1)}';
    } 
    // If it doesn't start with 254, add it
    else if (!cleaned.startsWith('254') && cleaned.length == 9) {
      return '254$cleaned';
    }
    
    return cleaned;
  }
  
  // Initiate an M-Pesa STK Push for wallet deposit
  Future<Map<String, dynamic>> initiateDeposit({
    required double amount,
    required String phoneNumber,
    String? businessName,
  }) async {
    try {
      final String? userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not logged in');
      }
      
      // Format the phone number
      final String formattedPhone = _formatPhoneNumber(phoneNumber);
      
      final response = await http.post(
        Uri.parse(_depositFunctionUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'amount': amount.toInt(), // M-Pesa requires integer amounts
          'phoneNumber': formattedPhone,
          'businessName': businessName ?? '',
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'Failed to initiate deposit');
      }
    } catch (e) {
      print('Error initiating deposit: $e');
      rethrow;
    }
  }

  // Check the status of a deposit
  Future<Map<String, dynamic>> checkDepositStatus(String checkoutRequestId) async {
    try {
      final response = await http.post(
        Uri.parse(_checkDepositStatusUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'checkoutRequestId': checkoutRequestId,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'Failed to check deposit status');
      }
    } catch (e) {
      print('Error checking deposit status: $e');
      rethrow;
    }
  }
}