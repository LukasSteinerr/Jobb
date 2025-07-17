import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

void main() {
  runApp(const MyApp());
}

class Folder {
  String id;
  String name;
  List<String> imagePaths;

  Folder({required this.id, required this.name, this.imagePaths = const []});

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'imagePaths': imagePaths};
  }

  factory Folder.fromMap(Map<String, dynamic> map) {
    return Folder(
      id: map['id'],
      name: map['name'],
      imagePaths: List<String>.from(map['imagePaths']),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Doc Scanner',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const FolderListScreen(),
    );
  }
}

class FolderListScreen extends StatefulWidget {
  const FolderListScreen({super.key});

  @override
  _FolderListScreenState createState() => _FolderListScreenState();
}

class _FolderListScreenState extends State<FolderListScreen> {
  List<Folder> _folders = [];
  final _folderNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _loadFolders();
  }

  Future<void> _requestPermissions() async {
    await Permission.camera.request();
  }

  Future<void> _loadFolders() async {
    final prefs = await SharedPreferences.getInstance();
    final folderListJson = prefs.getStringList('folders') ?? [];
    setState(() {
      _folders = folderListJson
          .map((json) => Folder.fromMap(jsonDecode(json)))
          .toList();
    });
  }

  Future<void> _saveFolders() async {
    final prefs = await SharedPreferences.getInstance();
    final folderListJson = _folders
        .map((folder) => jsonEncode(folder.toMap()))
        .toList();
    await prefs.setStringList('folders', folderListJson);
  }

  void _addFolder() {
    if (_folderNameController.text.isNotEmpty) {
      final newFolder = Folder(
        id: Uuid().v4(),
        name: _folderNameController.text,
        imagePaths: [],
      );
      setState(() {
        _folders.add(newFolder);
      });
      _saveFolders();
      _folderNameController.clear();
      Navigator.of(context).pop();
    }
  }

  void _showAddFolderDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('New Folder'),
          content: TextField(
            controller: _folderNameController,
            decoration: const InputDecoration(hintText: "Folder Name"),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(child: const Text('Create'), onPressed: _addFolder),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Folders')),
      body: ListView.builder(
        itemCount: _folders.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(_folders[index].name),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => FolderScreen(
                    folder: _folders[index],
                    onUpdate: (updatedFolder) {
                      setState(() {
                        _folders[index] = updatedFolder;
                      });
                      _saveFolders();
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddFolderDialog,
        child: const Icon(Icons.create_new_folder),
      ),
    );
  }
}

class FolderScreen extends StatefulWidget {
  final Folder folder;
  final Function(Folder) onUpdate;

  const FolderScreen({super.key, required this.folder, required this.onUpdate});

  @override
  _FolderScreenState createState() => _FolderScreenState();
}

class _FolderScreenState extends State<FolderScreen> {
  late Folder _currentFolder;

  @override
  void initState() {
    super.initState();
    _currentFolder = widget.folder;
  }

  Future<void> _scanDocument() async {
    try {
      final List<String>? pictures = await CunningDocumentScanner.getPictures();
      if (pictures != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final folderDir = Directory('${appDir.path}/${_currentFolder.id}');
        if (!await folderDir.exists()) {
          await folderDir.create(recursive: true);
        }

        List<String> newImagePaths = [];
        for (var picturePath in pictures) {
          final file = File(picturePath);
          final fileName = Uuid().v4();
          final newPath = '${folderDir.path}/$fileName.jpg';
          await file.copy(newPath);
          newImagePaths.add(newPath);
        }

        setState(() {
          _currentFolder.imagePaths.addAll(newImagePaths);
        });
        widget.onUpdate(_currentFolder);
      }
    } catch (e) {
      print('Error scanning document: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error scanning document: $e')));
    }
  }

  void _deleteImage(int index) {
    setState(() {
      _currentFolder.imagePaths.removeAt(index);
    });
    widget.onUpdate(_currentFolder);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_currentFolder.name)),
      body: _currentFolder.imagePaths.isNotEmpty
          ? GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
              ),
              itemCount: _currentFolder.imagePaths.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Stack(
                    children: [
                      Image.file(File(_currentFolder.imagePaths[index])),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteImage(index),
                        ),
                      ),
                    ],
                  ),
                );
              },
            )
          : const Center(child: Text('No documents scanned yet.')),
      floatingActionButton: FloatingActionButton(
        onPressed: _scanDocument,
        tooltip: 'Scan Document',
        child: const Icon(Icons.camera_alt),
      ),
    );
  }
}
