import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../services/survey_repository.dart';

class ResultDetailScreen extends StatefulWidget {
  const ResultDetailScreen({
    super.key,
    required this.repository,
    required this.file,
  });

  final SurveyRepository repository;
  final File file;

  @override
  State<ResultDetailScreen> createState() => _ResultDetailScreenState();
}

class _ResultDetailScreenState extends State<ResultDetailScreen> {
  late Future<_ResultPayload> _payload;

  @override
  void initState() {
    super.initState();
    _payload = _loadPayload();
  }

  Future<_ResultPayload> _loadPayload() async {
    final raw = await widget.repository.readResult(widget.file);
    Map<String, dynamic>? parsed;
    try {
      parsed = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      parsed = null;
    }
    return _ResultPayload(rawJson: raw, parsed: parsed);
  }

  String _formatDate(String? value) {
    if (value == null) {
      return 'Неизвестно';
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      return value;
    }
    final local = parsed.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  Future<void> _shareFile() async {
    await Share.shareXFiles(
      [XFile(widget.file.path)],
      text: 'Результат опроса (JSON)',
    );
  }

  @override
  Widget build(BuildContext context) {
    final fileName = widget.file.uri.pathSegments.last;
    return Scaffold(
      appBar: AppBar(
        title: Text(fileName),
        actions: [
          IconButton(
            onPressed: _shareFile,
            icon: const Icon(Icons.share),
            tooltip: 'Поделиться',
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<_ResultPayload>(
          future: _payload,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Text('Не удалось загрузить результат: ${snapshot.error}'),
              );
            }
            final payload = snapshot.data;
            if (payload == null) {
              return const Center(child: Text('Данные не найдены.'));
            }
            final parsed = payload.parsed;
            final answers = parsed?['answers'];
            final answerCount = answers is List ? answers.length : null;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (parsed != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            parsed['surveyTitle']?.toString() ?? 'Опрос',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'ID устройства: ${parsed['deviceId'] ?? 'Неизвестно'}',
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Завершено: ${_formatDate(parsed['completedAt']?.toString())}',
                          ),
                          if (answerCount != null) ...[
                            const SizedBox(height: 4),
                            Text('Ответов: $answerCount'),
                          ],
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  'JSON результат',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SelectableText(payload.rawJson),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ResultPayload {
  const _ResultPayload({required this.rawJson, required this.parsed});

  final String rawJson;
  final Map<String, dynamic>? parsed;
}
