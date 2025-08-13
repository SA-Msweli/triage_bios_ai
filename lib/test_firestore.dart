import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class StorageTestPage extends StatefulWidget {
  const StorageTestPage({super.key});
  @override
  State<StorageTestPage> createState() => _StorageTestPageState();
}

class _StorageTestPageState extends State<StorageTestPage> {
  String? downloadUrl;

  Future<void> uploadTestFile() async {
    // Pick image from gallery
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked == null) return;

    final file = File(picked.path);

    // Create a storage reference
    final storageRef = FirebaseStorage.instance
        .ref()
        .child("test-folder/${DateTime.now().millisecondsSinceEpoch}.jpg");

    // Upload the file
    await storageRef.putFile(file);

    // Get the download URL
    final url = await storageRef.getDownloadURL();

    setState(() {
      downloadUrl = url;
    });

    print("✅ File uploaded. URL: $url");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Firebase Storage Test")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: uploadTestFile,
              child: const Text("Upload Test File"),
            ),
            if (downloadUrl != null) ...[
              const SizedBox(height: 20),
              Text("Download URL:"),
              SelectableText(downloadUrl!),
              const SizedBox(height: 10),
              Image.network(downloadUrl!),
            ]
          ],
        ),
      ),
    );
  }
}
