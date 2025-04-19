import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ChangeEmailScreen extends StatefulWidget {
  const ChangeEmailScreen({super.key});
  
  static Route route() {
    return MaterialPageRoute(builder: (_) => const ChangeEmailScreen());
  }

  @override
  _ChangeEmailScreenState createState() => _ChangeEmailScreenState();
}

class _ChangeEmailScreenState extends State<ChangeEmailScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Box _appBox = Hive.box('appBox');
  final TextEditingController _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool isLoading = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCurrentEmail();
  }
  
  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  // Load current email
  Future<void> _loadCurrentEmail() async {
    User? user = _auth.currentUser;
    if (user != null && user.email != null) {
      setState(() {
        _emailController.text = user.email!;
      });
    }
  }

  // Email validation
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    
    // Simple email validation regex
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    
    // Check if it's the same as current email
    User? user = _auth.currentUser;
    if (user != null && user.email == value) {
      return 'New email must be different from current email';
    }
    
    return null;
  }



  // Change email
  Future<void> _changeEmail() async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    
    try {
      User? user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user is currently signed in');
      }
      
      // Get current user email
      String currentEmail = user.email ?? '';
      if (currentEmail.isEmpty) {
        throw Exception('Current user does not have an email');
      }
      
      // Change email - no password verification
      try {
        await user.updateEmail(_emailController.text.trim());
      } catch (e) {
        if (e is FirebaseAuthException && e.code == 'requires-recent-login') {
          // Handle the case where recent authentication is required
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please sign out and sign in again before changing your email')),
          );
          setState(() {
            isLoading = false;
            errorMessage = 'Please sign out and sign in again before changing your email';
          });
          return;
        } else {
          rethrow; // Rethrow other errors to be caught by the outer catch block
        }
      }
      
      // Update email in Firestore if needed
      await _firestore
          .collection('clients')
          .doc(user.uid)
          .update({'email': _emailController.text.trim()});
      
      // Update Hive cache
      Map<String, dynamic>? userData = _appBox.get('userData');
      if (userData != null) {
        userData['email'] = _emailController.text.trim();
        await _appBox.put('userData', userData);
      }
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email updated successfully')),
      );
      
      // Navigate back
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      setState(() {
        isLoading = false;
        
        // Handle specific Firebase Auth errors
        switch (e.code) {
          case 'requires-recent-login':
            errorMessage = 'Please sign out and sign in again before changing your email';
            break;
          case 'invalid-email':
            errorMessage = 'The email address is not valid';
            break;
          case 'email-already-in-use':
            errorMessage = 'The email address is already in use by another account';
            break;
          default:
            errorMessage = 'Error: ${e.message}';
        }
      });
      
      print('Firebase Auth error changing email: ${e.code} - ${e.message}');
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Error: $e';
      });
      
      print('Error changing email: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "Change Email",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Instructions
              const Text(
                "Enter Your new email address below.",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              
              // Email input field
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: const BorderSide(color: Colors.grey),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 14.0,
                  ),
                ),
                validator: _validateEmail,
                enabled: !isLoading,
              ),
              
              // Error message if any
              if (errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Text(
                    errorMessage!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 14,
                    ),
                  ),
                ),
              
              const SizedBox(height: 20),
              
              // Request Change button
              ElevatedButton(
                onPressed: isLoading ? null : _changeEmail,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B5E20), // Dark green color
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  elevation: 0,
                ),
                child: isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.0,
                      ),
                    )
                  : const Text(
                      "Request Change",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
              ),
              
              const SizedBox(height: 12),
              
              // Cancel button
              TextButton(
                onPressed: isLoading 
                  ? null 
                  : () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                child: const Text(
                  "Cancel",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
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