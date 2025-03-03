import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/gestures.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'Accountsetup/BusinessAccountCreation.dart';
import 'package:hive/hive.dart';
import 'dart:developer';

class Businesssignup extends StatefulWidget {
  @override
  _BusinesssignupState createState() => _BusinesssignupState();
}

class _BusinesssignupState extends State<Businesssignup> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _phoneController = TextEditingController();
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<bool> _checkPhoneNumber(String phoneNumber) async {
    try {
      final QuerySnapshot result = await _firestore
          .collection('businesses')
          .where('phone_number', isEqualTo: phoneNumber)
          .get();
      return result.docs.isNotEmpty;
    } catch (e) {
      print('Error checking phone number: $e');
      return false;
    }
  }

   Future<void> _signInWithGoogle(BuildContext context) async {
  try {

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Center(child: CircularProgressIndicator());
      },
    );

    final GoogleSignIn googleSignIn = GoogleSignIn(
      scopes: [
        'email',
        'profile',
      ],
    );


    await googleSignIn.signOut();
    
  
    print('Starting Google Sign In...');
    final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
    

    if (googleUser == null) {
      Navigator.pop(context);
      print('User canceled the sign-in flow');
      return;
    }

    print('Got Google User: ${googleUser.email}');

    try {

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      print('Got Google Auth');

     
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      print('Created Firebase credential');


      final QuerySnapshot emailCheck = await _firestore
          .collection('businesses')
          .where('work_email', isEqualTo: googleUser.email)
          .get();

      if (emailCheck.docs.isNotEmpty) {
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("An account with this email already exists")),
        );
        return;
      }


      print('Signing in with Firebase...');
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      print('Firebase sign in successful');

    
      try {
        final appBox = Hive.box('appBox');
        print('Successfully opened Hive box');
        
     
        await appBox.put('userId', userCredential.user?.uid);
        print('Stored userId in Hive: ${userCredential.user?.uid}');
        
        await appBox.put('userEmail', googleUser.email);
        print('Stored userEmail in Hive: ${googleUser.email}');
        
        await appBox.put('displayName', googleUser.displayName);
        print('Stored displayName in Hive: ${googleUser.displayName}');
        
        await appBox.put('loginMethod', 'google');
        print('Stored loginMethod in Hive: google');
        
        await appBox.put('isBusinessAccount', true);
        print('Stored isBusinessAccount in Hive: true');
        
       
        final businessData = {
          'userId': userCredential.user?.uid,
          'email': googleUser.email,
          'displayName': googleUser.displayName,
          'createdAt': DateTime.now().toIso8601String(),
          'accountSetupStep': 1,
        };
        await appBox.put('businessData', businessData);
        print('Stored businessData in Hive: $businessData');

      
        print('\nVerifying stored data:');
        print('userId from Hive: ${appBox.get('userId')}');
        print('userEmail from Hive: ${appBox.get('userEmail')}');
        print('displayName from Hive: ${appBox.get('displayName')}');
        print('loginMethod from Hive: ${appBox.get('loginMethod')}');
        print('isBusinessAccount from Hive: ${appBox.get('isBusinessAccount')}');
        print('businessData from Hive: ${appBox.get('businessData')}');

      } catch (e) {
        print('Error storing data in Hive: $e');
        throw Exception('Failed to store user data: $e');
      }


      Navigator.pop(context);


      print('Navigating to BusinessAccountCreation...');
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BusinessAccountCreation(),
        ),
      );

    } catch (e) {
      Navigator.pop(context); 
      print('Error during authentication: $e');
      throw e;
    }

  } on FirebaseAuthException catch (e) {
   
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    
    String errorMessage = 'An error occurred during Google sign in';
    print('FirebaseAuthException: ${e.code} - ${e.message}');
    
    if (e.code == 'account-exists-with-different-credential') {
      errorMessage = 'An account already exists with this email';
    } else if (e.code == 'invalid-credential') {
      errorMessage = 'Invalid credentials';
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(errorMessage)),
    );
  } catch (e) {

    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    
    print('Unexpected error during Google sign in: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("An unexpected error occurred during sign in")),
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
    phone = formatPhoneNumber(phone);
    

    
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
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _auth.signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Verification failed: ${e.message}")),
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => VerificationPage(
              verificationId: verificationId,
              phoneNumber: phone,
            ),
          ));
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error sending verification code: $e")),
      );
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
        title: Text('Business Sign Up', style: TextStyle(color: Colors.black)),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(15.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Image.asset('assets/Businessprofile.jpg', height: 150),
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
                child: Text('Continue',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
                onPressed: _signUpWithPhone,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF23461a),
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
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
              _buildSocialButton(
                'Continue with Email',
                'assets/email.svg',
                () => Navigator.pop(context),
              ),
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

  Widget _buildSocialButton(String text, String iconPath, VoidCallback onPressed) {
    return OutlinedButton(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(iconPath, height: 24, width: 24),
          SizedBox(width: 8),
          Text(text),
        ],
      ),
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.symmetric(vertical: 12),
        side: BorderSide(color: Colors.grey),
      ),
    );
  }
}

