
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] .

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBFoaY-2sZXF9JDEChLftl8iTCUeq6cRKM',
    appId: '1:337048471338:web:173bb139f96ba4b5130053',
    messagingSenderId: '337048471338',
    projectId: 'lotus-76761',
    authDomain: 'lotus-76761.firebaseapp.com',
    storageBucket: 'lotus-76761.appspot.com',
    measurementId: 'G-8QC7L4YDRE',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDuzLEjql52xsvBLAzHVoQV8h1pYFwRhZ8',
    appId: '1:337048471338:android:b653de1e4aa22db5130053',
    messagingSenderId: '337048471338',
    projectId: 'lotus-76761',
    storageBucket: 'lotus-76761.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBP_mT6bk8ADqC2GUw8BS6Fu2bTRXj7Cu0',
    appId: '1:337048471338:ios:44c8889588d040ab130053',
    messagingSenderId: '337048471338',
    projectId: 'lotus-76761',
    storageBucket: 'lotus-76761.appspot.com',
    androidClientId: '337048471338-0t8lao0jgniq6k9nrjqa268iis3u04fs.apps.googleusercontent.com',
    iosClientId: '337048471338-dcittpv3bvpb7hnnqpdgif04r5l4jif8.apps.googleusercontent.com',
    iosBundleId: 'com.example.clipsandstyles2',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBP_mT6bk8ADqC2GUw8BS6Fu2bTRXj7Cu0',
    appId: '1:337048471338:ios:44c8889588d040ab130053',
    messagingSenderId: '337048471338',
    projectId: 'lotus-76761',
    storageBucket: 'lotus-76761.appspot.com',
    androidClientId: '337048471338-0t8lao0jgniq6k9nrjqa268iis3u04fs.apps.googleusercontent.com',
    iosClientId: '337048471338-dcittpv3bvpb7hnnqpdgif04r5l4jif8.apps.googleusercontent.com',
    iosBundleId: 'com.example.clipsandstyles2',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDNmRPjKHA461S9xs0ayTjwdqYA9ynmOo0',
    appId: '1:337048471338:web:a37c0dd595d8883f130053',
    messagingSenderId: '337048471338',
    projectId: 'lotus-76761',
    authDomain: 'lotus-76761.firebaseapp.com',
    storageBucket: 'lotus-76761.appspot.com',
    measurementId: 'G-T1F7ZGTCGJ',
  );

}