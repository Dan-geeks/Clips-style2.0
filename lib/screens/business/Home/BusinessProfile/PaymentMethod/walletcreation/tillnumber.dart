import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Ensure this import points to the correct next screen (likely fingerprint.dart)
import 'fingerprint.dart';

// --- Constants ---
const Color kAppBackgroundColor = Colors.white;
const Color kPrimaryButtonColor = Color(0xFF23461a);
const Color kPrimaryTextColor = Colors.black;
const Color kSecondaryTextColor = Colors.grey;

// --- Enum for Payment Type ---
enum PaymentType { till, paybill, phone }

class PaymentNumberScreen extends StatefulWidget {
  const PaymentNumberScreen({super.key});

  @override
  _PaymentNumberScreenState createState() => _PaymentNumberScreenState();
}

class _PaymentNumberScreenState extends State<PaymentNumberScreen> {
  // --- State Variables ---
  PaymentType _selectedPaymentType = PaymentType.till; // Default selection
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;

  // --- Text Editing Controllers ---
  final TextEditingController _tillNumberController = TextEditingController();
  final TextEditingController _paybillNumberController = TextEditingController();
  final TextEditingController _accountNumberController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();
  // --- End Text Editing Controllers ---

  @override
  void dispose() {
    _tillNumberController.dispose();
    _paybillNumberController.dispose();
    _accountNumberController.dispose();
    _phoneNumberController.dispose();
    super.dispose();
  }

  // --- Function to save selected payment details ---
  Future<void> _savePaymentDetailsAndContinue() async {
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

      Map<String, dynamic> dataToSave = {
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // --- Prepare data based on selected type ---
      switch (_selectedPaymentType) {
        case PaymentType.till:
          dataToSave['paymentIdentifierType'] = 'Till';
          dataToSave['tillNumber'] = _tillNumberController.text.trim();
          break;
        case PaymentType.paybill:
          dataToSave['paymentIdentifierType'] = 'Paybill';
          dataToSave['paybillNumber'] = _paybillNumberController.text.trim();
          dataToSave['accountNumber'] = _accountNumberController.text.trim(); // Optional, can be empty
          break;
        case PaymentType.phone:
          dataToSave['paymentIdentifierType'] = 'Phone';
          // Simple formatting example (ensure it matches your needs)
          String phone = _phoneNumberController.text.trim();
          if (phone.startsWith('0') && phone.length == 10) {
            phone = '254${phone.substring(1)}';
          } else if (phone.length == 9) {
             phone = '254$phone';
          }
          dataToSave['phoneNumber'] = phone;
          break;
      }
      // --- End Prepare data ---

      // Save data to Firestore in wallets collection
      await FirebaseFirestore.instance
          .collection('wallets')
          .doc(user.uid)
          .set(dataToSave, SetOptions(merge: true));

      // Also store in businesses collection (optional, adjust if needed)
      await FirebaseFirestore.instance
          .collection('businesses')
          .doc(user.uid)
          .set(dataToSave, SetOptions(merge: true));

      // print('Payment details saved successfully: $dataToSave');

      // Navigate to the next screen
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CreatingWalletScreen()), // Navigate to Fingerprint/Loading Screen
        );
      }
    } catch (e) {
      // print('Error saving payment details: $e');
      setState(() {
        _errorMessage = 'Failed to save payment details: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  // --- End save function ---

  // --- Widget builder for input fields ---
  Widget _buildInputFields() {
    switch (_selectedPaymentType) {
      case PaymentType.till:
        return TextFormField(
          controller: _tillNumberController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(7), // Typical Till length
          ],
          decoration: _inputDecoration('Till Number', 'Enter M-Pesa Till Number', Icons.account_balance_wallet),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your Till Number';
            }
            if (value.length < 5) { // Basic validation
               return 'Till Number seems too short';
            }
            return null;
          },
        );
      case PaymentType.paybill:
        return Column(
          children: [
            TextFormField(
              controller: _paybillNumberController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: _inputDecoration('Paybill Number', 'Enter Business Paybill Number', Icons.business),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter the Paybill Number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _accountNumberController,
              keyboardType: TextInputType.text, // Can be alphanumeric
              decoration: _inputDecoration('Account Number (Optional)', 'Enter Account Number if required', Icons.person_pin),
              // Account number is often optional, so no validator needed unless required
               validator: (value) {
                // Add validation if account number becomes mandatory
                return null;
              },
            ),
          ],
        );
      case PaymentType.phone:
        return TextFormField(
          controller: _phoneNumberController,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: _inputDecoration('Phone Number', 'Enter M-Pesa Phone Number (07... or 254...)', Icons.phone_android),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your Phone Number';
            }
             if (value.length < 9 || value.length > 12) { // Basic length check for Kenyan numbers
               return 'Please enter a valid phone number';
             }
            return null;
          },
        );
    }
  }
  // --- End input field builder ---

  // Helper for InputDecoration
  InputDecoration _inputDecoration(String label, String hint, IconData icon) {
     return InputDecoration(
       labelText: label,
       hintText: hint,
       prefixIcon: Icon(icon),
       border: OutlineInputBorder(
         borderRadius: BorderRadius.circular(12),
       ),
       focusedBorder: OutlineInputBorder(
         borderRadius: BorderRadius.circular(12),
         borderSide: BorderSide(color: kPrimaryButtonColor),
       ),
     );
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
          'Set Up Receiving Number', // Updated Title
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
                const SizedBox(height: 20),

                // --- Payment Type Selection ---
                Text(
                  'Select the number type you use to receive M-Pesa payments:',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: kSecondaryTextColor),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ChoiceChip(
                      label: const Text('M-Pesa Till'),
                      selected: _selectedPaymentType == PaymentType.till,
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedPaymentType = PaymentType.till);
                      },
                      selectedColor: kPrimaryButtonColor.withOpacity(0.2),
                      checkmarkColor: kPrimaryButtonColor,
                    ),
                    ChoiceChip(
                      label: const Text('Paybill'),
                      selected: _selectedPaymentType == PaymentType.paybill,
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedPaymentType = PaymentType.paybill);
                      },
                       selectedColor: kPrimaryButtonColor.withOpacity(0.2),
                       checkmarkColor: kPrimaryButtonColor,
                    ),
                    ChoiceChip(
                      label: const Text('Phone'),
                      selected: _selectedPaymentType == PaymentType.phone,
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedPaymentType = PaymentType.phone);
                      },
                       selectedColor: kPrimaryButtonColor.withOpacity(0.2),
                       checkmarkColor: kPrimaryButtonColor,
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                // --- End Payment Type Selection ---

                // --- Dynamically Built Input Fields ---
                _buildInputFields(),
                // --- End Input Fields ---

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

                const Spacer(), // Pushes button to bottom

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
                    onPressed: _isLoading ? null : _savePaymentDetailsAndContinue,
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