import 'dart:io';

import 'package:flutter/material.dart';

import '../services/survey_repository.dart';
import 'result_detail_screen.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key, required this.repository});

  final SurveyRepository repository;

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  List<File> _files = <File>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final files = await widget.repository.listResultFiles();
      if (!mounted) {
        return;
      }
      setState(() {
        _files = files;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Не удалось загрузить результаты: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Widget content;
    if (_loading) {
      content = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Center(child: CircularProgressIndicator()),
        ],
      );
    } else if (_error != null) {
      content = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            _error!,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.error,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    } else if (_files.isEmpty) {
      content = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Результаты пока не сохранены.',
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      );
    } else {
      content = ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _files.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final file = _files[index];
          final stat = file.statSync();
          return ListTile(
            tileColor: theme.colorScheme.surfaceContainerHighest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: Text(file.uri.pathSegments.last),
            subtitle: Text(
              '${_formatDateTime(stat.modified)} · '
              '${stat.size} байт',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ResultDetailScreen(
                    repository: widget.repository,
                    file: file,
                  ),
                ),
              );
            },
          );
        },
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Результаты опроса'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadFiles,
          child: content,
        ),
      ),
    );
  }
}
