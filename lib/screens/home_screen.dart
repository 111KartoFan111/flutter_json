import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/survey_models.dart';
import '../services/device_identifier.dart';
import '../services/survey_repository.dart';
import 'results_screen.dart';
import 'survey_screen.dart';

class SurveyHomeScreen extends StatefulWidget {
  const SurveyHomeScreen({super.key});

  @override
  State<SurveyHomeScreen> createState() => _SurveyHomeScreenState();
}

class _SurveyHomeScreenState extends State<SurveyHomeScreen> {
  static const _urlPrefsKey = 'questions_url';

  final TextEditingController _urlController = TextEditingController();
  final SurveyRepository _repository = SurveyRepository();

  Survey? _survey;
  String? _error;
  String? _deviceId;
  bool _loading = false;
  bool _initializing = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString(_urlPrefsKey) ?? '';
    _urlController.text = savedUrl;
    final deviceId = await DeviceIdentifier.resolve();
    if (!mounted) {
      return;
    }
    setState(() {
      _deviceId = deviceId;
    });
    if (savedUrl.isNotEmpty) {
      await _loadQuestions();
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _initializing = false;
    });
  }

  Future<void> _loadQuestions() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final rawUrl = _urlController.text.trim();
    if (rawUrl.isEmpty) {
      setState(() {
        _error = 'Введите URL удаленной базы вопросов (JSON).';
        _survey = null;
      });
      return;
    }
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      setState(() {
        _error = 'Некорректный URL. Используйте http или https.';
        _survey = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final survey = await _repository.fetchSurvey(uri);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_urlPrefsKey, rawUrl);
      if (!mounted) {
        return;
      }
      setState(() {
        _survey = survey;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Не удалось загрузить вопросы: $error';
        _survey = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _startSurvey() async {
    if (_survey == null) {
      return;
    }
    final deviceId = _deviceId ?? await DeviceIdentifier.resolve();
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SurveyScreen(
          survey: _survey!,
          repository: _repository,
          deviceId: deviceId,
        ),
      ),
    );
  }

  void _openResults() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ResultsScreen(repository: _repository),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Удаленный опрос'),
        actions: [
          IconButton(
            onPressed: _openResults,
            icon: const Icon(Icons.folder_open),
            tooltip: 'Результаты',
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'URL удаленной базы вопросов',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'https://example.com/survey.json',
              ),
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _loadQuestions(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _loadQuestions,
                    icon: const Icon(Icons.download),
                    label: const Text('Загрузить вопросы'),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _openResults,
                  icon: const Icon(Icons.list_alt),
                  label: const Text('Результаты'),
                ),
              ],
            ),
            if (_loading) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (_survey != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _survey!.title,
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_survey!.questions.length} вопросов загружено',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed:
                            _loading || _initializing ? null : _startSurvey,
                        child: const Text('Начать опрос'),
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (!_loading) ...[
              Text(
                'Загрузите вопросы, чтобы начать опрос.',
                style: theme.textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 16),
            if (_deviceId != null)
              Text(
                'ID устройства: $_deviceId',
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}
