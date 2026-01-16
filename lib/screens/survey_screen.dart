import 'dart:async';

import 'package:flutter/material.dart';

import '../models/survey_models.dart';
import '../services/survey_repository.dart';
import 'result_detail_screen.dart';

class SurveyScreen extends StatefulWidget {
  const SurveyScreen({
    super.key,
    required this.survey,
    required this.repository,
    required this.deviceId,
  });

  final Survey survey;
  final SurveyRepository repository;
  final String deviceId;

  @override
  State<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends State<SurveyScreen> {
  final Map<String, Answer> _answers = <String, Answer>{};
  final Map<String, TextEditingController> _textControllers =
      <String, TextEditingController>{};

  late final DateTime _startedAt;
  int _currentIndex = 0;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
  }

  @override
  void dispose() {
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Question get _currentQuestion => widget.survey.questions[_currentIndex];

  bool _isAnswered(Question question) {
    final answer = _answers[question.id];
    if (question.type == QuestionType.text) {
      return answer?.textAnswer?.trim().isNotEmpty ?? false;
    }
    if (question.options.isEmpty) {
      return true;
    }
    return answer != null && answer.selectedOptions.isNotEmpty;
  }

  void _setSingleAnswer(Question question, String option) {
    setState(() {
      _answers[question.id] = Answer(
        questionId: question.id,
        questionText: question.text,
        type: question.type,
        selectedOptions: <String>[option],
        textAnswer: null,
      );
    });
  }

  void _toggleMultiAnswer(Question question, String option, bool selected) {
    final current =
        _answers[question.id]?.selectedOptions.toSet() ?? <String>{};
    if (selected) {
      current.add(option);
    } else {
      current.remove(option);
    }
    setState(() {
      _answers[question.id] = Answer(
        questionId: question.id,
        questionText: question.text,
        type: question.type,
        selectedOptions: current.toList(),
        textAnswer: null,
      );
    });
  }

  void _setTextAnswer(Question question, String value) {
    setState(() {
      _answers[question.id] = Answer(
        questionId: question.id,
        questionText: question.text,
        type: question.type,
        selectedOptions: const <String>[],
        textAnswer: value.trim().isEmpty ? null : value,
      );
    });
  }

  TextEditingController _controllerFor(Question question) {
    final existing = _textControllers[question.id];
    if (existing != null) {
      return existing;
    }
    final controller = TextEditingController(
      text: _answers[question.id]?.textAnswer ?? '',
    );
    _textControllers[question.id] = controller;
    return controller;
  }

  void _nextQuestion() {
    FocusScope.of(context).unfocus();
    if (_currentIndex < widget.survey.questions.length - 1) {
      setState(() {
        _currentIndex += 1;
      });
    }
  }

  void _previousQuestion() {
    FocusScope.of(context).unfocus();
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex -= 1;
      });
    }
  }

  Future<void> _finishSurvey() async {
    if (_saving) {
      return;
    }
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Submit survey?'),
            content: const Text(
              'You will not be able to edit your answers after submission.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Submit'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final completedAt = DateTime.now();
      final answers = widget.survey.questions
          .map(
            (question) =>
                _answers[question.id] ??
                Answer(
                  questionId: question.id,
                  questionText: question.text,
                  type: question.type,
                  selectedOptions: const <String>[],
                  textAnswer: null,
                ),
          )
          .toList();
      final result = SurveyResult(
        runId: completedAt.microsecondsSinceEpoch.toString(),
        deviceId: widget.deviceId,
        surveyTitle: widget.survey.title,
        startedAt: _startedAt,
        completedAt: completedAt,
        answers: answers,
      );
      final file = await widget.repository.saveResult(result);
      if (!mounted) {
        return;
      }
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => ResultDetailScreen(
            repository: widget.repository,
            file: file,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save results: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Widget _buildQuestionBody(Question question) {
    final theme = Theme.of(context);
    switch (question.type) {
      case QuestionType.single:
        if (question.options.isEmpty) {
          return Text(
            'No options provided for this question.',
            style: theme.textTheme.bodyMedium,
          );
        }
        final selected = _answers[question.id]?.selectedOptions;
        final groupValue = selected != null && selected.isNotEmpty
            ? selected.first
            : null;
        return RadioGroup<String>(
          groupValue: groupValue,
          onChanged: (value) {
            if (value != null) {
              _setSingleAnswer(question, value);
            }
          },
          child: Column(
            children: question.options
                .map(
                  (option) => RadioListTile<String>(
                    title: Text(option),
                    value: option,
                  ),
                )
                .toList(),
          ),
        );
      case QuestionType.multiple:
        if (question.options.isEmpty) {
          return Text(
            'No options provided for this question.',
            style: theme.textTheme.bodyMedium,
          );
        }
        final selected =
            _answers[question.id]?.selectedOptions.toSet() ?? <String>{};
        return Column(
          children: question.options
              .map(
                (option) => CheckboxListTile(
                  title: Text(option),
                  value: selected.contains(option),
                  onChanged: (checked) {
                    _toggleMultiAnswer(question, option, checked ?? false);
                  },
                ),
              )
              .toList(),
        );
      case QuestionType.text:
        final controller = _controllerFor(question);
        return TextField(
          controller: controller,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Type your answer',
          ),
          maxLines: 4,
          onChanged: (value) => _setTextAnswer(question, value),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final question = _currentQuestion;
    final total = widget.survey.questions.length;
    final progress = total == 0 ? 0.0 : (_currentIndex + 1) / total;
    final isLast = _currentIndex == total - 1;
    final canProceed = _isAnswered(question);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.survey.title),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(value: progress),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Question ${_currentIndex + 1} of $total',
                style: theme.textTheme.titleMedium,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      question.text,
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    _buildQuestionBody(question),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _currentIndex == 0 ? null : _previousQuestion,
                      icon: const Icon(Icons.chevron_left),
                      label: const Text('Back'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _saving
                          ? null
                          : (canProceed
                              ? (isLast ? _finishSurvey : _nextQuestion)
                              : null),
                      icon: Icon(isLast ? Icons.check : Icons.chevron_right),
                      label: Text(isLast ? 'Finish' : 'Next'),
                    ),
                  ),
                ],
              ),
            ),
            if (_saving)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: LinearProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}
