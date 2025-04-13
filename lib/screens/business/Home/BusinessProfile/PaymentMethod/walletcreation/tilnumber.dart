import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'fingerprint.dart';

// --- Constants ---
const Color kAppBackgroundColor = Colors.white;
const Color kPrimaryButtonColor = Color(0xFF23461a);
const Color kPrimaryTextColor = Colors.black;
const Color kSecondaryTextColor = Colors.grey;

class TillNumberScreen extends StatefulWidget {
  const TillNumberScreen({Key? key}) : super(key: key);

  @override
  _TillNumberScreenState createState() => _TillNumberScreenState();
}

class _TillNumberScreenState extends State<TillNumberScreen> {
  final TextEditingController _tillNumberController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _tillNumberController.dispose();
    super.dispose();
  }

  // Save till number to Firestore
  Future<void> _saveTillNumberAndContinue() async {
    if (!_formKey.currentState!.validate() || _isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      final tillNumber = _tillNumberController.text.trim();
      
      // Save till number to Firestore in wallets collection
      await FirebaseFirestore.instance
          .collection('wallets')
          .doc(user.uid)
          .set({
            'tillNumber': tillNumber,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      // Also store in businesses collection for redundancy
      await FirebaseFirestore.instance
          .collection('businesses')
          .doc(user.uid)
          .set({
            'tillNumber': tillNumber,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      print('Till number saved successfully: $tillNumber');

      // Navigate to the next screen in wallet setup
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CreatingWalletScreen()),
        );
      }
    } catch (e) {
      print('Error saving till number: $e');
      setState(() {
        _errorMessage = 'Failed to save till number: ${e.toString()}';
      });
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
      appBar: AppBar(
        backgroundColor: kAppBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: kPrimaryTextColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Enter M-Pesa Till Number',
          style: TextStyle(color: kPrimaryTextColor, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                
                // Instructions
                Text(
                  'Please enter your M-Pesa Till Number',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: kSecondaryTextColor,
                  ),
                ),
                
                const SizedBox(height: 12),
                
                Text(
                  'This till number will be used to receive payments through M-Pesa',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: kSecondaryTextColor,
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Till Number Input Field
                TextFormField(
                  controller: _tillNumberController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(7), // M-Pesa till numbers are typically 5-7 digits
                  ],
                  decoration: InputDecoration(
                    labelText: 'Till Number',
                    hintText: 'Enter your M-Pesa till number',
                    prefixIcon: Icon(Icons.account_balance_wallet),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: kPrimaryButtonColor),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your till number';
                    }
                    if (value.length < 5) {
                      return 'Till number must be at least 5 digits';
                    }
                    return null;
                  },
                ),
                
                // Error message if any
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
                
                const Spacer(),
                
                // Continue Button
                Padding(
                  padding: const EdgeInsets.only(bottom: 30.0),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryButtonColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      disabledBackgroundColor: kPrimaryButtonColor.withOpacity(0.5),
                    ),
                    onPressed: _isLoading ? null : _saveTillNumberAndContinue,
                    child: _isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Continue',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}