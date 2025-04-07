import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Import the business home page
import 'walletcompletion.dart';

// --- Constants ---
const Color kAppBackgroundColor = Colors.white;
const Color kPrimaryButtonColor = Color(0xFF23461a);
const Color kPrimaryTextColor = Colors.black;
const Color kSecondaryTextColor = Colors.grey;

// Temporary screen showing "Creating Wallet" for 2 seconds
class CreatingWalletScreen extends StatefulWidget {
  const CreatingWalletScreen({Key? key}) : super(key: key);

  @override
  _CreatingWalletScreenState createState() => _CreatingWalletScreenState();
}

class _CreatingWalletScreenState extends State<CreatingWalletScreen> {
  @override
  void initState() {
    super.initState();
    // Navigate to the ProtectWalletScreen after 2 seconds
    Timer(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ProtectWalletScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAppBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Creating Wallet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: kPrimaryTextColor,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Adding Your Wallet',
              style: TextStyle(
                fontSize: 16,
                color: kSecondaryTextColor,
              ),
            ),
            const SizedBox(height: 24),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(kPrimaryButtonColor),
            ),
          ],
        ),
      ),
    );
  }
}

// Protect Your Wallet screen with biometric authentication
class ProtectWalletScreen extends StatefulWidget {
  const ProtectWalletScreen({Key? key}) : super(key: key);

  @override
  _ProtectWalletScreenState createState() => _ProtectWalletScreenState();
}

class _ProtectWalletScreenState extends State<ProtectWalletScreen> {
  bool _deviceAuthEnabled = false;
  bool _isLoading = false;
  bool _biometricsAvailable = false;
  String _biometricType = "biometric authentication";
  final _secureStorage = const FlutterSecureStorage();
  final LocalAuthentication _localAuth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  // Check if biometrics are available on the device
  Future<void> _checkBiometrics() async {
    bool canCheckBiometrics = false;
    String biometricType = "biometric authentication";

    try {
      // Check if the device can check biometrics
      canCheckBiometrics = await _localAuth.canCheckBiometrics;
      
      // Get available biometrics type
      final List<BiometricType> availableBiometrics = 
          await _localAuth.getAvailableBiometrics();
      
      if (availableBiometrics.contains(BiometricType.fingerprint)) {
        biometricType = "fingerprint";
      } else if (availableBiometrics.contains(BiometricType.face)) {
        biometricType = "face recognition";
      } else if (availableBiometrics.contains(BiometricType.iris)) {
        biometricType = "iris scan";
      }
      
      setState(() {
        _biometricsAvailable = canCheckBiometrics && availableBiometrics.isNotEmpty;
        _biometricType = biometricType;
      });
      
      print('Biometrics available: $_biometricsAvailable (Type: $_biometricType)');
    } on PlatformException catch (e) {
      print('Error checking biometrics: $e');
      setState(() {
        _biometricsAvailable = false;
      });
    }
  }

  // Save biometric authentication preference
  Future<void> _saveBiometricPreference(bool enabled) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      print('Error: User not logged in, cannot save biometric preference.');
      return;
    }
    
    try {
      // Store biometric preference
      await _secureStorage.write(
        key: 'userBiometricEnabled_$userId', 
        value: enabled.toString()
      );
      
      print('Biometric preference saved: $enabled for user $userId');
    } catch (e) {
      print('Error saving biometric preference: $e');
      throw e;
    }
  }

  // Test biometric authentication to ensure it works
  Future<bool> _authenticateWithBiometrics() async {
    try {
      final bool authenticated = await _localAuth.authenticate(
        localizedReason: 'Scan your ${_biometricType} to confirm setup',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      
      print('Biometric authentication result: $authenticated');
      return authenticated;
    } on PlatformException catch (e) {
      print('Error using biometrics: $e');
      return false;
    }
  }

  // Toggle biometric authentication and validate
  Future<void> _toggleBiometricAuth(bool value) async {
    // If turning off, just update state
    if (!value) {
      setState(() {
        _deviceAuthEnabled = false;
      });
      await _saveBiometricPreference(false);
      return;
    }
    
    // If turning on, first check for availability
    if (!_biometricsAvailable) {
      _showBiometricNotAvailableDialog();
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Attempt to authenticate with biometrics as a test
      final bool authenticated = await _authenticateWithBiometrics();
      
      if (authenticated) {
        setState(() {
          _deviceAuthEnabled = true;
        });
        await _saveBiometricPreference(true);
      } else {
        // Authentication failed
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Biometric authentication failed. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error in biometric toggle: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Show dialog when biometrics are not available
  void _showBiometricNotAvailableDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Biometrics Not Available'),
          content: const Text(
            'Your device does not support biometric authentication or it has not been set up in your device settings.'
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // Continue to next screen
  Future<void> _continueToHome() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Save final settings before proceeding
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        // Additional wallet setup could go here (e.g., creating wallet records)
        
        // Navigate to the BusinessHomePage
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const WalletCompletionScreen()),
            (Route<dynamic> route) => false, // Clear the back stack
          );
        }
      } else {
        throw Exception('User not logged in');
      }
    } catch (e) {
      print('Error finalizing wallet setup: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAppBackgroundColor,
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Center image
                  Expanded(
                    flex: 4,
                    child: Center(
                      child: Image.asset(
                        'assets/image2.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  
                  // Text section
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text(
                          'Protect Your Wallet',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: kPrimaryTextColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Adding a biometric security will ensure that you are the only one that can access your wallet',
                          style: TextStyle(
                            fontSize: 16,
                            color: kSecondaryTextColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        
                        // Device authentication toggle
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _biometricType.contains('face') 
                                  ? Icons.face 
                                  : Icons.fingerprint,
                                color: kPrimaryTextColor,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Device Authentication',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: kPrimaryTextColor,
                                  ),
                                ),
                              ),
                              Switch(
                                value: _deviceAuthEnabled,
                                onChanged: _isLoading ? null : _toggleBiometricAuth,
                                activeColor: kPrimaryButtonColor,
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 8),
                        Text(
                          _biometricsAvailable 
                              ? 'Use $_biometricType for faster access'
                              : 'Biometric authentication unavailable',
                          style: TextStyle(
                            fontSize: 14,
                            color: _biometricsAvailable 
                                ? kSecondaryTextColor
                                : Colors.red.shade400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Next button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryButtonColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      disabledBackgroundColor: kPrimaryButtonColor.withOpacity(0.5),
                    ),
                    onPressed: _isLoading ? null : _continueToHome,
                    child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Next',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          // Full-screen loading overlay
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(kPrimaryButtonColor),
                ),
              ),
            ),
        ],
      ),
    );
  }
}