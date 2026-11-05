import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart'; 
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mango/utils.dart';
import 'package:uuid/uuid.dart';
import 'package:mango/Core/theme/mango_palette.dart';

class BookItem {
  String id;
  String title;
  String filePath;
  String downloadUrl;
  RxList<Map<String, String>> contributors;
  
  
  Uint8List? webBytes;
  String? webFileName;

  BookItem({
    required this.id,
    required this.title,
    required this.filePath,
    this.downloadUrl = '',
    List<Map<String, String>>? contributors,
    this.webBytes,
    this.webFileName,
  }) : contributors = (contributors ?? []).obs;
}




class UploadBookCollectionController extends GetxController {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  
  var collectionTitle = ''.obs;
  var author = ''.obs;
  var selectedGenre = ''.obs;
  var language = ''.obs;
  var releaseDate = DateTime.now().obs;

  
  var contributors = <String>[].obs;
  var newContributor = ''.obs;

  
  var coverImage = Rxn<XFile>();
  var coverDownloadUrl = ''.obs;
  
  
  Uint8List? webCoverBytes;
  String? webCoverFileName;

  
  var books = <BookItem>[].obs;
  var newBookTitle = ''.obs;
  var newBookFilePath = ''.obs;
  
  
  Uint8List? newBookWebBytes;
  String? newBookWebFileName;

  
  var isUploading = false.obs;
  var uploadProgress = 0.0.obs;

  
  final List<String> genres = [
    'Fiction','Non-fiction','Science','Philosophy','Biography',
    'Fantasy','Romance','Thriller','Mystery','Self-Help','History',
    'Children','Religion','Poetry','Comics','Other',
  ];

  
  final List<String> languages = [
    'English','French','Spanish','German','Chinese','Japanese',
    'Yoruba','Igbo','Hausa','Other'
  ];

