import 'dart:convert';

enum QuestionType { single, multiple, text }

QuestionType questionTypeFromString(String value) {
  switch (value.toLowerCase()) {
    case 'single':
    case 'single_choice':
    case 'one':
      return QuestionType.single;
    case 'multiple':
    case 'multi':
    case 'multiple_choice':
      return QuestionType.multiple;
    case 'text':
    case 'free_text':
      return QuestionType.text;
    default:
      return QuestionType.text;
  }
}

String questionTypeToString(QuestionType type) {
  switch (type) {
    case QuestionType.single:
      return 'single';
    case QuestionType.multiple:
      return 'multiple';
    case QuestionType.text:
      return 'text';
  }
}

class Survey {
  const Survey({required this.title, required this.questions});

  final String title;
  final List<Question> questions;

  factory Survey.fromJson(Map<String, dynamic> json) {
    final rawTitle = json['title']?.toString().trim();
    final title = (rawTitle == null || rawTitle.isEmpty) ? 'Опрос' : rawTitle;
    final rawQuestions = json['questions'] ?? json['items'] ?? json['data'];
    if (rawQuestions is! List) {
      throw const FormatException(
        'Список вопросов отсутствует или имеет неверный формат.',
      );
    }
    final questions = rawQuestions
        .map<Question>((dynamic item) =>
            Question.fromJson(item as Map<String, dynamic>))
        .toList();
    if (questions.isEmpty) {
      throw const FormatException('Список вопросов пуст.');
    }
    return Survey(title: title, questions: questions);
  }

  static Survey fromDynamic(dynamic data) {
    if (data is List) {
      final questions = data
          .map<Question>((dynamic item) =>
              Question.fromJson(item as Map<String, dynamic>))
          .toList();
      if (questions.isEmpty) {
        throw const FormatException('Список вопросов пуст.');
      }
      return Survey(title: 'Опрос', questions: questions);
    }
    if (data is Map<String, dynamic>) {
      return Survey.fromJson(data);
    }
    throw const FormatException('Неподдерживаемый формат JSON для опроса.');
  }
}

class Question {
  const Question({
    required this.id,
    required this.text,
    required this.type,
    required this.options,
  });

  final String id;
  final String text;
  final QuestionType type;
  final List<String> options;

  factory Question.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString().trim();
    final text = json['text']?.toString().trim();
    if (id == null || id.isEmpty) {
      throw const FormatException('Отсутствует идентификатор вопроса.');
    }
    if (text == null || text.isEmpty) {
      throw const FormatException('Отсутствует текст вопроса.');
    }
    final typeRaw = json['type']?.toString() ?? 'single';
    final type = questionTypeFromString(typeRaw);
    final rawOptions = json['options'];
    final options = rawOptions is List
        ? rawOptions.map((dynamic option) => option.toString()).toList()
        : <String>[];
    return Question(id: id, text: text, type: type, options: options);
  }
}

class Answer {
  const Answer({
    required this.questionId,
    required this.questionText,
    required this.type,
    required this.selectedOptions,
    required this.textAnswer,
  });

  final String questionId;
  final String questionText;
  final QuestionType type;
  final List<String> selectedOptions;
  final String? textAnswer;

  Map<String, dynamic> toJson() {
    return {
      'questionId': questionId,
      'questionText': questionText,
      'type': questionTypeToString(type),
      'selectedOptions': selectedOptions,
      'textAnswer': textAnswer,
    };
  }
}

class SurveyResult {
  const SurveyResult({
    required this.runId,
    required this.deviceId,
    required this.surveyTitle,
    required this.startedAt,
    required this.completedAt,
    required this.answers,
  });

  final String runId;
  final String deviceId;
  final String surveyTitle;
  final DateTime startedAt;
  final DateTime completedAt;
  final List<Answer> answers;

  Map<String, dynamic> toJson() {
    return {
      'runId': runId,
      'deviceId': deviceId,
      'surveyTitle': surveyTitle,
      'startedAt': startedAt.toIso8601String(),
      'completedAt': completedAt.toIso8601String(),
      'answers': answers.map((answer) => answer.toJson()).toList(),
    };
  }

  String toPrettyJson() {
    return const JsonEncoder.withIndent('  ').convert(toJson());
  }
}
