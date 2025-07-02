// lib/Businesssignup.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';     
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/gestures.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hive/hive.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';

import 'Accountsetup/BusinessAccountCreation.dart';

class Businesssignup extends StatefulWidget {
  const Businesssignup({Key? key}) : super(key: key);

  @override
  _BusinesssignupState createState() => _BusinesssignupState();
}

class _BusinesssignupState extends State<Businesssignup> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _phoneController = TextEditingController();
  final GlobalKey<FormState> _phoneFormKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String _formatPhoneNumber(String input) {
    final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    String phone = digits;
    if (phone.startsWith('0')) phone = phone.substring(1);
    if (phone.startsWith('254')) phone = phone.substring(3);
    if (phone.length != 9) throw FormatException('Enter 9 digits after country code');
    return '+254$phone';
  }

  Future<bool> _checkPhoneExists(String phone) async {
    final snap = await _firestore
        .collection('businesses')
        .where('phone_number', isEqualTo: phone)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

Future<void> _signUpWithPhone() async {
  // 1. Validate form
  if (!_phoneFormKey.currentState!.validate()) return;

  // 2. Normalize phone number
  late final String phone;
  try {
    phone = _formatPhoneNumber(_phoneController.text.trim());
  } on FormatException catch (e) {
    _showSnack(e.message);
    return;
  }

  // 3. Check duplicate
  if (await _checkPhoneExists(phone)) {
    _showSnack('This phone number is already registered');
    return;
  }

  // 4. Show loading
  setState(() => _isLoading = true);

  if (kIsWeb) {
    // 5a. Web: invisible‐style reCAPTCHA
    late RecaptchaVerifier verifier;
    verifier = RecaptchaVerifier(
      auth: FirebaseAuthPlatform.instance,    // <— use the platform interface
      container: 'recaptcha-container',
      size: RecaptchaVerifierSize.compact,
      theme: RecaptchaVerifierTheme.light,
      onSuccess: () => verifier.clear(),
      onError: (FirebaseAuthException e) {
        verifier.clear();
        _showSnack('reCAPTCHA error: ${e.message}');
      },
      onExpired: () {
        verifier.clear();
        _showSnack('reCAPTCHA expired');
      },
    );

    try {
      final confirmationResult = await _auth.signInWithPhoneNumber(
        phone,
        verifier,
      );
      setState(() => _isLoading = false);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VerifyCodeScreen(
            confirmationResult: confirmationResult,
          ),
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnack('Error sending code: $e');
    }
  } else {
    // 5b. Mobile: SMS code flow
    await _auth.verifyPhoneNumber(
      phoneNumber: phone,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (cred) async {
        await _auth.signInWithCredential(cred);
        _goToAccountCreation();
      },
      verificationFailed: (e) {
        setState(() => _isLoading = false);
        _showSnack('Verification failed: ${e.message}');
      },
      codeSent: (verificationId, _) {
        setState(() => _isLoading = false);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VerifyCodeScreen(
              verificationId: verificationId,
              phoneNumber: phone,
            ),
          ),
        );
      },
      codeAutoRetrievalTimeout: (_) => setState(() => _isLoading = false),
    );
  }
}


  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final GoogleSignIn google = GoogleSignIn(scopes: ['email', 'profile']);
      await google.signOut();
      final GoogleSignInAccount? user = await google.signIn();
      if (user == null) throw FirebaseAuthException(code: 'CANCELED', message: '');

      final GoogleSignInAuthentication auth = await user.authentication;
      final AuthCredential cred = GoogleAuthProvider.credential(
        accessToken: auth.accessToken,
        idToken: auth.idToken,
      );

      final bool exists = (await _firestore
              .collection('businesses')
              .where('work_email', isEqualTo: user.email)
              .limit(1)
              .get())
          .docs
          .isNotEmpty;
      if (exists) {
        Navigator.pop(context);
        _showSnack('An account with this email already exists');
        return;
      }

      final UserCredential result = await _auth.signInWithCredential(cred);
      final box = Hive.box('appBox');
      await box.putAll({
        'userId': result.user?.uid,
        'userEmail': user.email,
        'displayName': user.displayName,
        'loginMethod': 'google',
        'isBusinessAccount': true,
      });

      Navigator.pop(context);
      _goToAccountCreation();
    } on FirebaseAuthException catch (e) {
      Navigator.pop(context);
      if (e.code != 'CANCELED') _showSnack('Auth error: ${e.message}');
    } catch (e) {
      Navigator.pop(context);
      _showSnack('Unexpected error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _goToAccountCreation() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => BusinessAccountCreation()),
      (route) => false,
    );
  }

  Widget _socialButton(String label, String asset, VoidCallback onTap) {
    return OutlinedButton(
      onPressed: _isLoading ? null : onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        side: const BorderSide(color: Colors.grey),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(asset, width: 24, height: 24),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Business Sign Up', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Image.asset('assets/Businessprofile.jpg', height: 150),
                const SizedBox(height: 24),
                const Text(
                  'Enter your phone number to get started',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Form(
                  key: _phoneFormKey,
                  child: TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Safaricom / Airtel number',
                      prefixText: '+254 ',
                      hintText: '7xxxxxxxx',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(9),
                    ],
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Please enter your phone';
                      if (v.length != 9) return 'Must be exactly 9 digits';
                      if (!RegExp(r'^[17]\d{8}$').hasMatch(v)) {
                        return 'Must start with 1 or 7';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ElevatedButton(
  onPressed: _isLoading ? null : _signUpWithPhone,
  style: ElevatedButton.styleFrom(
    minimumSize: const Size.fromHeight(50),            // full-width, 50px tall
    backgroundColor: const Color(0xFF23461A),          // your dark green
    foregroundColor: Colors.white,                     // text/icon color
    textStyle: const TextStyle(fontSize: 18),          // font size
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
  ),
  child: _isLoading
    ? const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      )
    : const Text('Continue with Phone'),
),

                const SizedBox(height: 24),
                Row(
                  children: const [
                    Expanded(child: Divider()),
                    Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('Or with')),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 16),
                _socialButton('Continue with Apple', 'assets/appleicon.svg', () {}),
                const SizedBox(height: 8),
                _socialButton('Continue with Google', 'assets/Google.svg', _signInWithGoogle),
                const SizedBox(height: 8),
                _socialButton('Continue with Facebook', 'assets/Facebookicon.svg', () {}),
                const SizedBox(height: 8),
                _socialButton(
                  'Continue with Email',
                  'assets/email.svg',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => BusinessEmailSignupScreen()),
                  ),
                ),
                const SizedBox(height: 24),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(color: Colors.black),
                    children: [
                      const TextSpan(text: 'Already have an account? '),
                      TextSpan(
                        text: 'Log in',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        recognizer: TapGestureRecognizer()..onTap = () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading)
            Container(color: Colors.black45, child: const Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }
}

class VerifyCodeScreen extends StatefulWidget {
  final ConfirmationResult? confirmationResult;  // for web
  final String? verificationId;                  // for mobile
  final String? phoneNumber;

  const VerifyCodeScreen({
    Key? key,
    this.confirmationResult,
    this.verificationId,
    this.phoneNumber,
  }) : super(key: key);

  @override
  _VerifyCodeScreenState createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends State<VerifyCodeScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isVerifying = false;
  bool _canResend = false;
  int _resendSecs = 30;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    for (var c in _controllers) c.dispose();
    for (var f in _focusNodes) f.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    setState(() {
      _canResend = false;
      _resendSecs = 30;
    });
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (_resendSecs > 0) {
        setState(() => _resendSecs--);
        return true;
      }
      setState(() => _canResend = true);
      return false;
    });
  }

  Future<void> _resendCode() async {
    if (!_canResend || widget.phoneNumber == null) return;
    await _auth.verifyPhoneNumber(
      phoneNumber: widget.phoneNumber!,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (_) {},
      verificationFailed: (e) => _showSnack('Resend failed: ${e.message}'),
      codeSent: (_, __) {
        _showSnack('Code resent');
        _startResendTimer();
      },
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  Future<void> _verifyCode() async {
    final code = _controllers.map((c) => c.text).join();
    if (code.length != 6) {
      _showSnack('Enter all 6 digits');
      return;
    }

    setState(() => _isVerifying = true);
    try {
      if (widget.confirmationResult != null) {
        await widget.confirmationResult!.confirm(code);
      } else {
        final cred = PhoneAuthProvider.credential(
          verificationId: widget.verificationId!,
          smsCode: code,
        );
        await _auth.signInWithCredential(cred);
      }

      final uid = _auth.currentUser?.uid;
      if (uid != null) {
        await _firestore.collection('businesses').doc(uid).set({
          'phone_number': widget.phoneNumber,
          'user_id': uid,
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
          'accountSetupStep': 1,
        });
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => BusinessAccountCreation()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      _showSnack('Invalid code: ${e.message}');
    } catch (e) {
      _showSnack('Error: $e');
    } finally {
      setState(() => _isVerifying = false);
    }
  }

  void _showSnack(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Widget _digitField(int i) {
    return SizedBox(
      width: 40,
      child: TextField(
        controller: _controllers[i],
        focusNode: _focusNodes[i],
        textAlign: TextAlign.center,
        maxLength: 1,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(counterText: ''),
        onChanged: (v) {
          if (v.isNotEmpty && i < 5) _focusNodes[i + 1].requestFocus();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enter Verification Code', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 24),
            const Text(
              'Enter the 6-digit code sent to your phone',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(6, (i) => _digitField(i)),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Didn't receive code?"),
                TextButton(
                  onPressed: _canResend ? _resendCode : null,
                  child: Text(_canResend ? 'Resend' : 'Wait $_resendSecs s'),
                ),
              ],
            ),
            const SizedBox(height: 24),
           ElevatedButton(
  onPressed: _isVerifying ? null : _verifyCode,
  style: ElevatedButton.styleFrom(
    minimumSize: const Size.fromHeight(50),
    backgroundColor: const Color(0xFF23461A),
    foregroundColor: Colors.white,
    textStyle: const TextStyle(fontSize: 18),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
  ),
  child: _isVerifying
    ? const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      )
    : const Text('Continue'),
),

          ],
        ),
      ),
    );
  }
}

