import 'package:clipious/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('useWideLayoutForSize', () {
    test('compact portrait phone stays phone', () {
      expect(useWideLayoutForSize(const Size(360, 800)), isFalse);
    });

    test('533dp tablet portrait stays compact', () {
      expect(useWideLayoutForSize(const Size(533, 853)), isFalse);
    });

    test('533dp tablet landscape uses the wide layout', () {
      expect(useWideLayoutForSize(const Size(853, 533)), isTrue);
    });

    test('600dp+ tablet uses the wide layout in portrait', () {
      expect(useWideLayoutForSize(const Size(600, 960)), isTrue);
      expect(useWideLayoutForSize(const Size(1280, 800)), isTrue);
    });

    test('wide-but-short phone landscape stays compact', () {
      expect(useWideLayoutForSize(const Size(800, 360)), isFalse);
    });

    test('foldable-sized window uses the wide layout', () {
      expect(useWideLayoutForSize(const Size(720, 800)), isTrue);
    });
  });
}
