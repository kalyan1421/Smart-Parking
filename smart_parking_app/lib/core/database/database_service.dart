
// lib/core/database/database_service.dart - Firebase connection service
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Notification imports removed for now
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../firebase_options.dart';

class DatabaseService {
  static FirebaseFirestore? _firestore;
  static FirebaseAuth? _auth;
  // Notification services removed for now
  // static FirebaseMessaging? _messaging;
  // static FlutterLocalNotificationsPlugin? _localNotifications;
  
  static Future<void> init() async {
    try {
      // Initialize Firebase
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      
      // Initialize Firestore
      _firestore = FirebaseFirestore.instance;
      
      // Initialize Auth
      _auth = FirebaseAuth.instance;
      
      // Notification initialization removed for now
      // _messaging = FirebaseMessaging.instance;
      // _localNotifications = FlutterLocalNotificationsPlugin();
      
      // Configure Firestore settings
      _firestore!.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      
      // Notification setup removed for now
      // await _initializeLocalNotifications();
      // await _setupFirebaseMessaging();
      
      print('Firebase services initialized successfully');
    } catch (e) {
      print('Failed to initialize Firebase services: $e');
      throw e;
    }
  }
  
  // Notification methods removed for now
  /*
  static Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    
    await _localNotifications!.initialize(initializationSettings);
  }
  
  static Future<void> _setupFirebaseMessaging() async {
    // Request permission for notifications
    NotificationSettings settings = await _messaging!.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission for notifications');
    } else {
      print('User declined or has not accepted permission for notifications');
    }
    
    // Handle background messages - removed for now
    // FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }
  
  static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    print('Handling a background message: ${message.messageId}');
  }
  */
  
  // Getters for Firebase services
  static FirebaseFirestore get firestore {
    if (_firestore == null) {
      throw Exception('Firestore not initialized. Call DatabaseService.init() first.');
    }
    return _firestore!;
  }
  
  static FirebaseAuth get auth {
    if (_auth == null) {
      throw Exception('Firebase Auth not initialized. Call DatabaseService.init() first.');
    }
    return _auth!;
  }
  
  // Notification getters removed for now
  /*
  static FirebaseMessaging get messaging {
    if (_messaging == null) {
      throw Exception('Firebase Messaging not initialized. Call DatabaseService.init() first.');
    }
    return _messaging!;
  }
  
  static FlutterLocalNotificationsPlugin get localNotifications {
    if (_localNotifications == null) {
      throw Exception('Local Notifications not initialized. Call DatabaseService.init() first.');
    }
    return _localNotifications!;
  }
  */
  
  // Helper methods for common Firestore operations
  static CollectionReference collection(String collectionName) {
    return firestore.collection(collectionName);
  }
  
  static DocumentReference doc(String path) {
    return firestore.doc(path);
  }
  
  static Future<T> runTransaction<T>(
    Future<T> Function(Transaction transaction) updateFunction,
  ) async {
    return await firestore.runTransaction<T>(updateFunction);
  }
  
  static WriteBatch batch() {
    return firestore.batch();
  }
}
