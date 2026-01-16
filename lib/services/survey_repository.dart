import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/survey_models.dart';

class SurveyRepository {
  SurveyRepository({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<Survey> fetchSurvey(Uri url) async {
    final response = await _client.get(url);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Запрос завершился ошибкой (${response.statusCode}).',
        uri: url,
      );
    }
    final dynamic data = jsonDecode(response.body);
    return Survey.fromDynamic(data);
  }

  Future<File> saveResult(SurveyResult result) async {
    final directory = await _ensureResultsDirectory();
    final sanitizedDeviceId = _sanitizeForFileName(result.deviceId);
    final timestamp =
        result.completedAt.toUtc().toIso8601String().replaceAll(':', '-');
    final fileName = 'survey_${timestamp}_$sanitizedDeviceId.json';
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(result.toPrettyJson());
    return file;
  }

  Future<List<File>> listResultFiles() async {
    final directory = await _ensureResultsDirectory();
    if (!await directory.exists()) {
      return <File>[];
    }
    final entries = await directory.list().toList();
    final files = entries
        .whereType<File>()
        .where((file) => file.path.toLowerCase().endsWith('.json'))
        .toList();
    files.sort((a, b) =>
        b.statSync().modified.compareTo(a.statSync().modified));
    return files;
  }

  Future<String> readResult(File file) async {
    return file.readAsString();
  }

  Future<Directory> _ensureResultsDirectory() async {
    final base = await getApplicationDocumentsDirectory();
    final directory = Directory('${base.path}/survey_results');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  String _sanitizeForFileName(String value) {
    return value.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  }
}
