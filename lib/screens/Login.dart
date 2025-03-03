 import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> checkUserTypeAndNavigate(User user) async {
  try {

    final businessQuery = await _firestore
        .collection('businesses')
        .where('userId', isEqualTo: user.uid)
        .get();

    final clientQuery = await _firestore
        .collection('clients')
        .where('userId', isEqualTo: user.uid)
        .get();

    if (businessQuery.docs.isNotEmpty) {
      final businessDoc = businessQuery.docs.first;
      final businessId = businessDoc.id;
      final businessData = businessDoc.data();
      
      
      businessData['documentId'] = businessId;

    
     


    } else if (clientQuery.docs.isNotEmpty) {
      
    } else {
      
    }
  } catch (e) {
    print('Error loading user data: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error loading user data: ${e.toString()}')),
    );
  }
}
  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
     if (googleUser == null) {
       setState(() => _isLoading = false);
       return;
     }

     final GoogleSignInAuthentication googleAuth = 
         await googleUser.authentication;
     final AuthCredential credential = GoogleAuthProvider.credential(
       accessToken: googleAuth.accessToken,
       idToken: googleAuth.idToken,
     );

     final UserCredential userCredential = 
         await _auth.signInWithCredential(credential);
     
     if (userCredential.user != null) {
       await checkUserTypeAndNavigate(userCredential.user!);
     }

   } catch (e) {
     print("Error signing in with Google: $e");
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(content: Text('Google sign in failed: ${e.toString()}')),
     );
   } finally {
     if (mounted) setState(() => _isLoading = false);
   }
 }

 Future<void> _signInWithEmail() async {
   if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(content: Text('Please enter both email and password')),
     );
     return;
   }

   setState(() => _isLoading = true);

   try {
     final UserCredential userCredential = 
         await _auth.signInWithEmailAndPassword(
       email: _emailController.text.trim(),
       password: _passwordController.text,
     );
     
     if (userCredential.user != null) {
       await checkUserTypeAndNavigate(userCredential.user!);
     }

   } on FirebaseAuthException catch (e) {
     String message = 'An error occurred';
     
     if (e.code == 'user-not-found') {
       message = 'No user found with this email';
     } else if (e.code == 'wrong-password') {
       message = 'Wrong password provided';
     } else if (e.code == 'invalid-email') {
       message = 'Invalid email format';
     }
     
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(content: Text(message)),
     );
   } catch (e) {
     print("Error signing in with email: ${e.toString()}");
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(content: Text('Email sign in failed: ${e.toString()}')),
     );
   } finally {
     if (mounted) setState(() => _isLoading = false);
   }
 }

 @override
 Widget build(BuildContext context) {
   return Stack(
     children: [
       Scaffold(
         backgroundColor: Colors.white,
         body: Center(
           child: SingleChildScrollView(
             child: Padding(
               padding: EdgeInsets.symmetric(horizontal: 24.0),
               child: Column(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   Text(
                     ' Clips&Styles',
                     style: TextStyle(
                       fontSize: 24,
                       fontWeight: FontWeight.bold,
                       color: Colors.black,
                       fontFamily: 'Kavoon',
                     ),
                   ),
                   SizedBox(height: 20),
                   Container(
                     decoration: BoxDecoration(
                       border: Border.all(color: Colors.black, width: 2),
                       borderRadius: BorderRadius.circular(10),
                     ),
                     child: Padding(
                       padding: EdgeInsets.all(16.0),
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.stretch,
                         children: [
                           Align(
                             alignment: Alignment.centerLeft,
                             child: Text(
                               'Log in or sign up',
                               style: TextStyle(
                                 fontSize: 18,
                                 fontWeight: FontWeight.bold,
                               ),
                             ),
                           ),
                           Align(
                             alignment: Alignment.centerLeft,
                             child: Text(
                               'Get started for free',
                               style: TextStyle(color: Colors.grey),
                             ),
                           ),
                           SizedBox(height: 20),
                           ElevatedButton(
                             onPressed: _signInWithGoogle,
                             style: ElevatedButton.styleFrom(
                               backgroundColor: Colors.white,
                               foregroundColor: Colors.black,
                               elevation: 0,
                               shape: RoundedRectangleBorder(
                                 borderRadius: BorderRadius.circular(10),
                                 side: BorderSide(color: Colors.black, width: 1.5),
                               ),
                               padding: EdgeInsets.symmetric(vertical: 12),
                             ),
                             child: Row(
                               mainAxisAlignment: MainAxisAlignment.center,
                               children: [
                                 SvgPicture.asset('assets/Google.svg', height: 24),
                                 SizedBox(width: 10),
                                 Text('Continue with Google'),
                               ],
                             ),
                           ),
                           SizedBox(height: 20),
                           Row(
                             children: [
                               Expanded(child: Divider()),
                               Padding(
                                 padding: EdgeInsets.symmetric(horizontal: 8),
                                 child: Text('Or with', style: TextStyle(color: Color(0xFF1d0301))),
                               ),
                               Expanded(child: Divider()),
                             ],
                           ),
                           SizedBox(height: 20),
                           TextField(
                             controller: _emailController,
                             decoration: InputDecoration(
                               labelText: 'Email',
                               border: OutlineInputBorder(
                                 borderRadius: BorderRadius.circular(14),
                               ),
                               enabledBorder: OutlineInputBorder(
                                 borderRadius: BorderRadius.circular(14),
                                 borderSide: BorderSide(color: Colors.black, width: 1),
                               ),
                               focusedBorder: OutlineInputBorder(
                                 borderRadius: BorderRadius.circular(14),
                                 borderSide: BorderSide(color: Colors.black, width: 2),
                               ),
                             ),
                           ),
                           SizedBox(height: 10),
                           TextField(
                             controller: _passwordController,
                             obscureText: _obscurePassword,
                             decoration: InputDecoration(
                               labelText: 'Password',
                               border: OutlineInputBorder(
                                 borderRadius: BorderRadius.circular(14),
                               ),
                               enabledBorder: OutlineInputBorder(
                                 borderRadius: BorderRadius.circular(14),
                                 borderSide: BorderSide(color: Colors.black, width: 1),
                               ),
                               focusedBorder: OutlineInputBorder(
                                 borderRadius: BorderRadius.circular(14),
                                 borderSide: BorderSide(color: Colors.black, width: 2),
                               ),
                               suffixIcon: IconButton(
                                 icon: Icon(
                                   _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                   color: Colors.grey,
                                 ),
                                 onPressed: () {
                                   setState(() {
                                     _obscurePassword = !_obscurePassword;
                                   });
                                 },
                               ),
                             ),
                           ),
                           SizedBox(height: 10),
                           Row(
                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
                             children: [
                               TextButton(
                                 child: Text('Forgot password?',
                                   style: TextStyle(fontSize: 10, color: Colors.black),
                                 ),
                                 onPressed: () {
                  
                                 },
                               ),
                               TextButton(
                                 child: Text("I don't have an account sign up",
                                   style: TextStyle(fontSize: 10, color: Colors.black),
                                 ),
                                 onPressed: () {
                          
                                 },
                               ),
                             ],
                           ),
                           SizedBox(height: 10),
                           ElevatedButton(
                             child: Text('Continue with Email',
                               style: TextStyle(fontSize: 17),
                             ),
                             onPressed: _signInWithEmail,
                             style: ElevatedButton.styleFrom(
                               backgroundColor: Color(0xFF23461a),
                               foregroundColor: Colors.white,
                               shape: RoundedRectangleBorder(
                                 borderRadius: BorderRadius.circular(10),
                               ),
                             ),
                           ),
                           SizedBox(height: 10),
                           Text(
                             'By clicking "Continue with Google / Email" you agree to our Terms of Service and Privacy Policy',
                             style: TextStyle(fontSize: 10, color: Colors.black),
                             textAlign: TextAlign.center,
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
       ),
       if (_isLoading)
         Container(
           color: Colors.black.withOpacity(0.5),
           child: Center(
             child: CircularProgressIndicator(
               valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF23461a)),
             ),
           ),
         ),
     ],
   );
 }

 @override
 void dispose() {
   _emailController.dispose();
   _passwordController.dispose();
   super.dispose();
 }
}