  Future<void> pickCoverImage(context) async {
    try {
      if (kIsWeb) {
        
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
        );
        
        if (result != null && result.files.isNotEmpty) {
          webCoverBytes = result.files.first.bytes;
          webCoverFileName = result.files.first.name;
          coverImage.value = XFile.fromData(webCoverBytes!, name: webCoverFileName);
        }
      } else {
        
        final picked = await _picker.pickImage(source: ImageSource.gallery);
        if (picked != null) coverImage.value = picked;
      }
    } catch (e) {
      UtilsService().showSnackbar('Error', e.toString(), context: context);
    }
  }

  Future<void> pickBookFile(context) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'epub', 'docx'],
        allowMultiple: false,
      );
      
      if (result != null && result.files.isNotEmpty) {
        if (kIsWeb) {
          
          newBookWebBytes = result.files.first.bytes;
          newBookWebFileName = result.files.first.name;
          newBookFilePath.value = result.files.first.name; 
        } else {
          
          if (result.files.first.path != null) {
            newBookFilePath.value = result.files.first.path!;
          }
        }
      }
    } catch (e) {
      UtilsService().showSnackbar('Error', e.toString(), context: context);
    }
  }

  void addContributor() {
    if (newContributor.value.trim().isNotEmpty) {
      contributors.add(newContributor.value.trim());
      newContributor.value = '';
    }
  }

  void addBook(context) {
    if (newBookTitle.value.trim().isEmpty || 
        (kIsWeb ? newBookWebBytes == null : newBookFilePath.value.isEmpty)) {
      UtilsService().showSnackbar('Invalid', 'Book title and file required', context: context);
      return;
    }
    
    books.add(
      BookItem(
        id: Uuid().v4(),
        title: newBookTitle.value.trim(),
        filePath: kIsWeb ? '' : newBookFilePath.value,
        webBytes: kIsWeb ? newBookWebBytes : null,
        webFileName: kIsWeb ? newBookWebFileName : null,
      ),
    );
    newBookTitle.value = '';
    newBookFilePath.value = '';
    newBookWebBytes = null;
    newBookWebFileName = null;
  }

  void removeBook(int index) {
    if (index >= 0 && index < books.length) {
      books.removeAt(index);
    }
  }

  Future<String> _uploadFile(String path, Uint8List? bytes, String folder, String? fileName) async {
    final ref = _storage.ref().child('$folder/${Uuid().v4()}');
    
    if (kIsWeb && bytes != null) {
      
      final uploadTask = ref.putData(
        bytes,
        SettableMetadata(contentType: _getContentType(fileName ?? '')),
      );

      uploadTask.snapshotEvents.listen((snapshot) {
        if (snapshot.totalBytes > 0) {
          uploadProgress.value =
              snapshot.bytesTransferred / snapshot.totalBytes;
        }
      });

      await uploadTask;
    } else {
      
      final uploadTask = ref.putFile(File(path));

      uploadTask.snapshotEvents.listen((snapshot) {
        if (snapshot.totalBytes > 0) {
          uploadProgress.value =
              snapshot.bytesTransferred / snapshot.totalBytes;
        }
      });

      await uploadTask;
    }
    
    return await ref.getDownloadURL();
  }

  String _getContentType(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    switch (ext) {
      case 'pdf': return 'application/pdf';
      case 'epub': return 'application/epub+zip';
      case 'docx': return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'jpg':
      case 'jpeg': return 'image/jpeg';
      case 'png': return 'image/png';
      default: return 'application/octet-stream';
    }
  }

  Future<void> uploadCollection(context) async {
    if (collectionTitle.value.isEmpty ||
        author.value.isEmpty ||
        selectedGenre.value.isEmpty ||
        language.value.isEmpty ||
        (coverImage.value == null && webCoverBytes == null) ||
        books.isEmpty) {
      UtilsService().showSnackbar('Missing Info', 'Collection info, cover, and at least 1 book required', context: context);
      return;
    }

    isUploading.value = true;
    try {
      
      coverDownloadUrl.value =
          await _uploadFile(
            coverImage.value?.path ?? '',
            webCoverBytes,
            'book_covers',
            webCoverFileName,
          );

      
      List<Map<String, dynamic>> uploadedBooks = [];
      for (int i = 0; i < books.length; i++) {
        final b = books[i];
        final url = await _uploadFile(
          b.filePath,
          b.webBytes,
          'book_files',
          b.webFileName,
        );
        uploadedBooks.add({
          'title': b.title,
          'order': i,
          'fileUrl': url,
          'contributors': b.contributors.toList(),
        });
      }

      
      await _firestore.collection('book_collections').add({
        'title': collectionTitle.value,
        'author': author.value,
        'genre': selectedGenre.value,
        'language': language.value,
        'releaseDate': releaseDate.value,
        'contributors': contributors.toList(),
        'coverUrl': coverDownloadUrl.value,
        'books': uploadedBooks,
        'timestamp': FieldValue.serverTimestamp(),
      });

      UtilsService().showSnackbar('Success', 'Book collection uploaded successfully',
          backgroundColor: MangoPalette.green500, colorText: Colors.white, context: context);

      _clearAll();
    } catch (e) {
      UtilsService().showSnackbar('Upload Error', e.toString(),
          backgroundColor: Colors.red, colorText: Colors.white, context: context);
    } finally {
      isUploading.value = false;
      uploadProgress.value = 0.0;
    }
  }

  void _clearAll() {
    collectionTitle.value = '';
    author.value = '';
    selectedGenre.value = '';
    language.value = '';
    releaseDate.value = DateTime.now();
    contributors.clear();
    coverImage.value = null;
    webCoverBytes = null;
    webCoverFileName = null;
    coverDownloadUrl.value = '';
    books.clear();
    newBookWebBytes = null;
    newBookWebFileName = null;
  }
}




class UploadBookCollectionPage extends StatefulWidget {
  final String? contributorId;
  const UploadBookCollectionPage({super.key, this.contributorId});

  @override
  State<UploadBookCollectionPage> createState() =>
      _UploadBookCollectionPageState();
}

class _UploadBookCollectionPageState extends State<UploadBookCollectionPage> {
  final UploadBookCollectionController c =
      Get.put(UploadBookCollectionController());

  int _currentStep = 0;

  void _onStepContinue() {
    if (_currentStep < 3) {
      setState(() => _currentStep++);
    } else {
      c.uploadCollection(context);
    }
  }

