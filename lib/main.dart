import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'screens/customer/CustomerService/notification_hub.dart';
import 'screens/signup.dart';
import 'screens/login.dart';
import 'firebase_options.dart';

// Create a Hive TypeAdapter for Firebase Timestamp
class TimestampAdapter extends TypeAdapter<Timestamp> {
  @override
  final int typeId = 42; // Unique typeId for Timestamp

  @override
  Timestamp read(BinaryReader reader) {
    final seconds = reader.readInt();
    final nanoseconds = reader.readInt();
    return Timestamp(seconds, nanoseconds);
  }

  @override
  void write(BinaryWriter writer, Timestamp obj) {
    writer.writeInt(obj.seconds);
    writer.writeInt(obj.nanoseconds);
  }
}

Future<void> main() async {
  // Preserve splash screen until Flutter is ready
  final binding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: binding);

  // Simple logger for init steps
  void log(String message) => debugPrint('[INIT] $message');

  // Load environment variables
  try {
    await dotenv.load(fileName: '.env');
    log('Loaded .env');
  } catch (e, st) {
    log('Failed to load .env: $e');
    log(st.toString());
  }

  // Initialize Hive
  try {
    await Hive.initFlutter();
    log('Hive initialized');
    Hive.registerAdapter(TimestampAdapter());
    log('TimestampAdapter registered');
  } catch (e, st) {
    log('Hive init failed: $e');
    log(st.toString());
  }

  
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      log('Firebase initialized');
    } else {
      log('Firebase already initialized');
    }
  } catch (e, st) {
    log('Firebase init failed: $e');
    log(st.toString());
  }


  try {
    await Hive.openBox('appBox');
    log('Opened Hive box: appBox');
  } catch (e, st) {
    log('Failed to open Hive box: $e');
    log(st.toString());
  }


  WidgetsBinding.instance.addPostFrameCallback((_) async {
    try {
      await NotificationHub.instance.initialize();
      log('NotificationHub initialized');
    } catch (e, st) {
      log('NotificationHub init failed: $e');
      log(st.toString());
    }
  });

  
  runApp(const MyApp());
  FlutterNativeSplash.remove();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Clips&Styles',
      theme: ThemeData(
        primaryColor: const Color(0xFF23461a),
        colorScheme: ColorScheme.light(
          primary: const Color(0xFF23461a),
          secondary: Colors.green,
        ),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<String> _titles = ['Discover', 'The Best Beauty Shop', 'Near You'];
  final List<String> _imagePaths = [
    'assets/Frame4.png',
    'assets/Frame5.png',
    'assets/Frame6.png'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemCount: _titles.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(),
                      const Text(
                        'Clips&Styles',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Kavoon',
                        ),
                      ),
                      const SizedBox(height: 20),
                      Image.asset(
                        _imagePaths[index],
                        height: 200,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _titles[index],
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                );
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _titles.length,
              (dotIndex) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 12.0,
                  height: 12.0,
                  decoration: BoxDecoration(
                    color: _currentPage == dotIndex
                        ? const Color(0xFF1d0301)
                        : const Color(0xFF8e8180),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Column(
              children: [
                ElevatedButton(
                  onPressed: () {
                    if (_currentPage < _titles.length - 1) {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => SignUpPage()),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF23461A),
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: Text(
                    _currentPage == _titles.length - 1 ? 'Get Started' : 'Continue',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LoginScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1d0301),
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text(
                    'Sign in',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 70),
        ],
      ),
    );
  }
}
