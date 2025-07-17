import 'dart:io';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tesseract_ocr/tesseract_ocr.dart';
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
  bool _isPerformingOcr = false;

  @override
  void initState() {
    super.initState();
    _currentFolder = widget.folder;
  }

  Future<void> _performOcr() async {
    if (_currentFolder.imagePaths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No images to perform OCR on.')),
      );
      return;
    }

    setState(() {
      _isPerformingOcr = true;
    });

    try {
      String allExtractedText = '';
      for (var imagePath in _currentFolder.imagePaths) {
        final extractedText = await TesseractOcr.extractText(imagePath);
        allExtractedText += extractedText + '\n\n';
      }
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Extracted Text'),
          content: SingleChildScrollView(child: Text(allExtractedText)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      print('Error performing OCR: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error performing OCR: $e')));
    } finally {
      setState(() {
        _isPerformingOcr = false;
      });
    }
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
      body: _isPerformingOcr
          ? const Center(child: CircularProgressIndicator())
          : _currentFolder.imagePaths.isNotEmpty
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
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "scanButton",
            onPressed: _scanDocument,
            tooltip: 'Scan Document',
            child: const Icon(Icons.camera_alt),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: "ocrButton",
            onPressed: _performOcr,
            tooltip: 'Perform OCR',
            child: const Icon(Icons.text_fields),
          ),
        ],
      ),
    );
  }
}
