import 'dart:io';

import 'package:flutter/material.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

enum BarcodeStatus { none, found, notFound }

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
  final MobileScannerController _scannerController = MobileScannerController();
  final PdfViewerController _pdfViewerController = PdfViewerController();
  bool _isFlashOn = false;
  BarcodeStatus _barcodeStatus = BarcodeStatus.none;

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
      body: MultiSplitViewTheme(
        data: MultiSplitViewThemeData(dividerThickness: 25),
        child: MultiSplitView(
          axis: Axis.vertical,
          controller: _controller,
          dividerBuilder:
              (axis, index, resizable, dragging, highlighted, themeData) {
                return Container(
                  color: dragging
                      ? Theme.of(context).scaffoldBackgroundColor
                      : Theme.of(context).scaffoldBackgroundColor,
                  child: Icon(
                    Icons.drag_indicator,
                    color: highlighted ? Colors.grey : Colors.grey,
                    size: 20,
                  ),
                );
              },
        ),
      ),
    );
  }

  Future<void> _toggleFlash() async {
    _scannerController.toggleTorch();
    setState(() {
      _isFlashOn = !_isFlashOn;
    });
  }

  Widget _buildBarcodeScanner() {
    return Column(
      children: [
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              MobileScanner(
                controller: _scannerController,
                onDetect: (capture) {
                  final List<Barcode> barcodes = capture.barcodes;
                  final RegExp barcodePattern = RegExp(r'^58\d{7}$');

                  if (barcodes.isNotEmpty) {
                    final String? scannedBarcode = barcodes.first.rawValue;
                    if (scannedBarcode != null &&
                        barcodePattern.hasMatch(scannedBarcode)) {
                      // Barcode is valid and matches pattern
                      if (barcodeValue != scannedBarcode) {
                        setState(() {
                          barcodeValue = scannedBarcode;
                        });
                        _searchInPdf(scannedBarcode);
                      }
                    } else {
                      // Barcode is present, but doesn't match pattern
                      if (_barcodeStatus != BarcodeStatus.none) {
                        setState(() {
                          _barcodeStatus = BarcodeStatus.none;
                        });
                      }
                    }
                  } else {
                    // No barcodes detected
                    if (_barcodeStatus != BarcodeStatus.none) {
                      setState(() {
                        _barcodeStatus = BarcodeStatus.none;
                      });
                    }
                  }
                },
              ),
              Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(color: _getBorderColor(), width: 2),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: IconButton(
                  color: Colors.white,
                  icon: Icon(
                    _isFlashOn ? Icons.flash_on : Icons.flash_off,
                    color: _isFlashOn ? Colors.yellow : Colors.grey,
                  ),
                  iconSize: 32.0,
                  onPressed: _toggleFlash,
                ),
              ),
            ],
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

  void _searchInPdf(String barcode) {
    final searchResult = _pdfViewerController.searchText(barcode);
    searchResult.addListener(() {
      if (searchResult.isSearchCompleted) {
        setState(() {
          if (searchResult.hasResult) {
            _barcodeStatus = BarcodeStatus.found;
          } else {
            _barcodeStatus = BarcodeStatus.notFound;
          }
        });
        searchResult.removeListener(() {});
      }
    });
  }

  Color _getBorderColor() {
    switch (_barcodeStatus) {
      case BarcodeStatus.found:
        return Colors.green;
      case BarcodeStatus.notFound:
        return Colors.red;
      case BarcodeStatus.none:
      default:
        return Colors.white;
    }
  }

  Widget _buildPdfViewer() {
    return SfPdfViewer.file(
      File(widget.pdfPath),
      controller: _pdfViewerController,
    );
  }
}
