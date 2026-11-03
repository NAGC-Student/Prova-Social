import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Until which point the Modo Foco counts down.
///
/// `none` keeps the stopwatch purely informational, which is how the quiz
/// behaved before a limit could be configured.
enum FocusTimeLimit { none, total, perQuestion }

@immutable
class FocusTimerSettings {
  const FocusTimerSettings({
    this.limit = FocusTimeLimit.none,
    this.totalMinutes = 60,
    this.questionSeconds = 90,
  });

  final FocusTimeLimit limit;
  final int totalMinutes;
  final int questionSeconds;

  static const _key = 'focus_timer_settings_v1';
  static const minTotalMinutes = 5;
  static const maxTotalMinutes = 480;
  static const minQuestionSeconds = 15;
  static const maxQuestionSeconds = 600;
  static const totalMinutesStep = 5;
  static const questionSecondsStep = 15;

  /// Budget in seconds for the active limit, or null when counting up.
  int? get limitSeconds => switch (limit) {
    FocusTimeLimit.total => totalMinutes * 60,
    FocusTimeLimit.perQuestion => questionSeconds,
    FocusTimeLimit.none => null,
  };

  FocusTimerSettings copyWith({
    FocusTimeLimit? limit,
    int? totalMinutes,
    int? questionSeconds,
  }) => FocusTimerSettings(
    limit: limit ?? this.limit,
    totalMinutes: totalMinutes ?? this.totalMinutes,
    questionSeconds: questionSeconds ?? this.questionSeconds,
  );

  Future<void> save() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = await preferences.setString(
      _key,
      jsonEncode({
        'limit': limit.name,
        'totalMinutes': totalMinutes,
        'questionSeconds': questionSeconds,
      }),
    );
    if (!stored) throw StateError('A preferência recusou a gravação.');
  }

  static Future<FocusTimerSettings> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_key);
      if (raw == null) return const FocusTimerSettings();
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return const FocusTimerSettings();
      return FocusTimerSettings(
        limit: FocusTimeLimit.values.byName(
          decoded['limit'] as String? ?? FocusTimeLimit.none.name,
        ),
        totalMinutes: _clamp(
          decoded['totalMinutes'],
          minTotalMinutes,
          maxTotalMinutes,
        ),
        questionSeconds: _clamp(
          decoded['questionSeconds'],
          minQuestionSeconds,
          maxQuestionSeconds,
        ),
      );
    } on Object {
      // Uma preferência ilegível não pode impedir a abertura da prova.
      return const FocusTimerSettings();
    }
  }

  static int _clamp(Object? value, int min, int max) {
    if (value is! num) return min;
    return value.round().clamp(min, max);
  }
}
