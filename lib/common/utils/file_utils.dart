import 'dart:io';
import 'dart:math';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

/// Utility class for file operations.
///
/// This class provides methods for working with files, such as
/// downloading, saving, and deleting files.
class FileUtils {
  /// Gets the hidden folder for storing files.
  ///
  /// Creates the folder if it doesn't exist.
  static Future<Directory> getHiddenFolder() async {
    final Directory downloadsDir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
    final Directory hiddenFolder = Directory('${downloadsDir.path}/.hidden_folder');
    
    if (!await hiddenFolder.exists()) {
      await hiddenFolder.create(recursive: true);
    }
    
    return hiddenFolder;
  }

  /// Gets all files in the hidden folder.
  static Future<List<File>> getFilesInHiddenFolder() async {
    final Directory hiddenFolder = await getHiddenFolder();
    final List<FileSystemEntity> entities = await hiddenFolder.list().toList();
    return entities.whereType<File>().toList();
  }

  /// Downloads a file from a URL.
  ///
  /// Returns the downloaded file.
  static Future<File> downloadFile(String url, {String? customFileName}) async {
    try {
      final Directory hiddenFolder = await getHiddenFolder();
      final String fileName = customFileName ?? path.basename(url);
      final File file = File('${hiddenFolder.path}/$fileName');
      
      final http.Response response = await http.get(Uri.parse(url));
      await file.writeAsBytes(response.bodyBytes);
      
      return file;
    } catch (e) {
      debugPrint('Error downloading file: $e');
      rethrow;
    }
  }

  /// Deletes a file.
  static Future<void> deleteFile(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error deleting file: $e');
    }
  }

  /// Saves a file with a prefix.
  ///
  /// This is useful for saving files that should be persisted.
  static Future<File> saveFile(File file, {String prefix = 'saved_'}) async {
    try {
      final Directory hiddenFolder = await getHiddenFolder();
      final String fileName = path.basename(file.path);
      final String prefixedFileName = '$prefix$fileName';
      final File savedFile = File('${hiddenFolder.path}/$prefixedFileName');
      
      // Copy the file
      await file.copy(savedFile.path);
      
      return savedFile;
    } catch (e) {
      debugPrint('Error saving file: $e');
      rethrow;
    }
  }

  /// Gets the file size in a human-readable format.
  static String getFileSize(File file, {int decimals = 1}) {
    final bytes = file.lengthSync();
    if (bytes <= 0) return "0 B";
    
    const suffixes = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];
    final i = (log(bytes) / log(1024)).floor();
    
    return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  /// Checks if a file exists.
  static Future<bool> fileExists(String filePath) async {
    final file = File(filePath);
    return await file.exists();
  }
}

