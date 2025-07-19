import 'dart:io';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/folder.dart';
import 'pdf_barcode_scanner_screen.dart';

class FolderScreen extends StatefulWidget {
  final Folder folder;
  final Function(Folder) onUpdate;

  const FolderScreen({super.key, required this.folder, required this.onUpdate});

  @override
  _FolderScreenState createState() => _FolderScreenState();
}

class _FolderScreenState extends State<FolderScreen> {
  late Folder _currentFolder;
  bool _isSelectionMode = false;
  final List<int> _selectedIndices = [];

  @override
  void initState() {
    super.initState();
    _currentFolder = widget.folder;
  }

  Future<void> _scanDocument() async {
    try {
      final List<String>? pictures = await CunningDocumentScanner.getPictures();
      if (pictures != null && pictures.isNotEmpty) {
        final appDir = await getApplicationDocumentsDirectory();
        final folderDir = Directory('${appDir.path}/${_currentFolder.id}');
        if (!await folderDir.exists()) {
          await folderDir.create(recursive: true);
        }

        final pdf = pw.Document();
        for (var picturePath in pictures) {
          final file = File(picturePath);
          final image = pw.MemoryImage(file.readAsBytesSync());
          pdf.addPage(
            pw.Page(
              margin: pw.EdgeInsets.zero,
              build: (pw.Context context) {
                return pw.Image(image, fit: pw.BoxFit.fill);
              },
            ),
          );
        }

        final fileName = Uuid().v4();
        final newPath = '${folderDir.path}/$fileName.pdf';
        final pdfFile = File(newPath);
        await pdfFile.writeAsBytes(await pdf.save());

        await _sendPdfToOcr(newPath);
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

  void _deleteSelectedImages() {
    _selectedIndices.sort((a, b) => b.compareTo(a));
    setState(() {
      for (var index in _selectedIndices) {
        _currentFolder.imagePaths.removeAt(index);
      }
      _isSelectionMode = false;
      _selectedIndices.clear();
    });
    widget.onUpdate(_currentFolder);
  }

  Future<void> _sendPdfToOcr(String path) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Dialog(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text("Processing..."),
              ],
            ),
          ),
        );
      },
    );

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://192.168.0.16:8000/process-pdf/'),
      );
      request.files.add(await http.MultipartFile.fromPath('file', path));
      var response = await request.send();

      if (response.statusCode == 200) {
        final appDir = await getApplicationDocumentsDirectory();
        final folderDir = Directory('${appDir.path}/${_currentFolder.id}');
        final fileName = path.split('/').last;
        final newPath = '${folderDir.path}/processed_$fileName';
        final file = File(newPath);
        await file.writeAsBytes(await response.stream.toBytes());

        final originalFile = File(path);
        if (await originalFile.exists()) {
          await originalFile.delete();
        }

        setState(() {
          final index = _currentFolder.imagePaths.indexOf(path);
          if (index != -1) {
            _currentFolder.imagePaths[index] = newPath;
          } else {
            _currentFolder.imagePaths.add(newPath);
          }
        });
        widget.onUpdate(_currentFolder);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File processed successfully!')),
        );
      } else {
        final responseBody = await response.stream.bytesToString();
        print('Error processing PDF: ${response.statusCode}');
        print('Response body: $responseBody');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error processing PDF: ${response.statusCode} ${response.reasonPhrase}',
            ),
          ),
        );
      }
    } catch (e) {
      print('Error sending PDF to OCR: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error sending PDF to OCR: $e')));
    } finally {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isSelectionMode
              ? '${_selectedIndices.length} selected'
              : _currentFolder.name,
        ),
        actions: _isSelectionMode
            ? [
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: _deleteSelectedImages,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _isSelectionMode = false;
                      _selectedIndices.clear();
                    });
                  },
                ),
              ]
            : [],
      ),
      body: _currentFolder.imagePaths.isNotEmpty
          ? ListView.builder(
              itemCount: _currentFolder.imagePaths.length,
              itemBuilder: (context, index) {
                final path = _currentFolder.imagePaths[index];
                final isPdf = path.toLowerCase().endsWith('.pdf');
                final isSelected = _selectedIndices.contains(index);

                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: GestureDetector(
                    onLongPress: () {
                      setState(() {
                        _isSelectionMode = true;
                        _selectedIndices.add(index);
                      });
                    },
                    onTap: () {
                      if (_isSelectionMode) {
                        setState(() {
                          if (isSelected) {
                            _selectedIndices.remove(index);
                            if (_selectedIndices.isEmpty) {
                              _isSelectionMode = false;
                            }
                          } else {
                            _selectedIndices.add(index);
                          }
                        });
                      } else {
                        if (isPdf) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  PdfBarcodeScannerScreen(pdfPath: path),
                            ),
                          );
                        }
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected ? Colors.blue : Colors.grey,
                        ),
                        borderRadius: BorderRadius.circular(8.0),
                        color: isSelected ? Colors.blue.withOpacity(0.3) : null,
                      ),
                      child: Stack(
                        children: [
                          if (isPdf)
                            Container(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.picture_as_pdf,
                                    size: 50,
                                    color: Colors.red,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      path.split('/').last,
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Image.file(File(path)),
                        ],
                      ),
                    ),
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
