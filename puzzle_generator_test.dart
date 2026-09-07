import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mindgate/models/puzzle.dart';
import 'package:mindgate/services/puzzle_generator.dart';

/// The generator produces puzzles at runtime, so its invariants cannot be
/// eyeballed the way the handcrafted set can. These tests hammer every category
/// at every level and assert the contract the UI depends on.
void main() {
  group('generated puzzles hold their contract', () {
    test('four distinct options with a valid correct index, at every level', () {
      // Fixed seed keeps failures reproducible; the loop count is high enough
      // to exercise the rare branches (exact-division fallbacks, letter-range
      // clamping, distractor collisions).
      final generator = PuzzleGenerator(random: Random(20260728));

      for (final category in PuzzleCategory.values) {
        for (var level = 1; level <= 10; level++) {
          for (var i = 0; i < 200; i++) {
            final puzzle = generator.generate(category: category, difficulty: level);
            final context = '${category.id} L$level → "${puzzle.question}" '
                '${puzzle.options}';

            expect(puzzle.options, hasLength(4), reason: context);
            expect(puzzle.options.toSet(), hasLength(4), reason: 'Duplicate: $context');
            expect(puzzle.correctIndex, inInclusiveRange(0, 3), reason: context);
            expect(puzzle.category, category, reason: context);
            expect(puzzle.isGenerated, isTrue, reason: context);

            for (final option in puzzle.options) {
              expect(option.trim(), isNotEmpty, reason: context);
            }
          }
        }
      }
    });

    // Swept across several seeds rather than one. The subtraction branches of
    // the two-step and order-of-operations generators used to be able to reach
    // zero — "3 × 4 − 12 = ?" answers 0, and the padding in _numeric then fills
    // the option list with 1 and 2, which gives the answer away by shape. One
    // seed happened to expose it; a different one would not have.
    test('numeric answers are never negative or zero', () {
      for (final seed in [7, 20260728, 1, 99, 12345]) {
        final generator = PuzzleGenerator(random: Random(seed));

        for (var level = 1; level <= 10; level++) {
          for (var i = 0; i < 200; i++) {
            final puzzle = generator.generate(
              category: PuzzleCategory.math,
              difficulty: level,
            );

            for (final option in puzzle.options) {
              final value = num.tryParse(option);
              if (value != null) {
                expect(
                  value,
                  greaterThan(0),
                  reason: 'seed $seed — non-positive option in '
                      '"${puzzle.question}": ${puzzle.options}',
                );
              }
            }
          }
        }
      }
    });

    test('clamps out-of-range difficulty instead of throwing', () {
      final generator = PuzzleGenerator(random: Random(1));

      for (final level in [-5, 0, 11, 99]) {
        for (final category in PuzzleCategory.values) {
          final puzzle = generator.generate(category: category, difficulty: level);
          expect(puzzle.options, hasLength(4));
        }
      }
    });
  });

  group('math ladder', () {
    test('levels 1–4 generate the operation the brief specifies', () {
      final generator = PuzzleGenerator(random: Random(42));

      const expected = {
        1: PuzzleType.addition,
        2: PuzzleType.subtraction,
        3: PuzzleType.multiplication,
        4: PuzzleType.division,
      };

      for (final entry in expected.entries) {
        for (var i = 0; i < 25; i++) {
          final puzzle = generator.generate(
            category: PuzzleCategory.math,
            difficulty: entry.key,
          );
          expect(puzzle.type, entry.value, reason: 'level ${entry.key}');
        }
      }
    });

    test('addition and subtraction answers are arithmetically right', () {
      final generator = PuzzleGenerator(random: Random(99));

      for (var i = 0; i < 300; i++) {
        for (final level in [1, 2]) {
          final puzzle = generator.generate(
            category: PuzzleCategory.math,
            difficulty: level,
          );

          // Questions look like "12 + 7 = ?" or "40 − 13 = ?".
          final match = RegExp(r'^(\d+) ([+−]) (\d+) = \?$').firstMatch(puzzle.question);
          expect(match, isNotNull, reason: puzzle.question);

          final a = int.parse(match!.group(1)!);
          final b = int.parse(match.group(3)!);
          final expected = match.group(2) == '+' ? a + b : a - b;

          expect(
            int.parse(puzzle.correctAnswer),
            expected,
            reason: '${puzzle.question} marked ${puzzle.correctAnswer}',
          );
        }
      }
    });

    test('division is always exact', () {
      final generator = PuzzleGenerator(random: Random(1234));

      for (var i = 0; i < 300; i++) {
        final puzzle = generator.generate(
          category: PuzzleCategory.math,
          difficulty: 4,
        );

        final match = RegExp(r'^(\d+) ÷ (\d+) = \?$').firstMatch(puzzle.question);
        expect(match, isNotNull, reason: puzzle.question);

        final dividend = int.parse(match!.group(1)!);
        final divisor = int.parse(match.group(2)!);

        expect(dividend % divisor, 0, reason: puzzle.question);
        expect(int.parse(puzzle.correctAnswer), dividend ~/ divisor);
      }
    });
  });
}
