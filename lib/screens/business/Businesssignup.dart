import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/gestures.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'Accountsetup/BusinessAccountCreation.dart';
import 'package:hive/hive.dart';

class Businesssignup extends StatefulWidget {
  const Businesssignup({super.key});

  @override
  _BusinesssignupState createState() => _BusinesssignupState();
}

class _BusinesssignupState extends State<Businesssignup> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _phoneController = TextEditingController();
  // Added isLoading state for the main signup screen if needed for phone/google
  bool _isLoading = false;

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
       setState(() { _isLoading = true; }); // Example usage of _isLoading
       // ... rest of Google Sign-In logic ...
       showDialog( // Keep the dialog for loading during Firebase/Firestore ops
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Center(child: CircularProgressIndicator());
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
        if (Navigator.canPop(context)) Navigator.pop(context);
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
          if (Navigator.canPop(context)) Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("An account with this email already exists")),
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
        } catch (e) {
          print('Error storing data in Hive: $e');
          throw Exception('Failed to store user data: $e');
        }

        if (Navigator.canPop(context)) Navigator.pop(context);

        print('Navigating to BusinessAccountCreation...');
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BusinessAccountCreation(),
          ),
        );
      } catch (e) {
        if (Navigator.canPop(context)) Navigator.pop(context);
        print('Error during authentication: $e');
        rethrow;
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
        const SnackBar(content: Text("An unexpected error occurred during sign in")),
      );
    } finally {
       if (mounted) setState(() { _isLoading = false; });
    }
  }

  String formatPhoneNumber(String phone) {
    if (phone.startsWith('0')) {
      phone = phone.substring(1);
    }
    return '+254$phone';
  }

  Future<void> _signUpWithPhone() async {
    // Existing Phone Sign-Up logic (use _isLoading here if needed)
    String phone = _phoneController.text.trim();
    phone = formatPhoneNumber(phone);

    bool phoneExists = await _checkPhoneNumber(phone);
    if (phoneExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("This phone number is already registered")),
      );
      return;
    }

    setState(() { _isLoading = true; }); // Example usage of _isLoading

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
    } finally {
       if (mounted) setState(() { _isLoading = false; });
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
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Business Sign Up', style: TextStyle(color: Colors.black)),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Image.asset('assets/Businessprofile.jpg', height: 150),
              const SizedBox(height: 24),
              const Text(
                'Enter your phone number to get started', // Adjusted text for phone focus
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Phone Number Input
              TextField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  hintText: 'Phone number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),

               // Continue with Phone button
               ElevatedButton(
                 onPressed: _isLoading ? null : _signUpWithPhone,
                 style: ElevatedButton.styleFrom(
                   backgroundColor: const Color(0xFF23461a),
                   padding: const EdgeInsets.symmetric(vertical: 12),
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                 ),
                 child: _isLoading
                     ? const SizedBox(
                         height: 20,
                         width: 20,
                         child: CircularProgressIndicator(
                           color: Colors.white,
                           strokeWidth: 2,
                         ),
                       )
                     : const Text('Continue with Phone',
                         style: TextStyle(fontSize: 18, color: Colors.white),
                       ),
               ),

              const SizedBox(height: 16),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Or with'),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 16),
              _buildSocialButton(
                'Continue with Apple',
                'assets/appleicon.svg',
                () {},
              ),
              const SizedBox(height: 8),
              _buildSocialButton(
                'Continue with Google',
                'assets/Google.svg',
                () => _signInWithGoogle(context),
              ),
              const SizedBox(height: 8),
              _buildSocialButton(
                'Continue with Facebook',
                'assets/Facebookicon.svg',
                () {},
              ),
               const SizedBox(height: 8),

              // Continue with Email button (moved down)
               _buildSocialButton(
                'Continue with Email',
                'assets/email.svg',
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => BusinessEmailSignupScreen()),
                  );
                },
              ),

              const SizedBox(height: 16),
              Center(
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(color: Colors.black),
                    children: [
                      const TextSpan(text: 'Already have an account? '),
                      TextSpan(
                        text: 'Log in',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            Navigator.pop(context); // Go back to login
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

  // Helper method to build social buttons
  Widget _buildSocialButton(String text, String iconPath, VoidCallback onPressed) {
    return OutlinedButton(
      onPressed: _isLoading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        side: const BorderSide(color: Colors.grey),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(iconPath, height: 24, width: 24),
          SizedBox(width: 8),
          Text(text), // Use the provided text directly
        ],
      ),
    );
  }
}

