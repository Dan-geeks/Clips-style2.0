import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart'; // For SVG images like Google icon
import 'package:firebase_auth/firebase_auth.dart'; // For Firebase Authentication
import 'package:google_sign_in/google_sign_in.dart'; // For Google Sign-In specific flow
import 'package:cloud_firestore/cloud_firestore.dart'; // For Firestore database interaction
import 'package:hive_flutter/hive_flutter.dart'; // For local storage using Hive

// --- Import navigation destinations ---
// Ensure these paths match your project structure
import '../screens/business/Home/BusinessHomePage.dart'; // Business User's Home Page
import 'customer/HomePage/CustomerHomePage.dart'; // Customer's Home Page
import 'signup.dart'; // Sign Up Page (for unknown users or sign up navigation)

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Text Editing Controllers for email and password fields
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // State variables
  bool _obscurePassword = true; // To toggle password visibility
  bool _isLoading = false; // To show loading indicator during async operations

  // Firebase and Google Sign-In instances
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Checks the user type (business or client) in Firestore and navigates accordingly.
  /// Also saves the fetched user data to Hive.
  Future<void> checkUserTypeAndNavigate(User user) async {
    print("[LoginScreen] --- Starting checkUserTypeAndNavigate for user: ${user.uid} ---");
    try {
      // --- Ensure Hive Box is available ---
      if (!Hive.isBoxOpen('appBox')) {
        print("[LoginScreen] Hive box 'appBox' not open, attempting to open...");
        await Hive.openBox('appBox');
      }
      final Box appBox = Hive.box('appBox');
      print("[LoginScreen] Hive box 'appBox' is open.");
      // --- End Hive Box Check ---

      print("[LoginScreen] Querying 'businesses' collection for userId: ${user.uid}...");
      final businessQuery = await _firestore
          .collection('businesses')
          .where('userId', isEqualTo: user.uid)
          .limit(1)
          .get();
      print("[LoginScreen] Business query completed. Found ${businessQuery.docs.length} documents.");

      print("[LoginScreen] Querying 'clients' collection for userId: ${user.uid}...");
      final clientQuery = await _firestore
          .collection('clients')
          .where('userId', isEqualTo: user.uid)
          .limit(1)
          .get();
      print("[LoginScreen] Client query completed. Found ${clientQuery.docs.length} documents.");

      if (!mounted) { // Check if widget is still mounted before navigating
          print("[LoginScreen] Warning: Widget unmounted before proceeding.");
          return;
      }

      if (businessQuery.docs.isNotEmpty) {
        // --- BUSINESS USER FOUND ---
        final businessDoc = businessQuery.docs.first;
        final businessId = businessDoc.id; // Firestore Document ID
        final Map<String, dynamic> firestoreBusinessData = businessDoc.data();
        print("[LoginScreen] User identified as BUSINESS. Doc ID: $businessId");
        print("[LoginScreen] Firestore Data: ${firestoreBusinessData.toString().substring(0, (firestoreBusinessData.toString().length > 200 ? 200 : firestoreBusinessData.toString().length))}...");

        // --- Save data to Hive ---
        try {
          // Prepare data for Hive
          Map<String, dynamic> hiveDataToSave = Map<String, dynamic>.from(firestoreBusinessData);
          hiveDataToSave['userId'] = user.uid; // Auth UID
          hiveDataToSave['documentId'] = businessId; // Firestore Doc ID
          hiveDataToSave['loginMethod'] = user.providerData.isNotEmpty ? user.providerData[0].providerId : 'email';
          hiveDataToSave['isBusinessAccount'] = true;

          // Note: Ensure TimestampAdapter is registered in main.dart if storing Timestamps directly
          // Otherwise, convert them:
          // hiveDataToSave.updateAll((key, value) => value is Timestamp ? value.toDate().toIso8601String() : value);

          await appBox.put('businessData', hiveDataToSave); // Save the main map
          print("[LoginScreen] Saved fetched business data to Hive.");

          // Save individual keys if needed elsewhere
          await appBox.put('userId', user.uid);
          await appBox.put('userEmail', user.email);
          await appBox.put('displayName', user.displayName);
          await appBox.put('isBusinessAccount', true);
          await appBox.put('loginMethod', hiveDataToSave['loginMethod']);
          print("[LoginScreen] Saved individual keys to Hive for business.");

        } catch (hiveError) {
            print("[LoginScreen] Error saving business data to Hive: $hiveError");
            ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(content: Text('Error saving user session: $hiveError'), backgroundColor: Colors.orange),
             );
            // Decide whether to return or proceed with navigation
        }
        // --- End Save data to Hive ---

        print("[LoginScreen] Navigating to Business Home Page...");
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const BusinessHomePage())
        );

      } else if (clientQuery.docs.isNotEmpty) {
        // --- CLIENT USER FOUND ---
        final clientDoc = clientQuery.docs.first;
        final Map<String, dynamic> firestoreClientData = clientDoc.data();
        print("[LoginScreen] User identified as CLIENT. Doc ID: ${clientDoc.id}");
        print("[LoginScreen] Firestore Data: ${firestoreClientData.toString().substring(0, (firestoreClientData.toString().length > 200 ? 200 : firestoreClientData.toString().length))}...");

        // --- Save CLIENT data to Hive ---
         try {
            Map<String, dynamic> hiveDataToSave = Map<String, dynamic>.from(firestoreClientData);
            hiveDataToSave['userId'] = user.uid;
            hiveDataToSave['documentId'] = clientDoc.id;
            hiveDataToSave['isBusinessAccount'] = false; // Mark as client
            hiveDataToSave['loginMethod'] = user.providerData.isNotEmpty ? user.providerData[0].providerId : 'email';

            // Convert Timestamps if needed
            // hiveDataToSave.updateAll((key, value) => value is Timestamp ? value.toDate().toIso8601String() : value);

            await appBox.put('userData', hiveDataToSave); // Use 'userData' key for clients?
            print("[LoginScreen] Saved fetched client data to Hive.");

           // Save individual keys if needed
           await appBox.put('userId', user.uid);
           await appBox.put('userEmail', user.email);
           await appBox.put('displayName', user.displayName);
           await appBox.put('isBusinessAccount', false);
           await appBox.put('loginMethod', hiveDataToSave['loginMethod']);
           print("[LoginScreen] Saved individual keys to Hive for client.");

         } catch (hiveError) {
             print("[LoginScreen] Error saving client data to Hive: $hiveError");
             ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(content: Text('Error saving user session: $hiveError'), backgroundColor: Colors.orange),
             );
         }
        // --- End Save Client Data ---

        print("[LoginScreen] Navigating to Customer Home Page...");
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => CustomerHomePage()) // CustomerHomePage might be stateful
        );

      } else {
        // --- UNKNOWN USER TYPE ---
        print("[LoginScreen] User type UNKNOWN. No document found in 'businesses' or 'clients'.");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login successful, but user profile not found. Please complete setup.')),
        );
         print("[LoginScreen] Navigating to SignUp Page for unknown user...");
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => SignUpPage()) // Navigate back to sign up
        );
      }
      print("[LoginScreen] --- Finished checkUserTypeAndNavigate ---");
   } catch (e) {
     print('[LoginScreen] Error in checkUserTypeAndNavigate: $e');
     if(mounted){
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Error determining user type: ${e.toString()}')),
         );
     }
   }
 }

  /// Handles the Google Sign-In flow.
  /// Handles the Google Sign-In flow.
  Future<void> _signInWithGoogle() async {
    print("[LoginScreen] --- Starting _signInWithGoogle ---");
    setState(() => _isLoading = true);

    // --- MODIFICATION START: Clear previous session data ---
    try {
      print("[LoginScreen] Signing out previous Google user...");
      await _googleSignIn.signOut(); // Sign out from Google
      print("[LoginScreen] Signing out previous Firebase user...");
      await _auth.signOut();      // Sign out from Firebase

      // Clear relevant Hive data
      print("[LoginScreen] Clearing relevant Hive data...");
      final Box appBox = Hive.box('appBox');
      // List all keys you potentially save during login/signup
      final keysToClear = [
        'userId',
        'userEmail',
        'displayName',
        'isBusinessAccount',
        'loginMethod',
        'businessData',
        'userData',
        // Add any other keys related to user session
      ];
      for (var key in keysToClear) {
        if (await appBox.containsKey(key)) {
          await appBox.delete(key);
          print("[LoginScreen] Deleted '$key' from Hive.");
        }
      }
      print("[LoginScreen] Hive data cleared.");

    } catch (e) {
      print("[LoginScreen] Error during pre-sign-in cleanup: $e");
      // Optionally show a less critical error, but proceed with sign-in attempt
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Warning: Could not clear previous session fully.')),
      // );
    }
    // --- MODIFICATION END ---

    try {
      print("[LoginScreen] Attempting GoogleSignIn.signIn()...");
      // Now, signIn should prompt for account selection if multiple accounts exist
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        print("[LoginScreen] Google sign-in cancelled by user.");
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      print("[LoginScreen] Google user obtained: ${googleUser.email}");
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      print("[LoginScreen] Google auth tokens obtained.");
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      print("[LoginScreen] GoogleAuthProvider credential created.");
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      print("[LoginScreen] Firebase sign-in successful. User: ${userCredential.user?.uid}");
      if (userCredential.user != null) {
        print("[LoginScreen] User exists, calling checkUserTypeAndNavigate...");
        // checkUserTypeAndNavigate will save the NEW user's data to Hive
        await checkUserTypeAndNavigate(userCredential.user!);
      } else {
         print("[LoginScreen] Warning: Firebase sign-in successful but user object is null.");
      }
      print("[LoginScreen] --- Finished _signInWithGoogle successfully ---");
    } catch (e) {
      print("[LoginScreen] Error during _signInWithGoogle: $e");
      if(mounted){
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Google sign in failed: ${e.toString()}')),
          );
      }
    } finally {
      print("[LoginScreen] _signInWithGoogle finally block executing.");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Handles the Email/Password Sign-In flow.
  Future<void> _signInWithEmail() async {
     print("[LoginScreen] --- Starting _signInWithEmail ---");
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
       print("[LoginScreen] Email or password field is empty.");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter both email and password')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      print("[LoginScreen] Attempting Firebase signInWithEmailAndPassword for ${_emailController.text.trim()}...");
      final UserCredential userCredential =
          await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      print("[LoginScreen] Firebase email sign-in successful. User: ${userCredential.user?.uid}");

      if (userCredential.user != null) {
         print("[LoginScreen] User exists, calling checkUserTypeAndNavigate...");
        await checkUserTypeAndNavigate(userCredential.user!);
      } else {
        print("[LoginScreen] Warning: Firebase email sign-in successful but user object is null.");
      }
       print("[LoginScreen] --- Finished _signInWithEmail successfully ---");

    } on FirebaseAuthException catch (e) {
       print("[LoginScreen] FirebaseAuthException during email sign-in: ${e.code} - ${e.message}");
      String message = 'An error occurred';

      // Provide a user-friendly message for common errors
      if (e.code == 'user-not-found' || e.code == 'invalid-credential' || e.code == 'wrong-password') {
           message = 'Incorrect email or password.';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email format.';
      } else if (e.code == 'user-disabled') {
        message = 'This user account has been disabled.';
      } else if (e.code == 'too-many-requests') {
         message = 'Too many login attempts. Please try again later.';
      } else if (e.code == 'network-request-failed') {
         message = 'Network error. Please check your connection.';
      }
      // Add more specific error codes as needed

      if(mounted){ // Check mounted before showing SnackBar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
      }
    } catch (e) {
      print("[LoginScreen] Unexpected error during email sign-in: ${e.toString()}");
       if(mounted){ // Check mounted before showing SnackBar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Email sign in failed: ${e.toString()}')),
          );
       }
    } finally {
      print("[LoginScreen] _signInWithEmail finally block executing.");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    print("[LoginScreen] --- Building Widget Tree ---");
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
                              onPressed: _isLoading ? null : _signInWithGoogle,
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
                              enabled: !_isLoading,
                              keyboardType: TextInputType.emailAddress, // Keyboard type for email
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
                              enabled: !_isLoading,
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
                                  onPressed: _isLoading ? null : () {
                                     print("[LoginScreen] Forgot password tapped.");
                                     // TODO: Implement forgot password
                                  },
                                ),
                                TextButton(
                                  child: Text("I don't have an account sign up",
                                    style: TextStyle(fontSize: 10, color: Colors.black),
                                  ),
                                  onPressed: _isLoading ? null : () {
                                     print("[LoginScreen] Sign up tapped.");
                                     Navigator.push(
                                       context,
                                       MaterialPageRoute(builder: (context) => SignUpPage())
                                     );
                                  },
                                ),
                              ],
                            ),
                            SizedBox(height: 10),
                            ElevatedButton(
                              child: Text('Continue with Email',
                                style: TextStyle(fontSize: 17),
                              ),
                              onPressed: _isLoading ? null : _signInWithEmail,
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
     print("[LoginScreen] --- Disposing Widget ---");
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}