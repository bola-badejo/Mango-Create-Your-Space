
import 'package:flutter/material.dart';
import 'package:mango/Core/theme/mango_palette.dart';


class UploadProgressDialog extends StatefulWidget {
  final String fileType;
  final String fileName;
  final Future<String> Function(Function(double) onProgress) uploadFunction; 

  const UploadProgressDialog({
    Key? key,
    required this.fileType,
    required this.fileName,
    required this.uploadFunction,
  }) : super(key: key);

  @override
  _UploadProgressDialogState createState() => _UploadProgressDialogState();
}

class _UploadProgressDialogState extends State<UploadProgressDialog> {
  double _progress = 0.0;
  bool _isUploading = true;
  bool _isSuccess = false;
  String _errorMessage = '';
  String? _downloadUrl; 

  @override
  void initState() {
    super.initState();
    _startUpload();
  }

  Future<void> _startUpload() async {
    try {
      _downloadUrl = await widget.uploadFunction((progress) {
        if (mounted) {
          setState(() {
            _progress = progress;
          });
        }
      });
      
      if (mounted) {
        setState(() {
          _isUploading = false;
          _isSuccess = true;
        });
        
        
        await Future.delayed(Duration(milliseconds: 500));
        if (mounted) {
          Navigator.of(context).pop(_downloadUrl);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _isSuccess = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  String _getFileTypeIcon() {
    switch (widget.fileType) {
      case 'audio':
        return '🎤';
      case 'image':
        return '🖼️';
      case 'video':
        return '🎥';
      default:
        return '📎';
    }
  }

  Color _getProgressColor() {
    if (!_isUploading) {
      return _isSuccess ? MangoPalette.green500 : Colors.red;
    }
    return Colors.blue;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, 
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MangoRadius.lg)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              
              AnimatedContainer(
                duration: Duration(milliseconds: 300),
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: _getProgressColor().withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: _isUploading
                      ? Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(semanticsLabel: 'Loading', 
                              value: _progress,
                              valueColor: AlwaysStoppedAnimation(_getProgressColor()),
                              strokeWidth: 4,
                            ),
                            Text(
                              _getFileTypeIcon(),
                              style: TextStyle(fontSize: 24),
                            ),
                          ],
                        )
                      : Icon(
                          _isSuccess ? Icons.check_circle : Icons.error,
                          color: _getProgressColor(),
                          size: 40,
                        ),
                ),
              ),
              
              SizedBox(height: 20),
              
              
              Text(
                _isUploading 
                  ? 'Uploading ${widget.fileType}...'
                  : _isSuccess 
                    ? 'Upload Complete!'
                    : 'Upload Failed',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _getProgressColor(),
                ),
              ),
              
              SizedBox(height: 8),
              
              
              Text(
                widget.fileName,
                style: TextStyle(
                  fontSize: 14,
                  color: MangoPalette.grey600,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              
              SizedBox(height: 20),
              
              
              if (_isUploading) ...[
                LinearProgressIndicator(semanticsLabel: 'Loading', 
                  value: _progress,
                  backgroundColor: MangoPalette.grey200,
                  valueColor: AlwaysStoppedAnimation(_getProgressColor()),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(MangoRadius.xs),
                ),
                SizedBox(height: 8),
                Text(
                  '${(_progress * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: MangoPalette.grey600,
                  ),
                ),
              ],
              
              
              if (!_isUploading && !_isSuccess) ...[
                Text(
                  _errorMessage,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('Close'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}