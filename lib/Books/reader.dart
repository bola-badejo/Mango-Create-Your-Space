import 'package:flutter/material.dart';
import 'package:mango/Books/viewer_bse.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:mango/Models/customModel/library.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;

class PdfViewerScreen extends PdfViewerBase {
  const PdfViewerScreen({
    super.key,
    required super.fileUrl,
    required super.book,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  late Future<String> _pdfUrlFuture;
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _pdfUrlFuture = _getPdfUrl();
  }

  Future<String> _getPdfUrl() async {
    try {
      if (widget.fileUrl.startsWith('http')) {
        return widget.fileUrl;
      }
      final ref = firebase_storage.FirebaseStorage.instance.ref(widget.fileUrl);
      return await ref.getDownloadURL();
    } catch (e) {
      _errorMessage = 'Failed to load PDF: $e';
      throw Exception(_errorMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.book.title,
          style: const TextStyle(fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: FutureBuilder<String>(
        future: _pdfUrlFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 50, color: Colors.red),
                  const SizedBox(height: 20),
                  Text(
                    'Unable to open this book',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _errorMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _pdfUrlFuture = _getPdfUrl();
                      });
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return SfPdfViewer.network(
            snapshot.data!,
            canShowScrollHead: true,
            canShowScrollStatus: true,
            onDocumentLoadFailed: (details) {
              if (!mounted) return;
              setState(() {
                _errorMessage = details.error;
                _isLoading = false;
              });
            },
            onDocumentLoaded: (details) {
              if (!mounted) return;
              setState(() {
                _isLoading = false;
              });
            },
          );
        },
      ),
    );
  }
}