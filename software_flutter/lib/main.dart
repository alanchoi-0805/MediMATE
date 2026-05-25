import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/role_selection_screen.dart';
import 'screens/patient/home_screen.dart';
import 'screens/caregiver/home_screen.dart';
import 'providers/locale_provider.dart';

const String checkMissedDoseTask = "checkMissedDoseTask";

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await Firebase.initializeApp();
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return Future.value(true);

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('history')
          .where('isRead', isEqualTo: false)
          .where('status', isEqualTo: 'missed')
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        debugPrint("Background Task: New missed doses found.");
      }
    } catch (e) {
      debugPrint("Workmanager Task Error: $e");
    }
    return Future.value(true);
  });
}

const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'medication_channel',
  'Medication Alerts',
  description: 'This channel is used for medication reminders.',
  importance: Importance.low,
  playSound: false,
);

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await EasyLocalization.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (Platform.isAndroid) {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidImplementation?.requestNotificationsPermission();
  }

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: false,
    sslEnabled: true,
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/launcher_icon');

  await flutterLocalNotificationsPlugin.initialize(
    const InitializationSettings(android: initializationSettingsAndroid),
  );

  SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(statusBarColor: Colors.transparent));

  Workmanager().initialize(callbackDispatcher, isInDebugMode: false);

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ms'), Locale('zh')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      useOnlyLangCode: true,
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ],
        child: const MyApp(),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MediMATE',
      locale: context.locale,
      supportedLocales: context.supportedLocales,
      localizationsDelegates: context.localizationDelegates,
      theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFF472B6)),
          useMaterial3: true),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});
  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  StreamSubscription? _historySubscription;
  String? _currentUserId;

  @override
  void dispose() {
    _historySubscription?.cancel();
    super.dispose();
  }

  void _initializeUserData(String userId, BuildContext context) {
    if (_currentUserId == userId) return;
    _currentUserId = userId;

    _updateFcmToken(userId);
    _setupHistoryListener(userId);
    _syncUserLanguage(userId, context);

    Workmanager().registerPeriodicTask(
      "medimate_bg_check",
      checkMissedDoseTask,
      frequency: const Duration(minutes: 15),
      existingWorkPolicy: ExistingWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }

  Future<void> _syncUserLanguage(String userId, BuildContext context) async {
    try {
      var doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (doc.exists && doc.data() != null) {
        String? lang = doc.data()!['preferredLanguage'];
        if (lang == "中文") {
          context.setLocale(const Locale('zh'));
        } else if (lang == "Bahasa Melayu") {
          context.setLocale(const Locale('ms'));
        } else if (lang == "English") {
          context.setLocale(const Locale('en'));
        }
      }
    } catch (e) {
      debugPrint("Language Sync Error: $e");
    }
  }

  void _setupHistoryListener(String userId) {
    _historySubscription?.cancel();
    _historySubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('history')
        .where('isRead', isEqualTo: false)
        .where('status', isEqualTo: 'missed')
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          debugPrint("In-App Logic: New unread dose detected for red dot.");
        }
      }
    });
  }

  Future<void> _updateFcmToken(String userId) async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await FirebaseFirestore.instance.collection('users').doc(userId).set({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint("FCM Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(
                  child: CircularProgressIndicator(color: Color(0xFFEC4899))));
        }

        if (!snapshot.hasData) {
          _historySubscription?.cancel();
          _currentUserId = null;
          return const LoginScreen();
        }

        _initializeUserData(snapshot.data!.uid, context);

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(snapshot.data!.uid)
              .get(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                  body: Center(child: CircularProgressIndicator()));
            }
            if (userSnapshot.hasData && userSnapshot.data!.exists) {
              var userData = userSnapshot.data!.data() as Map<String, dynamic>;
              String role = userData['role'] ?? "";
              if (role == "Patient") return const PatientHomeScreen();
              if (role == "Caregiver") return const CaregiverHomeScreen();
            }
            return const RoleSelectionScreen();
          },
        );
      },
    );
  }
}
