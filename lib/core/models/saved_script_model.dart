import 'package:equatable/equatable.dart';

/// Represents a persistently saved teleprompter script in the creator's library.
class SavedScript extends Equatable {
  final String id;
  final String title;
  final String content;
  final double scrollSpeedWpm;
  final double fontSize;
  final DateTime updatedAt;

  const SavedScript({
    required this.id,
    required this.title,
    required this.content,
    this.scrollSpeedWpm = 140.0,
    this.fontSize = 32.0,
    required this.updatedAt,
  });

  SavedScript copyWith({
    String? id,
    String? title,
    String? content,
    double? scrollSpeedWpm,
    double? fontSize,
    DateTime? updatedAt,
  }) {
    return SavedScript(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      scrollSpeedWpm: scrollSpeedWpm ?? this.scrollSpeedWpm,
      fontSize: fontSize ?? this.fontSize,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'scrollSpeedWpm': scrollSpeedWpm,
      'fontSize': fontSize,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory SavedScript.fromJson(Map<String, dynamic> json) {
    return SavedScript(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Untitled Script',
      content: json['content'] as String? ?? '',
      scrollSpeedWpm: (json['scrollSpeedWpm'] as num?)?.toDouble() ?? 140.0,
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 32.0,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
    id,
    title,
    content,
    scrollSpeedWpm,
    fontSize,
    updatedAt,
  ];
}
