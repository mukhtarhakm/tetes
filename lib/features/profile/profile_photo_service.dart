import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../core/utils/uuid_v4.dart';
import '../../data/repositories/user_repo.dart';

class ProfilePhotoService {
  ProfilePhotoService({
    ImagePicker? picker,
    Future<Directory> Function()? documentsDirectory,
  }) : _picker = picker ?? ImagePicker(),
       _documentsDirectory =
           documentsDirectory ?? getApplicationDocumentsDirectory;

  static const maxWidth = 512.0;
  static const maxHeight = 512.0;
  static const imageQuality = 85;

  final ImagePicker _picker;
  final Future<Directory> Function() _documentsDirectory;

  Future<Directory> directory() => _documentsDirectory();

  Future<String?> replace({
    required String userId,
    required String? previousName,
    required ImageSource source,
    required UserRepository repository,
  }) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
    );
    if (picked == null) return null;
    final directory = await _documentsDirectory();
    final fileName =
        'profile_${userId}_${createUuidV4()}${path.extension(picked.path).toLowerCase()}';
    final newFile = File(path.join(directory.path, fileName));
    try {
      await File(picked.path).copy(newFile.path);
      await repository.savePhotoPath(userId, fileName);
    } catch (_) {
      if (await newFile.exists()) await newFile.delete();
      rethrow;
    }
    if (previousName != null && previousName != fileName) {
      final oldFile = File(
        path.join(directory.path, path.basename(previousName)),
      );
      try {
        if (await oldFile.exists()) await oldFile.delete();
      } catch (_) {
        // The saved replacement remains valid if old-file cleanup fails.
      }
    }
    return fileName;
  }
}
