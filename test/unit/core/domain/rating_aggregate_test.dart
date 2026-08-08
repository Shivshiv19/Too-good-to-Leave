import 'package:flutter_test/flutter_test.dart';
import 'package:surplus_marketplace/core/domain/rating_aggregate.dart';

void main() {
  group('RatingAggregate', () {
    test('empty() has no reviews and a zero histogram', () {
      final aggregate = RatingAggregate.empty();
      expect(aggregate.hasReviews, isFalse);
      expect(aggregate.count, 0);
      for (var star = 1; star <= 5; star++) {
        expect(aggregate.histogramPercent(star), 0);
      }
    });

    test('hasReviews is true once count is positive', () {
      const aggregate = RatingAggregate(
        average: 4.5,
        count: 10,
        histogram: {1: 0, 2: 0, 3: 0, 4: 2, 5: 8},
      );
      expect(aggregate.hasReviews, isTrue);
    });

    test('histogramPercent computes the share of reviews at each star', () {
      const aggregate = RatingAggregate(
        average: 4.5,
        count: 10,
        histogram: {1: 0, 2: 0, 3: 0, 4: 2, 5: 8},
      );
      expect(aggregate.histogramPercent(5), 80);
      expect(aggregate.histogramPercent(4), 20);
      expect(aggregate.histogramPercent(1), 0);
    });

    test('equality is by value, including the histogram contents', () {
      const a = RatingAggregate(average: 4, count: 1, histogram: {5: 1});
      const b = RatingAggregate(average: 4, count: 1, histogram: {5: 1});
      final c = RatingAggregate(average: 4, count: 1, histogram: const {4: 1});
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == c, isFalse);
    });
  });
}