class BusinessEmailSignupScreen extends StatefulWidget {
  const BusinessEmailSignupScreen({Key? key}) : super(key: key);

  @override
  _BusinessEmailSignupScreenState createState() =>
      _BusinessEmailSignupScreenState();
}

class _BusinessEmailSignupScreenState
    extends State<BusinessEmailSignupScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _showSnack(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _signUpEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    final bool exists = (await _firestore
            .collection('businesses')
            .where('work_email', isEqualTo: email)
            .limit(1)
            .get())
        .docs
        .isNotEmpty;
    if (exists) {
      _showSnack('An account with this email already exists');
      setState(() => _isLoading = false);
      return;
    }

    try {
      final UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: pass,
      );

      await _firestore.collection('businesses').doc(cred.user?.uid).set({
        'work_email': email,
        'user_id': cred.user?.uid,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        'accountSetupStep': 1,
      });

      final box = Hive.box('appBox');
      await box.putAll({
        'userId': cred.user?.uid,
        'userEmail': email,
        'loginMethod': 'email',
        'isBusinessAccount': true,
      });

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => BusinessAccountCreation()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      var msg = 'Sign up failed';
      if (e.code == 'weak-password') msg = 'Password too weak';
      if (e.code == 'email-already-in-use') msg = 'Email already registered';
      if (e.code == 'invalid-email') msg = 'Invalid email';
      _showSnack(msg);
    } catch (e) {
      _showSnack('Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Email Sign Up', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Image.asset('assets/Businessprofile.jpg', height: 150),
              const SizedBox(height: 24),
              const Text(
                'Create your business account with email',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Work Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Please enter your work email';
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passCtrl,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Please enter a password';
                  if (v.length < 6) return 'Password must be at least 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _signUpEmail,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF23461a),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Sign Up', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 16),
              RichText(
                text: TextSpan(
                  style: const TextStyle(color: Colors.black),
                  children: [
                    const TextSpan(text: 'Already have an account? '),
                    TextSpan(
                      text: 'Log in',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      recognizer: TapGestureRecognizer()..onTap = () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