  void _onStepCancel() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        bool discard = await showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text("Discard upload?"),
                content: const Text("Do you want to discard this collection?"),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text("Stay")),
                  TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text("Discard")),
                ],
              ),
            ) ??
            false;
        return discard;
      },
      child: Scaffold(
        appBar: AppBar(title: const Text("Upload Book Collection")),
        body: Obx(
          () => Stepper(
            type: StepperType.vertical,
            currentStep: _currentStep,
            onStepContinue: _onStepContinue,
            onStepCancel: _onStepCancel,
            controlsBuilder: (context, details) {
              final isLast = _currentStep == 3;
              return Row(
                children: [
                  ElevatedButton(
                    onPressed: details.onStepContinue,
                    child: Text(isLast ? "Upload" : "Next"),
                  ),
                  const SizedBox(width: 10),
                  if (_currentStep > 0)
                    TextButton(
                      onPressed: details.onStepCancel,
                      child: const Text("Back"),
                    ),
                ],
              );
            },
            steps: [
              
              Step(
                title: const Text("Cover"),
                isActive: _currentStep >= 0,
                content: Column(
                  children: [
                    c.coverImage.value == null
                        ? const Text("No cover selected")
                        : Image.file(File(c.coverImage.value!.path),
                            height: 150),
                    ElevatedButton.icon(
                      onPressed: (){
                        c.pickCoverImage(context);
                      },
                      icon: const Icon(Icons.image),
                      label: const Text("Pick Cover"),
                    ),
                  ],
                ),
              ),

              
              Step(
                title: const Text("Books"),
                isActive: _currentStep >= 1,
                content: Column(
                  children: [
                    for (int i = 0; i < c.books.length; i++)
                      ListTile(
                        title: Text(c.books[i].title),
                        subtitle: Text(c.books[i].filePath),
                        trailing: IconButton(
        tooltip: 'Delete',
                          icon: const Icon(Icons.delete),
                          onPressed: () => c.removeBook(i),
                        ),
                      ),
                    TextField(
                      decoration: const InputDecoration(labelText: "Book Title"),
                      onChanged: (text) => c.newBookTitle.value = text,
                    ),
                    ElevatedButton.icon(
                      onPressed: (){
                        c.pickBookFile(context);
                      },
                      icon: const Icon(Icons.file_present),
                      label: const Text("Pick Book File"),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: (){
                        c.addBook(context);
                      },
                      child: const Text("Add Book"),
                    ),
                  ],
                ),
              ),

              
              Step(
                title: const Text("Details"),
                isActive: _currentStep >= 2,
                content: Column(
                  children: [
                    TextField(
                      decoration: const InputDecoration(labelText: "Collection Title"),
                      onChanged: (text) => c.collectionTitle.value = text,
                    ),
                    TextField(
                      decoration: const InputDecoration(labelText: "Author"),
                      onChanged: (text) => c.author.value = text,
                    ),
                    DropdownButtonFormField(
                      value: c.selectedGenre.value.isEmpty
                          ? null
                          : c.selectedGenre.value,
                      items: c.genres
                          .map((g) =>
                              DropdownMenuItem(value: g, child: Text(g)))
                          .toList(),
                      onChanged: (val) => c.selectedGenre.value = val.toString(),
                      decoration: const InputDecoration(labelText: "Genre"),
                    ),
                    DropdownButtonFormField(
                      value: c.language.value.isEmpty
                          ? null
                          : c.language.value,
                      items: c.languages
                          .map((g) =>
                              DropdownMenuItem(value: g, child: Text(g)))
                          .toList(),
                      onChanged: (val) => c.language.value = val.toString(),
                      decoration: const InputDecoration(labelText: "Language"),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text("Release: ${c.releaseDate.value.toLocal()}"),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () async {
                            DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: c.releaseDate.value,
                              firstDate: DateTime(1900),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              c.releaseDate.value = picked;
                            }
                          },
                          child: const Text("Pick Date"),
                        ),
                      ],
                    ),
                    const Divider(),
                    TextField(
                      decoration: const InputDecoration(labelText: "Add Contributor"),
                      onChanged: (text) => c.newContributor.value = text,
                    ),
                    ElevatedButton(
                      onPressed: c.addContributor,
                      child: const Text("Add Contributor"),
                    ),
                    Wrap(
                      children: c.contributors
                          .map((con) => Chip(label: Text(con)))
                          .toList(),
                    ),
                  ],
                ),
              ),

              
              Step(
                title: const Text("Review & Upload"),
                isActive: _currentStep >= 3,
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Title: ${c.collectionTitle.value}"),
                    Text("Author: ${c.author.value}"),
                    Text("Genre: ${c.selectedGenre.value}"),
                    Text("Language: ${c.language.value}"),
                    Text("Release: ${c.releaseDate.value.toLocal()}"),
                    Text("Contributors: ${c.contributors.join(', ')}"),
                    Text("Books: ${c.books.length} added"),
                    if (c.isUploading.value)
                      LinearProgressIndicator(semanticsLabel: 'Loading', value: c.uploadProgress.value),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
