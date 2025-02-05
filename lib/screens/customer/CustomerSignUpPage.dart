import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/gestures.dart';


class CustomerSignUpPage extends StatefulWidget {
  @override
  _CustomerSignUpPageState createState() => _CustomerSignUpPageState();
}

class _CustomerSignUpPageState extends State<CustomerSignUpPage> {
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _phoneController = TextEditingController();
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
   @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

    Future<bool> _checkPhoneNumber(String phoneNumber) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('checkPhoneNumber');
      final result = await callable.call({'phoneNumber': phoneNumber});
      return result.data['exists'] as bool;
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text("Signed in as ${userCredential.user?.displayName}")),
      );

    
    } catch (e) {
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
    phone = formatPhoneNumber(phone);

    // Check if the phone number already exists
    bool phoneExists = await _checkPhoneNumber(phone);
    if (phoneExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("This phone number is already registered")),
      );
      return;
    }

    // If the phone number doesn't exist, proceed with verification
    await _auth.verifyPhoneNumber(
      phoneNumber: phone,
      timeout: Duration(seconds: 120),
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Sign the user in with the auto-generated credential
        UserCredential result = await _auth.signInWithCredential(credential);
        User? user = result.user;

        if (user != null) {
        ;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error signing in with phone number")),
          );
        }
      },
      verificationFailed: (FirebaseAuthException exception) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Verification failed: ${exception.message}")),
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
          // Your existing UI code
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
              // Rest of your UI code
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
                color: Colors.black, // Optional: make it look like a link
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () {
                
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
  }

  Widget _buildSocialButton(
      String text, String iconPath, VoidCallback onPressed) {
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



class VerificationPage extends StatefulWidget {
  String verificationId;
  final String phoneNumber;

  VerificationPage({required this.verificationId, required this.phoneNumber});

  @override
  _VerificationPageState createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isResendActive = true;
  int _resendTimer = 0;

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
          // Auto-retrieve may be possible on some devices
          UserCredential result = await _auth.signInWithCredential(credential);
          User? user = result.user;
          if (user != null) {
           
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Verification failed: ${e.message}")),
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            widget.verificationId = verificationId;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Verification code resent")),
          );
          _startResendTimer();
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
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
      AuthCredential credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: code,
      );

      UserCredential result = await _auth.signInWithCredential(credential);
      User? user = result.user;

      if (user != null) {
       
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error signing in with verification code")),
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
            Text('Verification',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold), textAlign: TextAlign.center,
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
                  onPressed:  _resendCode,
                  child: Text("Resend Code", style: TextStyle(color: Color(0xFF23461a))),
                ),
              ],
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _verifyCode,
              child: Text('Continue',
                  style: TextStyle(fontSize: 18, color: Colors.white)),
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