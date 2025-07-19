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

        setState(() {
          _currentFolder.imagePaths.add(newPath);
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

  Future<void> _sendPdfToOcr(String path) async {
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

        setState(() {
          _currentFolder.imagePaths.add(newPath);
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_currentFolder.name)),
      body: _currentFolder.imagePaths.isNotEmpty
          ? ListView.builder(
              itemCount: _currentFolder.imagePaths.length,
              itemBuilder: (context, index) {
                final path = _currentFolder.imagePaths[index];
                final isPdf = path.toLowerCase().endsWith('.pdf');

                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: InkWell(
                    onTap: () {
                      if (isPdf) {
                        OpenFile.open(path);
                      }
                    },
                    child: Stack(
                      children: [
                        if (isPdf)
                          Container(
                            padding: const EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
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
                                IconButton(
                                  icon: const Icon(Icons.send_to_mobile),
                                  onPressed: () => _sendPdfToOcr(path),
                                ),
                              ],
                            ),
                          )
                        else
                          Image.file(File(path)),
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