class VerificationPage extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;

  VerificationPage({required this.verificationId, required this.phoneNumber});

  @override
  _VerificationPageState createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isResendActive = true;
  int _resendTimer = 0;
  

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

  }

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
          await _auth.signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Verification failed: ${e.message}")),
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Verification code resent")),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
      _startResendTimer();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error resending code: ${e.toString()}")),
      );
    }
  }

  Future<void> _verifyCode() async {
    String code = _controllers.map((c) => c.text).join();

    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enter a 6-digit code")),
      );
      return;
    }

    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: code,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);

      if (userCredential.user != null) {
       

        // Create business profile with full structure
        final businessData = {
          'business_name': '',
          'registration_number': '',
          'work_email': '',
          'phone_number': widget.phoneNumber,
          'about_us': '',
          'profile_image_url': '',
          'main_category': '',
          'sub_categories': [],
          'user_id': userCredential.user?.uid,
          'is_profile_complete': false,
          
          'business_location': {
            'address': '',
            'geo_point': null,
            'is_location_enabled': false
          },
          
          'notification_preferences': {
            'email': true,
            'push': true,
            'sms': true
          },
          
          'operating_hours': {
            'monday': {'is_open': false, 'start': '', 'end': ''},
            'tuesday': {'is_open': false, 'start': '', 'end': ''},
            'wednesday': {'is_open': false, 'start': '', 'end': ''},
            'thursday': {'is_open': false, 'start': '', 'end': ''},
            'friday': {'is_open': false, 'start': '', 'end': ''},
            'saturday': {'is_open': false, 'start': '', 'end': ''},
            'sunday': {'is_open': false, 'start': '', 'end': ''}
          },
          
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp()
        };

     
        final DocumentReference docRef = await _firestore
            .collection('businesses')
            .add(businessData);
            
       


        await _firestore
            .collection('businesses')
            .doc(docRef.id)
            .collection('analytics')
            .doc('daily_stats')
            .set({
              'date': FieldValue.serverTimestamp(),
              'total_sales': 0,
              'total_appointments': 0,
              'new_clients': 0,
              'returning_clients': 0,
              'cancellations': 0,
              'no_shows': 0,
              'service_breakdown': [],
              'staff_performance': []
            });

       
       ;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Invalid verification code")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
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
            Text(
              'Verification',
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
                Text(
                  "If you didn't receive the code please click",
                  style: TextStyle(color: Colors.grey, fontSize: 10)
                ),
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
              onPressed: _verifyCode,
              child: Text(
                'Continue',
                style: TextStyle(fontSize: 18, color: Colors.white)
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF23461a),
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(35),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}