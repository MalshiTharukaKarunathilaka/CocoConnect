import 'package:flutter/material.dart';
import '../../services/coconut_review_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/buyer_widgets.dart';
import '../../widgets/coconut_reviews.dart';

Future<void> openCoconutCounterpartProfile(
  BuildContext context, {
  required String name,
  required String profilePath,
}) => Navigator.push<void>(
  context,
  MaterialPageRoute(
    builder: (_) =>
        CoconutCounterpartProfilePage(name: name, profilePath: profilePath),
  ),
);

class CoconutCounterpartProfilePage extends StatefulWidget {
  final String profilePath;
  final String name;

  const CoconutCounterpartProfilePage({
    super.key,
    required this.profilePath,
    required this.name,
  });

  @override
  State<CoconutCounterpartProfilePage> createState() =>
      _CoconutCounterpartProfilePageState();
}

class _CoconutCounterpartProfilePageState
    extends State<CoconutCounterpartProfilePage> {
  late Future<CoconutCounterpartProfile> _profile =
      CoconutCounterpartProfile.load(widget.profilePath);

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFEFEFEF),
    body: Center(
      child: SizedBox(
        width: AppTheme.sheetConstraints.maxWidth,
        child: ColoredBox(
          color: kBuyerCream,
          child: SafeArea(
            child: Column(
              children: [
                SizedBox(
                  height: kToolbarHeight,
                  child: AppBar(
                    primary: false,
                    title: Text(widget.name, overflow: TextOverflow.ellipsis),
                    automaticallyImplyLeading: false,
                    actions: [
                      IconButton(
                        tooltip: 'Close profile',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Expanded(child: _profileBody()),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _profileBody() => FutureBuilder<CoconutCounterpartProfile>(
    future: _profile,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(
          child: TextButton(
            onPressed: () => setState(() {
              _profile = CoconutCounterpartProfile.load(widget.profilePath);
            }),
            child: const Text('Could not load profile. Retry'),
          ),
        );
      }
      final profile = snapshot.data!;
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          BuyerCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.name.isEmpty ? widget.name : profile.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(profile.isLandOwner ? 'Land Owner' : 'Buyer'),
                if (profile.estateName case final estate?
                    when estate.isNotEmpty && estate != profile.name)
                  Text(estate),
                if (profile.location case final location?
                    when location.isNotEmpty)
                  Text(location),
              ],
            ),
          ),
          const SizedBox(height: 12),
          BuyerCard(child: CoconutReviewsSection(reviews: profile.reviews)),
        ],
      );
    },
  );
}

class CoconutProfileLink extends StatelessWidget {
  final String name;
  final double? trustScore;
  final String profilePath;

  const CoconutProfileLink({
    super.key,
    required this.name,
    required this.trustScore,
    required this.profilePath,
  });

  @override
  Widget build(BuildContext context) {
    final score = trustScore?.toStringAsFixed(1);
    return InkWell(
      onTap: () => openCoconutCounterpartProfile(
        context,
        name: name,
        profilePath: profilePath,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: kBuyerGreenDark,
              ),
            ),
            Text(
              score == null ? 'Not rated yet' : '★ $score/5',
              semanticsLabel: score == null
                  ? 'Trust score: not rated yet'
                  : 'Trust score: $score out of 5',
              style: const TextStyle(fontSize: 12, color: kBuyerGrey),
            ),
          ],
        ),
      ),
    );
  }
}
