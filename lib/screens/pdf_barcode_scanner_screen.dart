import 'dart:io';

import 'package:flutter/material.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class PdfBarcodeScannerScreen extends StatefulWidget {
  final String pdfPath;
  const PdfBarcodeScannerScreen({super.key, required this.pdfPath});

  @override
  State<PdfBarcodeScannerScreen> createState() =>
      _PdfBarcodeScannerScreenState();
}

class _PdfBarcodeScannerScreenState extends State<PdfBarcodeScannerScreen> {
  String? barcodeValue;
  late MultiSplitViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = MultiSplitViewController(
      areas: [
        Area(builder: (context, area) => _buildBarcodeScanner()),
        Area(builder: (context, area) => _buildPdfViewer()),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PDF & Barcode Scanner')),
      body: MultiSplitView(axis: Axis.vertical, controller: _controller),
    );
  }

  Widget _buildBarcodeScanner() {
    return Column(
      children: [
        Expanded(
          child: MobileScanner(
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                setState(() {
                  barcodeValue = barcodes.first.rawValue;
                });
              }
            },
          ),
        ),
        if (barcodeValue != null)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text('Barcode: $barcodeValue'),
          ),
      ],
    );
  }

  Widget _buildPdfViewer() {
    return SfPdfViewer.file(File(widget.pdfPath));
  }
}
