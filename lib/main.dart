
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:pegas_cashcollector/firebase_options.dart';
import 'package:pegas_cashcollector/screens/codeEntryScreen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
);
  print('✅ firebase cashcollector initialized');
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cash Collector 02',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      home: AccessCodeEntryScreen(),
    );
  }
}