// Existing VerificationPage class (no changes needed here)
class VerificationPage extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;

  const VerificationPage({super.key, required this.verificationId, required this.phoneNumber});

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
  bool _isVerifying = false;

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
      await Future.delayed(const Duration(seconds: 1));
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
            const SnackBar(content: Text("Verification code resent")),
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
    if (_isVerifying) return;
    
    String code = _controllers.map((c) => c.text).join();

    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a 6-digit code")),
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
            
       

       
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid verification code")),
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
        decoration: const InputDecoration(
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
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Verification',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            const Text(
              'Please Enter the 6-digit code sent to\nyour phone number',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(6, (index) => _buildCodeInput(index)),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "If you didn't receive the code please click",
                  style: TextStyle(color: Colors.grey, fontSize: 10)
                ),
                TextButton(
                  onPressed: _isResendActive ? _resendCode : null,
                  child: Text(
                    _isResendActive ? "Resend Code" : "Wait $_resendTimer seconds",
                    style: TextStyle(
                      color: _isResendActive ? const Color(0xFF23461a) : Colors.grey
                    )
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _verifyCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF23461a),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(35),
                ),
              ),
              child: Text(
                'Continue',
                style: TextStyle(fontSize: 18, color: Colors.white)
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// New screen for Email Sign-up
class BusinessEmailSignupScreen extends StatefulWidget {
  const BusinessEmailSignupScreen({super.key});

  @override
  _BusinessEmailSignupScreenState createState() => _BusinessEmailSignupScreenState();
}

class _BusinessEmailSignupScreenState extends State<BusinessEmailSignupScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false; // Declared _isLoading here

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signUpWithEmailAndPassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      // Check if email already exists in businesses collection
      final QuerySnapshot emailCheck = await _firestore
          .collection('businesses')
          .where('work_email', isEqualTo: email)
          .get();

      if (emailCheck.docs.isNotEmpty) {
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("An account with this email already exists")),
          );
        }
        return;
      }

      // Create user with email and password
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = userCredential.user;

      if (user != null) {
        // Save initial business data to Firestore
        await _firestore.collection('businesses').doc(user.uid).set({
          'userId': user.uid,
          'work_email': email,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'accountSetupStep': 1, // Mark initial setup step
        });

        // Save user and business data to Hive
        try {
          final appBox = Hive.box('appBox');
          await appBox.put('userId', user.uid);
          await appBox.put('userEmail', email);
          await appBox.put('loginMethod', 'email');
          await appBox.put('isBusinessAccount', true);

          final businessData = {
            'userId': user.uid,
            'email': email,
            'createdAt': DateTime.now().toIso8601String(),
            'accountSetupStep': 1,
          };
          await appBox.put('businessData', businessData);

        } catch (e) {
          print('Error storing data in Hive: $e');
          // Continue with navigation even if Hive storage fails
        }

        // Navigate to the next step
        if(mounted) {
          Navigator.pushReplacement( // Use pushReplacement to prevent going back to this screen
            context,
            MaterialPageRoute(
              builder: (context) => BusinessAccountCreation(),
            ),
          );
        }

      } else {
         // This case should theoretically not happen with createUserWithEmailAndPassword
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to create user account")),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'An error occurred during sign up';
      switch (e.code) {
        case 'weak-password':
          errorMessage = 'The password provided is too weak.';
          break;
        case 'email-already-in-use':
          errorMessage = 'The account already exists for that email.';
          break;
        case 'invalid-email':
          errorMessage = 'The email address is not valid.';
          break;
        default:
          errorMessage = 'Error: ${e.message}';
      }
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("An unexpected error occurred: ${e.toString()}")),
        );
      }
    } finally {
      if(mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Business Sign Up', style: TextStyle(color: Colors.black)),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.asset('assets/Businessprofile.jpg', height: 150),
                const SizedBox(height: 24),
                const Text(
                  'Create your business account with email',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                // Email Input Field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Work Email',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your work email';
                    }
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                      return 'Enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Password Input Field
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                   validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a password';
                    }
                    if (value.length < 6) {
                       return 'Password must be at least 6 characters long';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                   onPressed: _isLoading ? null : _signUpWithEmailAndPassword,
                   style: ElevatedButton.styleFrom(
                     backgroundColor: const Color(0xFF23461a),
                     padding: const EdgeInsets.symmetric(vertical: 12),
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                   ),
                   child: _isLoading
                       ? const SizedBox(
                           height: 20,
                           width: 20,
                           child: CircularProgressIndicator(
                             color: Colors.white,
                             strokeWidth: 2,
                           ),
                         )
                       : const Text('Sign Up',
                           style: TextStyle(fontSize: 18, color: Colors.white),
                         ),
                 ),
                 const SizedBox(height: 16),
                 Center(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(color: Colors.black),
                      children: [
                        const TextSpan(text: 'Already have an account? '),
                        TextSpan(
                          text: 'Log in',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              Navigator.pop(context); // Go back to login
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
      ),
    );
  }
}