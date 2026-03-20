import 'dart:io';
import 'dart:typed_data';

import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CloudinaryService {
  CloudinaryService._private();
  static final CloudinaryService instance = CloudinaryService._private();

  static const String _cloudName = 'dwfxs0im6';
  static const String _presetStorageKey = 'cloudinary_upload_preset';
  static const String _uploadPreset = String.fromEnvironment(
    'CLOUDINARY_UPLOAD_PRESET',
    defaultValue: 'transaction_app_preset',
  );
  String? _runtimePreset;

  Future<void> initialize() async {
    if (_runtimePreset != null) return;
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_presetStorageKey);
    if (saved != null && saved.trim().isNotEmpty) {
      _runtimePreset = saved.trim();
    }
  }

  Future<void> setUploadPreset(String preset) async {
    final normalized = preset.trim();
    _runtimePreset = normalized;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_presetStorageKey, normalized);
  }

  bool get isConfigured {
    final preset = _runtimePreset ?? _uploadPreset;
    return preset.trim().isNotEmpty;
  }

  CloudinaryPublic get _client {
    final effectivePreset = (_runtimePreset ?? _uploadPreset).trim();
    if (effectivePreset.isEmpty) {
      throw Exception('Missing Cloudinary upload preset');
    }
    return CloudinaryPublic(_cloudName, effectivePreset, cache: false);
  }

  Future<String> uploadImagePath(File file) async {
    final response = await _client.uploadFile(
      CloudinaryFile.fromFile(
        file.path,
        folder: 'transactions/images',
        resourceType: CloudinaryResourceType.Image,
      ),
    );
    return response.publicId;
  }

  Future<String> uploadFilePath(File file) async {
    final response = await _client.uploadFile(
      CloudinaryFile.fromFile(
        file.path,
        folder: 'transactions/files',
        resourceType: CloudinaryResourceType.Raw,
      ),
    );
    return response.publicId;
  }

  Future<String> uploadHandwritingPath(Uint8List pngBytes) async {
    final tmpDir = await getTemporaryDirectory();
    final tmpFile = File(
      '${tmpDir.path}/handwriting_${DateTime.now().microsecondsSinceEpoch}.png',
    );
    await tmpFile.writeAsBytes(pngBytes, flush: true);

    final response = await _client.uploadFile(
      CloudinaryFile.fromFile(
        tmpFile.path,
        folder: 'transactions/handwriting',
        resourceType: CloudinaryResourceType.Image,
      ),
    );

    try {
      await tmpFile.delete();
    } catch (_) {
      // ignore temp cleanup issues
    }

    return response.publicId;
  }
}
