import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/camera_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const FoodNutritionApp());
}

class FoodNutritionApp extends StatelessWidget {
  const FoodNutritionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '음식 영양소 분석',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.green,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
        ),
      ),
      home: const CameraScreen(),
    );
  }
}
