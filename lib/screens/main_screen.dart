import 'package:flutter/material.dart';
import 'main_screen/main_screen.dart' as main_screen;

// This file is a redirect to maintain backward compatibility
class MainScreen extends StatelessWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const main_screen.MainScreen();
  }
}

