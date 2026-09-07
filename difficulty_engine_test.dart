import 'package:flutter_test/flutter_test.dart';
import 'package:mindgate/core/constants/app_constants.dart';
import 'package:mindgate/models/puzzle.dart';
import 'package:mindgate/models/puzzle_attempt.dart';
import 'package:mindgate/services/difficulty_engine.dart';

/// Builds a synthetic attempt window.
List<PuzzleAttempt> attempts({
  required int count,
  required int correct,
  int responseMs = 6000,
  int difficulty = 3,
  PuzzleCategory category = PuzzleCategory.math,
}) {
  return List.generate(count, (i) {
    return PuzzleAttempt(
      category: category,
      type: PuzzleType.addition,
      difficulty: difficulty,
      isCorrect: i < correct,
      responseMs: responseMs,
      createdAt: DateTime.now().millisecondsSinceEpoch - i * 1000,
    );
  });
}

void main() {
  const engine = DifficultyEngine();

  group('promotion', () {
    test('promotes on high accuracy inside the target time', () {
      final decision = engine.evaluate(
        category: PuzzleCategory.math,
        currentLevel: 3,
        attempts: attempts(count: 10, correct: 9, responseMs: 6000),
      );

      expect(decision.change, LevelChange.promoted);
      expect(decision.newLevel, 4);
    });

    test('does not promote on accuracy alone when answers are slow', () {
      // Accurate but well past the design target: the level is still doing
      // useful work, so it should hold.
      final decision = engine.evaluate(
        category: PuzzleCategory.math,
        currentLevel: 3,
        attempts: attempts(count: 10, correct: 10, responseMs: 25000),
      );

      expect(decision.change, LevelChange.unchanged);
      expect(decision.newLevel, 3);
    });

    test('will not promote past the maximum level', () {
      final decision = engine.evaluate(
        category: PuzzleCategory.math,
        currentLevel: AppConstants.maxDifficulty,
        attempts: attempts(count: 10, correct: 10, responseMs: 4000),
      );

      expect(decision.change, LevelChange.unchanged);
      expect(decision.newLevel, AppConstants.maxDifficulty);
    });

    test('needs a minimum sample before moving', () {
      // Three perfect answers is luck, not mastery.
      final decision = engine.evaluate(
        category: PuzzleCategory.math,
        currentLevel: 2,
        attempts: attempts(count: 3, correct: 3, responseMs: 3000),
      );

      expect(decision.change, LevelChange.unchanged);
      expect(decision.sampleSize, 3);
    });
  });

  group('demotion', () {
    test('demotes when accuracy falls below the floor', () {
      final decision = engine.evaluate(
        category: PuzzleCategory.english,
        currentLevel: 5,
        attempts: attempts(count: 10, correct: 3, category: PuzzleCategory.english),
      );

      expect(decision.change, LevelChange.demoted);
      expect(decision.newLevel, 4);
    });

    test('will not demote below the minimum level', () {
      final decision = engine.evaluate(
        category: PuzzleCategory.english,
        currentLevel: AppConstants.minDifficulty,
        attempts: attempts(count: 10, correct: 1, category: PuzzleCategory.english),
      );

      expect(decision.change, LevelChange.unchanged);
      expect(decision.newLevel, AppConstants.minDifficulty);
    });

    test('holds steady in the middle band', () {
      // 60%: not good enough to promote, not bad enough to demote.
      final decision = engine.evaluate(
        category: PuzzleCategory.cognitive,
        currentLevel: 4,
        attempts: attempts(count: 10, correct: 6, category: PuzzleCategory.cognitive),
      );

      expect(decision.change, LevelChange.unchanged);
      expect(decision.accuracy, closeTo(0.6, 0.001));
    });
  });

  group('xp', () {
    test('awards nothing for a wrong answer', () {
      expect(engine.xpFor(wasCorrect: false, difficulty: 5, responseMs: 3000), 0);
    });

    test('scales with difficulty', () {
      final easy = engine.xpFor(wasCorrect: true, difficulty: 1, responseMs: 20000);
      final hard = engine.xpFor(wasCorrect: true, difficulty: 9, responseMs: 20000);
      expect(hard, greaterThan(easy));
    });

    test('pays a bonus for answering inside the target window', () {
      final fast = engine.xpFor(wasCorrect: true, difficulty: 3, responseMs: 6000);
      final slow = engine.xpFor(wasCorrect: true, difficulty: 3, responseMs: 20000);
      expect(fast - slow, AppConstants.xpSpeedBonus);
    });
  });

  group('level descriptions', () {
    test('match the ladder in the brief', () {
      expect(engine.describeLevel(PuzzleCategory.math, 1), 'Addition');
      expect(engine.describeLevel(PuzzleCategory.math, 2), 'Subtraction');
      expect(engine.describeLevel(PuzzleCategory.math, 3), 'Multiplication');
      expect(engine.describeLevel(PuzzleCategory.math, 4), 'Division');

      expect(engine.describeLevel(PuzzleCategory.english, 1), 'Common words');
      expect(engine.describeLevel(PuzzleCategory.english, 2), 'Synonyms');
      expect(engine.describeLevel(PuzzleCategory.english, 3), 'Antonyms');
      expect(engine.describeLevel(PuzzleCategory.english, 4), 'Vocabulary');

      expect(engine.describeLevel(PuzzleCategory.cognitive, 1), 'Pattern recognition');
      expect(engine.describeLevel(PuzzleCategory.cognitive, 2), 'Memory recall');
      expect(engine.describeLevel(PuzzleCategory.cognitive, 3), 'Logic');
      expect(engine.describeLevel(PuzzleCategory.cognitive, 4), 'Sequences');
    });

    test('every level 1–10 has a description for every category', () {
      for (final category in PuzzleCategory.values) {
        for (var level = 1; level <= 10; level++) {
          expect(engine.describeLevel(category, level), isNotEmpty);
        }
      }
    });
  });

  group('column mapping', () {
    test('maps each category to its progress column', () {
      expect(engine.columnFor(PuzzleCategory.math), 'math_level');
      expect(engine.columnFor(PuzzleCategory.english), 'english_level');
      expect(engine.columnFor(PuzzleCategory.cognitive), 'cognitive_level');
    });
  });
}
