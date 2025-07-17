import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'screens/folder_list_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    _requestPermissions();
    return MaterialApp(
      title: 'Doc Scanner',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const FolderListScreen(),
    );
  }

  Future<void> _requestPermissions() async {
    await Permission.camera.request();
  }
}
