import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// SCREENS
import 'screens/landing.dart';
import 'screens/home.dart';
import 'screens/reports.dart';
import 'screens/complaints.dart';
import 'screens/map.dart';
import 'screens/TrackComplaints.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const PathaApp());
}

class PathaApp extends StatelessWidget {
  const PathaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PATHA',

      initialRoute: '/landing',

      routes: {
        '/landing': (context) => const LandingScreen(),
        '/home': (context) => const HomeScreen(),
        '/reports': (context) => const ReportsScreen(),
        '/complaints': (context) => const MyComplaints(),
        '/TrackComplaints': (context) => const TrackComplaints(),
        '/map': (context) => const MapScreen(),
      },
    );
  }
}