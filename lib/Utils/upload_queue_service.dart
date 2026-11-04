import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';

enum UploadStatus { pending, uploading, completed, failed, paused }

class QueuedUpload {
  final String id;
  final String localPath;
  final String fileName;
  final String mimeType;
  final Map<String, dynamic> metadata;
  UploadStatus status;
  double progress;
  int retryCount;
  String? downloadUrl;
  String? errorMessage;

  QueuedUpload({
    required this.id,
    required this.localPath,
    required this.fileName,
    required this.mimeType,
    required this.metadata,
    this.status = UploadStatus.pending,
    this.progress = 0.0,
    this.retryCount = 0,
    this.downloadUrl,
    this.errorMessage,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'localPath': localPath,
    'fileName': fileName,
    'mimeType': mimeType,
    'metadata': metadata,
    'status': status.index,
    'progress': progress,
    'retryCount': retryCount,
    'downloadUrl': downloadUrl,
    'errorMessage': errorMessage,
  };

  factory QueuedUpload.fromJson(Map<String, dynamic> json) => QueuedUpload(
    id: json['id'],
    localPath: json['localPath'],
    fileName: json['fileName'],
    mimeType: json['mimeType'],
    metadata: json['metadata'],
    status: UploadStatus.values[json['status']],
    progress: json['progress'],
    retryCount: json['retryCount'],
    downloadUrl: json['downloadUrl'],
    errorMessage: json['errorMessage'],
  );
}

class UploadQueueService {
  static final UploadQueueService _instance = UploadQueueService._internal();
  factory UploadQueueService() => _instance;
  UploadQueueService._internal();

  final List<QueuedUpload> _queue = [];
  final List<QueuedUpload> _completed = [];
  bool _isProcessing = false;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  UploadTask? _currentTask;
  String? _currentUploadId;

  // Listeners
  final List<void Function(List<QueuedUpload>)> _queueListeners = [];
  final List<void Function(QueuedUpload)> _progressListeners = [];

  void addListener(void Function(List<QueuedUpload>) listener) => _queueListeners.add(listener);
  void removeListener(void Function(List<QueuedUpload>) listener) => _queueListeners.remove(listener);
  void addProgressListener(void Function(QueuedUpload) listener) => _progressListeners.add(listener);

  List<QueuedUpload> get pendingUploads => _queue.where((e) => e.status == UploadStatus.pending).toList();
  List<QueuedUpload> get failedUploads => _queue.where((e) => e.status == UploadStatus.failed).toList();

  Future<void> addToQueue({
    required String localPath,
    required String fileName,
    required String mimeType,
    required Map<String, dynamic> metadata,
  }) async {
    final upload = QueuedUpload(
      id: const Uuid().v4(),
      localPath: localPath,
      fileName: fileName,
      mimeType: mimeType,
      metadata: metadata,
    );
    _queue.add(upload);
    await _persistQueue();
    _notifyListeners();
    _processQueue();
  }

  Future<void> _processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;

    while (pendingUploads.isNotEmpty) {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity == ConnectivityResult.none) {
        _isProcessing = false;
        return;
      }

      final upload = pendingUploads.first;
      await _uploadFile(upload);
    }

    _isProcessing = false;
  }

  Future<void> _uploadFile(QueuedUpload upload) async {
    upload.status = UploadStatus.uploading;
    _currentUploadId = upload.id;
    _notifyListeners();
    await _persistQueue();

    try {
      final file = File(upload.localPath);
      if (!await file.exists()) {
        throw Exception('File not found: ${upload.localPath}');
      }

      final storageRef = _storage.ref().child(
        'audios/${upload.id}/${DateTime.now().millisecondsSinceEpoch}_${upload.fileName}'
      );

      final metadata = SettableMetadata(
        contentType: upload.mimeType,
        customMetadata: {
          'originalName': upload.fileName,
          'uploadId': upload.id,
          ...upload.metadata.map((k, v) => MapEntry(k, v.toString())),
        },
      );

      _currentTask = storageRef.putFile(file, metadata);

      _currentTask!.snapshotEvents.listen((snapshot) {
        upload.progress = snapshot.bytesTransferred / snapshot.totalBytes;
        for (var listener in _progressListeners) {
          listener(upload);
        }
        _persistQueue();
      });

      await _currentTask!;
      upload.downloadUrl = await storageRef.getDownloadURL();
      upload.status = UploadStatus.completed;
      
      // Clean up local file after successful upload
      await file.delete();
      
    } catch (e) {
      upload.status = UploadStatus.failed;
      upload.errorMessage = e.toString();
      upload.retryCount++;
      
      if (upload.retryCount < 3) {
        // Move back to pending for retry
        upload.status = UploadStatus.pending;
        Future.delayed(Duration(seconds: 5 * upload.retryCount), () => _processQueue());
      }
    } finally {
      _currentTask = null;
      _currentUploadId = null;
      _notifyListeners();
      await _persistQueue();
      
      if (upload.status == UploadStatus.completed) {
        _queue.remove(upload);
        _completed.add(upload);
        await _cleanOldCompleted();
      }
    }
  }

  Future<void> retryFailed(String id) async {
    final upload = _queue.firstWhere((e) => e.id == id);
    upload.status = UploadStatus.pending;
    upload.retryCount = 0;
    upload.errorMessage = null;
    await _persistQueue();
    _notifyListeners();
    _processQueue();
  }

  Future<void> cancelUpload(String id) async {
    if (_currentUploadId == id && _currentTask != null) {
      _currentTask!.cancel();
    }
    _queue.removeWhere((e) => e.id == id);
    await _persistQueue();
    _notifyListeners();
  }

  Future<void> _persistQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final queueJson = _queue.map((e) => e.toJson()).toList();
    await prefs.setString('upload_queue', jsonEncode(queueJson));
    
    final completedJson = _completed.map((e) => e.toJson()).toList();
    await prefs.setString('completed_uploads', jsonEncode(completedJson));
  }

  Future<void> loadPersistedQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final queueString = prefs.getString('upload_queue');
    if (queueString != null) {
      final List<dynamic> queueJson = jsonDecode(queueString);
      _queue.clear();
      _queue.addAll(queueJson.map((e) => QueuedUpload.fromJson(e)));
    }
    
    final completedString = prefs.getString('completed_uploads');
    if (completedString != null) {
      final List<dynamic> completedJson = jsonDecode(completedString);
      _completed.clear();
      _completed.addAll(completedJson.map((e) => QueuedUpload.fromJson(e)));
    }
    
    _notifyListeners();
    _processQueue();
  }

  Future<void> _cleanOldCompleted() async {
    // Keep only last 50 completed uploads
    while (_completed.length > 50) {
      _completed.removeAt(0);
    }
    await _persistQueue();
  }

  void _notifyListeners() {
    for (var listener in _queueListeners) {
      listener(List.from(_queue));
    }
  }
}