import 'dart:io';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/folder.dart';

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
          ? ListView.builder(
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
