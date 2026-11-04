import 'package:firebase_auth/firebase_auth.dart';
import 'package:mango/Authentication/controllers/auth_controller.dart';
import 'package:mango/Models/cloud/content.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mango/Models/controllers/creator_controller.dart';
import 'package:mango/utils.dart';

class UploadWizardV2 extends StatefulWidget {
  const UploadWizardV2({Key? key}) : super(key: key);

  @override
  State<UploadWizardV2> createState() => _UploadWizardV2State();
}

class _UploadWizardV2State extends State<UploadWizardV2> {
  final CreatorController creator = Get.put(CreatorController());
  final AuthController auth = Get.find<AuthController>();

  int step = 0;
  ContentType selectedType = ContentType.track;

  
  PlatformFile? picked;
  File? pickedFile;
  Uint8List? webPickedBytes;
  final titleCtl = TextEditingController();
  final descCtl = TextEditingController();
  final artistsCtl = TextEditingController();
  final genresCtl = TextEditingController();

  
  final List<PlatformFile> albumPicked = [];
  final List<File> albumFiles = [];
  final List<Uint8List> albumWebFiles = [];
  final List<TextEditingController> trackTitleCtls = [];
  final albumTitleCtl = TextEditingController();
  final albumDescCtl = TextEditingController();

  @override
  void dispose() {
    titleCtl.dispose();
    descCtl.dispose();
    artistsCtl.dispose();
    genresCtl.dispose();
    albumTitleCtl.dispose();
    albumDescCtl.dispose();
    for (var c in trackTitleCtls) c.dispose();
    super.dispose();
  }

