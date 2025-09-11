import 'package:firebase_core/firebase_core.dart';

/// Firebase configuration for different platforms
class FirebaseConfig {
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'your_android_api_key_here',
    appId: '1:your_sender_id:android:your_app_id_here',
    messagingSenderId: 'your_sender_id_here',
    projectId: 'instant-mentor-demo',
    storageBucket: 'instant-mentor-demo.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'your_ios_api_key_here',
    appId: '1:your_sender_id:ios:your_app_id_here',
    messagingSenderId: 'your_sender_id_here',
    projectId: 'instant-mentor-demo',
    storageBucket: 'instant-mentor-demo.appspot.com',
    iosBundleId: 'com.instantmentor.demo',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'your_web_api_key_here',
    appId: '1:your_sender_id:web:your_app_id_here',
    messagingSenderId: 'your_sender_id_here',
    projectId: 'instant-mentor-demo',
    authDomain: 'instant-mentor-demo.firebaseapp.com',
    storageBucket: 'instant-mentor-demo.appspot.com',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'your_windows_api_key_here',
    appId: '1:your_sender_id:windows:your_app_id_here',
    messagingSenderId: 'your_sender_id_here',
    projectId: 'instant-mentor-demo',
    authDomain: 'instant-mentor-demo.firebaseapp.com',
    storageBucket: 'instant-mentor-demo.appspot.com',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'your_macos_api_key_here',
    appId: '1:your_sender_id:macos:your_app_id_here',
    messagingSenderId: 'your_sender_id_here',
    projectId: 'instant-mentor-demo',
    storageBucket: 'instant-mentor-demo.appspot.com',
    iosBundleId: 'com.instantmentor.demo',
  );

  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'your_linux_api_key_here',
    appId: '1:your_sender_id:linux:your_app_id_here',
    messagingSenderId: 'your_sender_id_here',
    projectId: 'instant-mentor-demo',
    authDomain: 'instant-mentor-demo.firebaseapp.com',
    storageBucket: 'instant-mentor-demo.appspot.com',
  );
}
