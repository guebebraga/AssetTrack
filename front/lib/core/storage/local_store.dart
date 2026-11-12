import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

abstract class LocalStore {
  Future<Map<String, dynamic>?> read();
  Future<void> write(Map<String, dynamic> data);
  Future<void> clear();
}

class MemoryStore implements LocalStore {
  MemoryStore([this._data]);

  Map<String, dynamic>? _data;

  Map<String, dynamic>? get data => _data;

  @override
  Future<Map<String, dynamic>?> read() async => _data;

  @override
  Future<void> write(Map<String, dynamic> data) async {
    _data = jsonDecode(jsonEncode(data)) as Map<String, dynamic>;
  }

  @override
  Future<void> clear() async {
    _data = null;
  }
}

class JsonFileStore implements LocalStore {
  JsonFileStore({this.fileName = 'assettrack_snapshot.json'});

  final String fileName;
  File? _cachedFile;

  Future<File> _file() async {
    if (_cachedFile != null) return _cachedFile!;
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    _cachedFile = File('${directory.path}${Platform.pathSeparator}$fileName');
    return _cachedFile!;
  }

  @override
  Future<Map<String, dynamic>?> read() async {
    final file = await _file();
    if (!await file.exists()) return null;
    try {
      final content = await file.readAsString();
      if (content.trim().isEmpty) return null;
      return jsonDecode(content) as Map<String, dynamic>;
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> write(Map<String, dynamic> data) async {
    final file = await _file();
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(data), flush: true);
    if (await file.exists()) {
      await file.delete();
    }
    await temp.rename(file.path);
  }

  @override
  Future<void> clear() async {
    final file = await _file();
    if (await file.exists()) {
      await file.delete();
    }
  }
}
