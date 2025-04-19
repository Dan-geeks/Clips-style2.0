import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/gestures.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Added Firestore import
import 'package:hive_flutter/hive_flutter.dart'; // Added Hive import for local storage
import 'HomePage/CustomerHomePage.dart';

class CustomerSignUpPage extends StatefulWidget {
  const CustomerSignUpPage({super.key});

  @override
  _CustomerSignUpPageState createState() => _CustomerSignUpPageState();
}

class _CustomerSignUpPageState extends State<CustomerSignUpPage> {
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // Added Firestore instance
  final TextEditingController _phoneController = TextEditingController();
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  
  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<bool> _checkPhoneNumber(String phoneNumber) async {
    try {
      // First check directly in Firestore
      final QuerySnapshot result = await _firestore
          .collection('clients')
          .where('phoneNumber', isEqualTo: phoneNumber)
          .get();
          
      if (result.docs.isNotEmpty) {
        return true;
      }
      
      // If not found, use the cloud function as fallback
      final HttpsCallable callable = _functions.httpsCallable('checkPhoneNumber');
      final result2 = await callable.call({'phoneNumber': phoneNumber});
      return result2.data['exists'] as bool;
    } catch (e) {
      print('Error checking phone number: $e');
      return false;
    }
  }

  Future<void> _signInWithGoogle(BuildContext context) async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);
          
      User? user = userCredential.user;
      if (user == null) {
        throw Exception("Failed to get user from credentials");
      }

      // Check if client document already exists
      DocumentSnapshot clientDoc = await _firestore
          .collection('clients')
          .doc(user.uid)
          .get();
          
      // If document doesn't exist, create it
      if (!clientDoc.exists) {
        // Create the client document in Firestore
        await _firestore.collection('clients').doc(user.uid).set({
          'userId': user.uid,
          'email': user.email ?? googleUser.email,
          'displayName': user.displayName ?? googleUser.displayName,
          'firstName': user.displayName?.split(' ').first ?? '',
          'lastName': (user.displayName?.split(' ') ?? []).length > 1 
              ? (user.displayName?.split(' ') ?? []).sublist(1).join(' ') 
              : '',
          'photoURL': user.photoURL,
          'phoneNumber': user.phoneNumber ?? '',
          'isProfileComplete': true,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
          'notificationSettings': {
            'email': true,
            'push': true,
            'sms': true
          }
        });
        
        print("Created new client document for ${user.uid}");
      } else {
        // Update last login time
        await _firestore.collection('clients').doc(user.uid).update({
          'lastLogin': FieldValue.serverTimestamp(),
        });
        
        print("Updated existing client document for ${user.uid}");
      }
      
      // Save basic user data to Hive for offline access
      try {
        final appBox = Hive.box('appBox');
        await appBox.put('userData', {
          'userId': user.uid,
          'email': user.email,
          'firstName': user.displayName?.split(' ').first ?? '',
          'lastName': (user.displayName?.split(' ') ?? []).length > 1 
              ? (user.displayName?.split(' ') ?? []).sublist(1).join(' ') 
              : '',
          'phoneNumber': user.phoneNumber ?? '',
          'photoURL': user.photoURL,
        });
      } catch (e) {
        print("Error saving user data to Hive: $e");
        // Continue even if Hive storage fails
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Signed in as ${userCredential.user?.displayName}")),
      );

      // Navigate to Home page after successful sign-in
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => CustomerHomePage()),
      );
    } catch (e) {
      print("Google sign in error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error signing in with Google: $e")),
      );
    }
  }

  String formatPhoneNumber(String phone) {
    if (phone.startsWith('0')) {
      phone = phone.substring(1);
    }
    return '+254$phone';
  }

  Future<void> _signUpWithPhone() async {
    String phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enter a phone number")),
      );
      return;
    }
    
    phone = formatPhoneNumber(phone);

    // Check if phone number already exists
    bool phoneExists = await _checkPhoneNumber(phone);
    if (phoneExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("This phone number is already registered")),
      );
      return;
    }

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phone,
        timeout: Duration(seconds: 120),
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            UserCredential result = await _auth.signInWithCredential(credential);
            User? user = result.user;

            if (user != null) {
              // Create client profile in Firestore after auto verification
              await _createClientDocument(user, phone);
              
              // Navigate to Home page
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => CustomerHomePage()),
                (route) => false,
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Error signing in with phone number")),
              );
            }
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Error: ${e.toString()}")),
            );
          }
        },
        verificationFailed: (FirebaseAuthException exception) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Verification failed: ${exception.message}")),
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => VerificationPage(
              verificationId: verificationId,
              phoneNumber: phone,
              firestore: _firestore, // Pass firestore instance
            ),
          ));
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    }
  }

  // Helper method to create a client document
  static Future<void> _createClientDocument(User user, String phoneNumber) async {
    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      
      // Check if document already exists
      DocumentSnapshot clientDoc = await firestore
          .collection('clients')
          .doc(user.uid)
          .get();
          
      if (!clientDoc.exists) {
        // Create the client document with the user's info
        await firestore.collection('clients').doc(user.uid).set({
          'userId': user.uid,
          'email': user.email ?? '',
          'displayName': user.displayName ?? '',
          'firstName': user.displayName?.split(' ').first ?? '',
          'lastName': (user.displayName?.split(' ') ?? []).length > 1 
              ? user.displayName?.split(' ').sublist(1).join(' ') ?? '' 
              : '',
          'phoneNumber': phoneNumber,
          'photoURL': user.photoURL ?? '',
          'isProfileComplete': true,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
          'notificationSettings': {
            'email': true,
            'push': true,
            'sms': true
          }
        });
      
        print("Created new client document for ${user.uid}");
      
        // Save basic user data to Hive for offline access
        try {
          final appBox = Hive.box('appBox');
          await appBox.put('userData', {
            'userId': user.uid,
            'email': user.email,
            'firstName': user.displayName?.split(' ').first ?? '',
            'lastName': (user.displayName?.split(' ') ?? []).length > 1 
                ? (user.displayName?.split(' ') ?? []).sublist(1).join(' ') 
                : '',
            'phoneNumber': phoneNumber,
            'photoURL': user.photoURL,
          });
        } catch (e) {
          print("Error saving user data to Hive: $e");
          // Continue even if Hive storage fails
        }
      }
    } catch (e) {
      print("Error creating client document: $e");
      // Let the error propagate up to be handled by the caller
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title:
            Text('Customer Sign Up', style: TextStyle(color: Colors.black)),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Image.asset('assets/Frame8.png', height: 150),
              SizedBox(height: 24),
              Text(
                'Enter your phone number',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              TextField(
                controller: _phoneController,
                decoration: InputDecoration(
                  hintText: 'Phone number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _signUpWithPhone,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF23461a),
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), 
                ),
                child: Text('Continue',
                style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
           
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Or with'),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              SizedBox(height: 16),
              _buildSocialButton(
                'Continue with Apple',
                'assets/appleicon.svg',
                () {},
              ),
              SizedBox(height: 8),
              _buildSocialButton(
                'Continue with Google',
                'assets/Google.svg',
                () => _signInWithGoogle(context),
              ),
              SizedBox(height: 8),
              _buildSocialButton(
                'Continue with Facebook',
                'assets/Facebookicon.svg',
                () {},
              ),
              SizedBox(height: 8),
          
              SizedBox(height: 16),
              Center(
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(color: Colors.black),
                    children: [
                      TextSpan(text: 'Already have an account? '),
                      TextSpan(
                        text: 'Log in',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            Navigator.pop(context);
                          },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSocialButton(
      String text, String iconPath, VoidCallback onPressed) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.symmetric(vertical: 12),
        side: BorderSide(color: Colors.grey),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(iconPath, height: 24, width: 24),
          SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }
}

class VerificationPage extends StatefulWidget {
  String verificationId;
  final String phoneNumber;
  final FirebaseFirestore firestore; // Added firestore instance

  VerificationPage({super.key, 
    required this.verificationId, 
    required this.phoneNumber,
    required this.firestore, // Require firestore instance
  });

  @override
  _VerificationPageState createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isResendActive = true;
  int _resendTimer = 0;
  bool _isVerifying = false; // Added to track verification state

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _startResendTimer() {
    setState(() {
      _isResendActive = false;
      _resendTimer = 30;
    });
    Future.doWhile(() async {
      await Future.delayed(Duration(seconds: 1));
      setState(() {
        if (_resendTimer > 0) {
          _resendTimer--;
        }
      });
      if (_resendTimer == 0) {
        setState(() {
          _isResendActive = true;
        });
        return false;
      }
      return true;
    });
  }

  Future<void> _resendCode() async {
    if (!_isResendActive) return;

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: widget.phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          UserCredential result = await _auth.signInWithCredential(credential);
          User? user = result.user;
          if (user != null) {
            // Create client document after verification
            await _createClientDocument(user);
            
            // Navigate to home page
            if (mounted) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => CustomerHomePage()),
                (route) => false,
              );
            }
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Verification failed: ${e.message}")),
            );
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          if (mounted) {
            setState(() {
              widget.verificationId = verificationId;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Verification code resent")),
            );
            _startResendTimer();
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error resending code: ${e.toString()}")),
        );
      }
    }
  }

  Future<void> _verifyCode() async {
    if (_isVerifying) return; // Prevent multiple attempts
    
    String code = _controllers.map((c) => c.text).join();

    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enter a 6-digit code")),
      );
      return;
    }

    setState(() {
      _isVerifying = true;
    });

    try {
      AuthCredential credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: code,
      );

      UserCredential result = await _auth.signInWithCredential(credential);
      User? user = result.user;

      if (user != null) {
        // Create client document in Firestore
        await _createClientDocument(user);
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Successfully verified and created your account!")),
        );
        
        // Navigate to Home page
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => CustomerHomePage()),
          (route) => false,
        );
      } else {
        setState(() {
          _isVerifying = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error signing in with verification code")),
        );
      }
    } catch (e) {
      setState(() {
        _isVerifying = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    }
  }

  // Method to create the client document in Firestore
  Future<void> _createClientDocument(User user) async {
    try {
      // Check if document already exists
      DocumentSnapshot clientDoc = await widget.firestore
          .collection('clients')
          .doc(user.uid)
          .get();
          
      if (!clientDoc.exists) {
        // Create the client document with basic information
        await widget.firestore.collection('clients').doc(user.uid).set({
          'userId': user.uid,
          'email': user.email ?? '',
          'displayName': user.displayName ?? '',
          'firstName': user.displayName?.split(' ').first ?? '',
          'lastName': (user.displayName?.split(' ') ?? []).length > 1 
              ? (user.displayName?.split(' ') ?? []).sublist(1).join(' ') 
              : '',
          'phoneNumber': widget.phoneNumber,
          'photoURL': user.photoURL ?? '',
          'isProfileComplete': true,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
          'notificationSettings': {
            'email': true,
            'push': true,
            'sms': true
          }
        });
      
        print("Created new client document for ${user.uid}");
      
        // Save basic user data to Hive for offline access
        try {
          final appBox = Hive.box('appBox');
          await appBox.put('userData', {
            'userId': user.uid,
            'firstName': user.displayName?.split(' ').first ?? '',
            'lastName': (user.displayName?.split(' ') ?? []).length > 1 
                ? user.displayName?.split(' ').sublist(1).join(' ') ?? '' 
                : '',
            'phoneNumber': widget.phoneNumber,
          });
        } catch (e) {
          print("Error saving user data to Hive: $e");
          // Continue even if Hive storage fails
        }
      } else {
        // Update last login time if document already exists
        await widget.firestore.collection('clients').doc(user.uid).update({
          'lastLogin': FieldValue.serverTimestamp(),
          'phoneNumber': widget.phoneNumber,
        });
        
        print("Updated existing client document for ${user.uid}");
      }
    } catch (e) {
      print("Error creating client document: $e");
      rethrow;
    }
  }

  Widget _buildCodeInput(int index) {
    return Container(
      width: 40,
      height: 50,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black),
        borderRadius: BorderRadius.circular(5),
      ),
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        decoration: InputDecoration(
          counterText: "",
          border: InputBorder.none,
        ),
        onChanged: (value) {
          if (value.isNotEmpty && index < 5) {
            _focusNodes[index + 1].requestFocus();
          }
          // Auto-verify if all fields are filled
          if (index == 5 && value.isNotEmpty) {
            String code = _controllers.map((c) => c.text).join();
            if (code.length == 6) {
              _verifyCode();
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Verification',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold), 
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 40),
            Text(
              'Please Enter the 6-digit code sent to\nyour phone number',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(6, (index) => _buildCodeInput(index)),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("If you didn't receive the code please click",
                  style: TextStyle(color: Colors.grey, fontSize: 10)),
                TextButton(
                  onPressed: _isResendActive ? _resendCode : null,
                  child: Text(
                    _isResendActive ? "Resend Code" : "Wait $_resendTimer seconds",
                    style: TextStyle(
                      color: _isResendActive ? Color(0xFF23461a) : Colors.grey
                    )
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isVerifying ? null : _verifyCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF23461a),
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(35),
                ),
              ),
              child: _isVerifying 
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text('Continue', 
                    style: TextStyle(fontSize: 18, color: Colors.white)
                  ),
            ),
          ],
        ),
      ),
    );
  }
}