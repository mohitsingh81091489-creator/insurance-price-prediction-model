import 'package:flutter_test/flutter_test.dart';
import 'package:mindgate/database/seed/puzzle_seed_data.dart';
import 'package:mindgate/models/puzzle.dart';

/// Content integrity tests for the 100 handcrafted puzzles.
///
/// Worth having because puzzle data is the one part of the app where a typo is
/// invisible in code review and only shows up as a user being told they are
/// wrong when they are right — the single most trust-destroying bug this app
/// could ship.
void main() {
  group('seed data shape', () {
    test('ships exactly 100 puzzles, split 40/30/30', () {
      expect(PuzzleSeedData.all, hasLength(100));
      expect(PuzzleSeedData.math, hasLength(40));
      expect(PuzzleSeedData.english, hasLength(30));
      expect(PuzzleSeedData.cognitive, hasLength(30));
    });

    test('each list only contains puzzles of its own category', () {
      for (final puzzle in PuzzleSeedData.math) {
        expect(puzzle.category, PuzzleCategory.math, reason: puzzle.question);
      }
      for (final puzzle in PuzzleSeedData.english) {
        expect(puzzle.category, PuzzleCategory.english, reason: puzzle.question);
      }
      for (final puzzle in PuzzleSeedData.cognitive) {
        expect(puzzle.category, PuzzleCategory.cognitive, reason: puzzle.question);
      }
    });
  });

  group('every puzzle is well formed', () {
    test('has four distinct, non-empty options', () {
      for (final puzzle in PuzzleSeedData.all) {
        expect(puzzle.options, hasLength(4), reason: puzzle.question);
        expect(
          puzzle.options.toSet(),
          hasLength(4),
          reason: 'Duplicate option in: ${puzzle.question}',
        );
        for (final option in puzzle.options) {
          expect(option.trim(), isNotEmpty, reason: puzzle.question);
        }
      }
    });

    test('correctIndex points at a real option', () {
      for (final puzzle in PuzzleSeedData.all) {
        expect(puzzle.correctIndex, inInclusiveRange(0, 3), reason: puzzle.question);
        expect(puzzle.correctAnswer, isNotEmpty, reason: puzzle.question);
      }
    });

    test('difficulty sits in the 1–10 range', () {
      for (final puzzle in PuzzleSeedData.all) {
        expect(puzzle.difficulty, inInclusiveRange(1, 10), reason: puzzle.question);
      }
    });

    test('target solve time stays inside the 5–10 second design goal', () {
      for (final puzzle in PuzzleSeedData.all) {
        expect(
          puzzle.targetSeconds,
          inInclusiveRange(5, 10),
          reason: '${puzzle.question} targets ${puzzle.targetSeconds}s',
        );
      }
    });

    test('questions are unique', () {
      final questions = PuzzleSeedData.all.map((p) => p.question).toList();
      expect(questions.toSet(), hasLength(questions.length));
    });

    test('memory puzzles carry a payload and nothing else does', () {
      for (final puzzle in PuzzleSeedData.all) {
        if (puzzle.type == PuzzleType.memoryRecall) {
          expect(puzzle.memoryPayload, isNotNull, reason: puzzle.question);
          expect(puzzle.memoryPayload!.trim(), isNotEmpty);
          expect(puzzle.isMemoryPuzzle, isTrue);
        } else {
          expect(puzzle.memoryPayload, isNull, reason: puzzle.question);
        }
      }
    });
  });

  group('difficulty ladder', () {
    test('math follows the brief: add → subtract → multiply → divide', () {
      Set<PuzzleType> typesAtLevel(int level) => PuzzleSeedData.math
          .where((p) => p.difficulty == level)
          .map((p) => p.type)
          .toSet();

      expect(typesAtLevel(1), {PuzzleType.addition});
      expect(typesAtLevel(2), {PuzzleType.subtraction});
      expect(typesAtLevel(3), {PuzzleType.multiplication});
      expect(typesAtLevel(4), {PuzzleType.division});
    });

    test('english starts with common words then synonyms and antonyms', () {
      Set<PuzzleType> typesAtLevel(int level) => PuzzleSeedData.english
          .where((p) => p.difficulty == level)
          .map((p) => p.type)
          .toSet();

      expect(typesAtLevel(1), {PuzzleType.commonWord});
      expect(typesAtLevel(2), {PuzzleType.synonym});
      expect(typesAtLevel(3), {PuzzleType.antonym});
      expect(typesAtLevel(4), {PuzzleType.vocabulary});
    });

    test('every category covers levels 1 through 4 at minimum', () {
      for (final category in PuzzleCategory.values) {
        final levels = PuzzleSeedData.all
            .where((p) => p.category == category)
            .map((p) => p.difficulty)
            .toSet();

        for (var level = 1; level <= 4; level++) {
          expect(
            levels,
            contains(level),
            reason: '${category.label} has no level $level puzzle',
          );
        }
      }
    });
  });

  group('answer spot checks', () {
    // A representative slice verified by hand. If a distractor is ever edited
    // into the correct slot, one of these fails loudly.
    const expected = <String, String>{
      '7 + 6 = ?': '13',
      '84 − 46 = ?': '38',
      '12 × 7 = ?': '84',
      '126 ÷ 6 = ?': '21',
      '17 + 8 × 2 = ?': '33',
      '12.5% of 200 = ?': '25',
      '(5 + 3)² ÷ 8 = ?': '8',
      'If 2x − 5 = 17, then x = ?': '11',
    };

    test('known math answers are still correct', () {
      for (final entry in expected.entries) {
        final puzzle = PuzzleSeedData.math.firstWhere(
          (p) => p.question == entry.key,
          orElse: () => fail('Missing puzzle: ${entry.key}'),
        );
        expect(puzzle.correctAnswer, entry.value, reason: entry.key);
      }
    });
  });

  group('shuffling', () {
    test('keeps correctIndex pointing at the same answer', () {
      for (final puzzle in PuzzleSeedData.all) {
        final shuffled = puzzle.shuffled();
        expect(shuffled.options.toSet(), puzzle.options.toSet());
        expect(shuffled.correctAnswer, puzzle.correctAnswer, reason: puzzle.question);
        expect(shuffled.options, hasLength(4));
      }
    });
  });
}
