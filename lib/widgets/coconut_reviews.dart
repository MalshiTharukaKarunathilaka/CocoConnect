import 'package:flutter/material.dart';
import '../services/coconut_review_service.dart';
import 'buyer_widgets.dart';

class CoconutReviewsSection extends StatelessWidget {
  final CoconutReviews reviews;
  final bool showScore;

  const CoconutReviewsSection({
    super.key,
    required this.reviews,
    this.showScore = true,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (showScore) ...[
        Text('Trust Score', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          reviews.average == null
              ? 'Not rated yet'
              : '${reviews.average!.toStringAsFixed(1)} / 5.0',
          style: const TextStyle(
            color: kBuyerGreenDark,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text('${reviews.count} received coconut order ratings'),
        const SizedBox(height: 12),
      ],
      Text(
        'Comments from coconut orders',
        style: Theme.of(context).textTheme.titleSmall,
      ),
      const SizedBox(height: 6),
      if (reviews.comments.isEmpty) const Text('No comments yet'),
      for (final review in reviews.comments) ...[
        const Divider(height: 20),
        Text(
          '${review.stars} / 5 stars',
          style: const TextStyle(
            color: kBuyerGreenDark,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(review.comment),
      ],
    ],
  );
}

class MyCoconutReviews extends StatefulWidget {
  final bool showScore;

  const MyCoconutReviews({super.key, this.showScore = true});

  @override
  State<MyCoconutReviews> createState() => _MyCoconutReviewsState();
}

class _MyCoconutReviewsState extends State<MyCoconutReviews> {
  late Future<CoconutReviews> _reviews = CoconutReviews.loadMine();

  @override
  Widget build(BuildContext context) => FutureBuilder<CoconutReviews>(
    future: _reviews,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Could not load coconut reviews'),
          trailing: TextButton(
            onPressed: () => setState(() => _reviews = CoconutReviews.loadMine()),
            child: const Text('Retry'),
          ),
        );
      }
      return CoconutReviewsSection(
        reviews: snapshot.data!,
        showScore: widget.showScore,
      );
    },
  );
}