  Future<void> pickSingleFile() async {
    FilePickerResult? result;
    
    if (kIsWeb) {
      
      result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: true,
      );
    } else {
      
      result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
      );
    }
    
    if (result == null) return;
    
    setState(() {
      picked = result!.files.first;
      
      if (kIsWeb) {
        
        webPickedBytes = picked!.bytes;
        pickedFile = null; 
      } else if (picked!.path != null) {
        
        pickedFile = File(picked!.path!);
        webPickedBytes = null; 
      }
    });
  }

  Future<void> pickAlbumFiles() async {
    FilePickerResult? result;
    
    if (kIsWeb) {
      
      result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
      );
    } else {
      
      result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
      );
    }
    
    if (result == null) return;
    
    setState(() {
      for (var file in result!.files) {
        albumPicked.add(file);
        
        if (kIsWeb && file.bytes != null) {
          
          albumWebFiles.add(file.bytes!);
          trackTitleCtls.add(TextEditingController(text: file.name));
        } else if (!kIsWeb && file.path != null) {
          
          albumFiles.add(File(file.path!));
          trackTitleCtls.add(TextEditingController(text: file.name));
        }
      }
    });
  }

  
  dynamic _getFileForUpload() {
    if (kIsWeb) {
      return webPickedBytes;
    } else {
      return pickedFile;
    }
  }

  
  List<dynamic> _getAlbumFilesForUpload() {
    if (kIsWeb) {
      return albumWebFiles;
    } else {
      return albumFiles;
    }
  }

  
  bool get hasSingleFile => kIsWeb ? webPickedBytes != null : pickedFile != null;

  
  bool get hasAlbumFiles => kIsWeb ? albumWebFiles.isNotEmpty : albumFiles.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Wizard'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: buildStep(),
      ),
    );
  }

  Widget buildStep() {
    switch (step) {
      case 0:
        return _buildContentTypeSelection();
      case 1:
        if (selectedType == ContentType.album) {
          return _buildAlbumUpload();
        } else {
          return _buildSingleUpload();
        }
      default:
        return const Center(child: Text('Invalid step'));
    }
  }

  Widget _buildContentTypeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'What would you like to upload?',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        Text(
          'Select content type:',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 15),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color.fromARGB(255, 60, 59, 59)),
          ),
          child: DropdownButton<ContentType>(
            value: selectedType,
            isExpanded: true,
            underline: const SizedBox(),
            items: ContentType.values
                .map(
                  (t) => DropdownMenuItem(
                    value: t,
                    child: Row(
                      children: [
                        _getContentTypeIcon(t),
                        const SizedBox(width: 12),
                        Text(
                          _getContentTypeLabel(t),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => selectedType = v!),
          ),
        ),
        const SizedBox(height: 30),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton(
              onPressed: () => setState(() => step = 1),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Next →',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSingleUpload() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Upload Content',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          
          
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: hasSingleFile ? Colors.deepPurple : const Color.fromARGB(255, 51, 51, 51),
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.cloud_upload,
                  size: 50,
                  color: hasSingleFile ? Colors.deepPurple : Colors.grey[400],
                ),
                const SizedBox(height: 10),
                Text(
                  hasSingleFile ? 'File selected' : 'No file selected',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: hasSingleFile ? Colors.deepPurple : Colors.grey[600],
                  ),
                ),
                if (picked != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    picked!.name,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (picked!.size != null) ...[
                    const SizedBox(height: 5),
                    Text(
                      '${(picked!.size! / 1024 / 1024).toStringAsFixed(2)} MB',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 15),
                ElevatedButton.icon(
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Choose File'),
                  onPressed: pickSingleFile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 30),
          
          
          Column(
            children: [
              TextField(
                controller: titleCtl,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: descCtl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: artistsCtl,
                decoration: const InputDecoration(
                  labelText: 'Artists (comma separated)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.people),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: genresCtl,
                decoration: const InputDecoration(
                  labelText: 'Genres (comma separated)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 30),
          
          
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => step = 0),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: ElevatedButton(
                  onPressed: !hasSingleFile ? null : () async {
                    if (titleCtl.text.isEmpty) {
                      UtilsService().showSnackbar(
                        'Error',
                        'Please enter a title',
                        backgroundColor: Colors.red,
                        colorText: Colors.white, context: context,
                      );
                      return;
                    }
                    
                    try {
                      final artists = artistsCtl.text.isEmpty
                          ? <String>[]
                          : artistsCtl.text
                              .split(',')
                              .map((s) => s.trim())
                              .toList()
                              .cast<String>();
                      
                      final genres = genresCtl.text.isEmpty
                          ? <String>[]
                          : genresCtl.text
                              .split(',')
                              .map((s) => s.trim())
                              .toList()
                              .cast<String>();
                      
                      await creator.createContent(
                        type: selectedType,
                        title: titleCtl.text.trim(),
                        description: descCtl.text.trim(),
                        artists: artists,
                        genres: genres,
                        file: _getFileForUpload(),
                        rights: {
                          'ownerId': FirebaseAuth.instance.currentUser!.uid,
                          'territories': ['ALL'],
                        },
                      );
                      
                      UtilsService().showSnackbar(
                        'Success',
                        'Content uploaded successfully!',
                        backgroundColor: Colors.green,
                        colorText: Colors.white, context: context,
                      );
                      
                      Get.back();
                    } catch (e) {
                      UtilsService().showSnackbar(
                        'Error',
                        'Failed to upload: ${e.toString()}',
                        backgroundColor: Colors.red,
                        colorText: Colors.white, context: context,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: creator.loading.value
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Upload'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumUpload() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Create Album',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          
          
          TextField(
            controller: albumTitleCtl,
            decoration: const InputDecoration(
              labelText: 'Album Title',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.album),
            ),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: albumDescCtl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Album Description',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.description),
            ),
          ),
          
          const SizedBox(height: 30),
          
          
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: hasAlbumFiles ? Colors.deepPurple : const Color.fromARGB(255, 53, 53, 53),
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.library_music,
                  size: 50,
                  color: hasAlbumFiles ? Colors.deepPurple : Colors.grey[400],
                ),
                const SizedBox(height: 10),
                Text(
                  hasAlbumFiles 
                    ? '${kIsWeb ? albumWebFiles.length : albumFiles.length} tracks selected' 
                    : 'No tracks selected',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: hasAlbumFiles ? Colors.deepPurple : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 15),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add Tracks'),
                  onPressed: pickAlbumFiles,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 30),
          
          
          if (hasAlbumFiles)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tracks',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.3,
                  ),
                  child: ReorderableListView(
                    shrinkWrap: true,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex -= 1;
                        
                        
                        final file = albumFiles.isNotEmpty 
                          ? albumFiles.removeAt(oldIndex) 
                          : null;
                        final webFile = albumWebFiles.isNotEmpty
                          ? albumWebFiles.removeAt(oldIndex)
                          : null;
                        final pf = albumPicked.removeAt(oldIndex);
                        final ctl = trackTitleCtls.removeAt(oldIndex);
                        
                        if (file != null) albumFiles.insert(newIndex, file);
                        if (webFile != null) albumWebFiles.insert(newIndex, webFile);
                        albumPicked.insert(newIndex, pf);
                        trackTitleCtls.insert(newIndex, ctl);
                      });
                    },
                    children: List.generate(
                      kIsWeb ? albumWebFiles.length : albumFiles.length,
                      (i) => ListTile(
                        key: ValueKey(kIsWeb ? albumWebFiles[i] : albumFiles[i]),
                        leading: CircleAvatar(
                          backgroundColor: Colors.deepPurple[100],
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              color: Colors.deepPurple,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: TextField(
                          controller: trackTitleCtls[i],
                          decoration: InputDecoration(
                            labelText: 'Track ${i + 1} title',
                            border: InputBorder.none,
                          ),
                        ),
                        subtitle: Text(
                          albumPicked[i].name,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              if (kIsWeb) {
                                albumWebFiles.removeAt(i);
                              } else {
                                albumFiles.removeAt(i);
                              }
                              albumPicked.removeAt(i);
                              trackTitleCtls.removeAt(i);
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          
          const SizedBox(height: 30),
          
          
          Column(
            children: [
              TextField(
                controller: artistsCtl,
                decoration: const InputDecoration(
                  labelText: 'Artists (comma separated)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.people),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: genresCtl,
                decoration: const InputDecoration(
                  labelText: 'Genres (comma separated)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 30),
          
          
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => step = 0),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: ElevatedButton(
                  onPressed: !hasAlbumFiles ? null : () async {
                    if (albumTitleCtl.text.isEmpty) {
                      UtilsService().showSnackbar(
                        'Error',
                        'Please enter an album title',
                        backgroundColor: Colors.red,
                        colorText: Colors.white, context: context,
                      );
                      return;
                    }
                    
                    try {
                      final artists = artistsCtl.text.isEmpty
                          ? <String>[]
                          : artistsCtl.text
                              .split(',')
                              .map((s) => s.trim())
                              .toList()
                              .cast<String>();
                      
                      final genres = genresCtl.text.isEmpty
                          ? <String>[]
                          : genresCtl.text
                              .split(',')
                              .map((s) => s.trim())
                              .toList()
                              .cast<String>();
                      
                      final trackTitles = trackTitleCtls
                          .map((c) => c.text.trim())
                          .toList();
                      
                      await creator.createAlbum(
                        albumTitle: albumTitleCtl.text.trim(),
                        albumDescription: albumDescCtl.text.trim(),
                        trackFiles: _getAlbumFilesForUpload(),
                        trackTitles: trackTitles,
                        artists: artists,
                        genres: genres,
                        rights: {
                          'ownerId': FirebaseAuth.instance.currentUser!.uid,
                          'territories': ['ALL'],
                        },
                      );
                      
                      UtilsService().showSnackbar(
                        'Success',
                        'Album created successfully!',
                        backgroundColor: Colors.green,
                        colorText: Colors.white, context: context,
                      );
                      
                      Get.back();
                    } catch (e) {
                      UtilsService().showSnackbar(
                        'Error',
                        'Failed to create album: ${e.toString()}',
                        backgroundColor: Colors.red,
                        colorText: Colors.white, context: context,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: creator.loading.value
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Create Album'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  
  Icon _getContentTypeIcon(ContentType type) {
    switch (type) {
      case ContentType.track:
        return const Icon(Icons.music_note);
      case ContentType.album:
        return const Icon(Icons.album);
      case ContentType.podcast:
        return const Icon(Icons.mic);
      case ContentType.movie:
        return const Icon(Icons.movie);
      
        
      default:
        return const Icon(Icons.insert_drive_file);
    }
  }

  String _getContentTypeLabel(ContentType type) {
    switch (type) {
      case ContentType.track:
        return 'Single Track';
      case ContentType.album:
        return 'Album';
      case ContentType.podcast:
        return 'Podcast';
      case ContentType.movie:
        return 'Movie';
      
      default:
        return type.toString().split('.').last;
    }
  }
}