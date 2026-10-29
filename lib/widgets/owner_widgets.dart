import 'dart:async';
import 'package:flutter/material.dart';
import '../screens/buyer/buyer_format.dart';
import '../services/owner_service.dart';

// Estate owner palette, taken from the Figma designs.
const Color kOwnerGreen = Color(0xFF256B45);
const Color kOwnerGreenSoft = Color(0xFFE3F0E6);
const Color kOwnerCream = Color(0xFFFCF8EF);
const Color kOwnerInk = Color(0xFF1E2A22);
const Color kOwnerMuted = Color(0xFF6B7280);
const Color kOwnerBorder = Color(0xFFE5E7EB);
const Color kOwnerPanel = Color(0xFFF1EFEA);
const Color kOwnerRed = Color(0xFFC62828);
const Color kOwnerBrown = Color(0xFF8B4A1C);

/// The phone-width cream page every estate owner screen sits in.
class OwnerPage extends StatelessWidget {
  final Widget child;
  final Widget? bottom;

  const OwnerPage({super.key, required this.child, this.bottom});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFEFEF),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Center(
          child: Container(
            width: 390,
            height: double.infinity,
            color: kOwnerCream,
            child: SafeArea(
              child: Column(
                children: [
                  Expanded(child: child),
                  ?bottom,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Back arrow, centred title and optional actions on the right.
class OwnerHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final bool showBack;

  const OwnerHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.showBack = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEDE7DA))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: showBack && Navigator.of(context).canPop()
                ? IconButton(
                    icon: const Icon(Icons.arrow_back, color: kOwnerInk),
                    onPressed: () => Navigator.pop(context),
                  )
                : null,
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: kOwnerGreen,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: kOwnerMuted,
                      letterSpacing: 0.4,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 48.0 * (actions.isEmpty ? 1 : actions.length),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: actions,
            ),
          ),
        ],
      ),
    );
  }
}

class OwnerCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const OwnerCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kOwnerBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

enum PillTone { green, red, neutral }

class OwnerPill extends StatelessWidget {
  final String text;
  final IconData? icon;
  final PillTone tone;

  const OwnerPill(
    this.text, {
    super.key,
    this.icon,
    this.tone = PillTone.green,
  });

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, Color border) = switch (tone) {
      PillTone.green => (kOwnerGreenSoft, kOwnerGreen, const Color(0xFFBFDCC6)),
      PillTone.red => (
        const Color(0xFFFDECEC),
        kOwnerRed,
        const Color(0xFFF5C2C2),
      ),
      PillTone.neutral => (
        const Color(0xFFF1F1EF),
        const Color(0xFF555555),
        kOwnerBorder,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// Grey box with "Quantity | Price" side by side.
class QuantityPriceBox extends StatelessWidget {
  final int quantity;
  final double pricePerUnit;

  const QuantityPriceBox({
    super.key,
    required this.quantity,
    required this.pricePerUnit,
  });

  @override
  Widget build(BuildContext context) {
    TextSpan unit(String text) => TextSpan(
      text: text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: kOwnerMuted,
      ),
    );

    Widget half(String label, InlineSpan value, {bool right = false}) =>
        Expanded(
          child: Column(
            crossAxisAlignment: right
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11.5, color: kOwnerMuted),
              ),
              const SizedBox(height: 4),
              Text.rich(
                value,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: kOwnerGreen,
                ),
              ),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: kOwnerPanel,
        borderRadius: BorderRadius.circular(10),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            half(
              'Quantity',
              TextSpan(text: withCommas(quantity), children: [unit(' nuts')]),
            ),
            const VerticalDivider(width: 24, color: Color(0xFFD6D3CC)),
            half(
              'Price',
              TextSpan(text: rupees(pricePerUnit), children: [unit('/nut')]),
              right: true,
            ),
          ],
        ),
      ),
    );
  }
}

/// "LIVE DEAL  Deal Closed: 2,500 Nuts at Rs. 128.00/nut" plus the
/// average price, from real orders across all estates.
class MarketPulse extends StatefulWidget {
  final String productType;

  const MarketPulse({super.key, this.productType = 'RAW_COCONUT'});

  @override
  State<MarketPulse> createState() => _MarketPulseState();
}

class _MarketPulseState extends State<MarketPulse> {
  /// How often the strip checks for newly closed deals.
  static const Duration _interval = Duration(seconds: 15);

  MarketStats? _stats;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(_interval, (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final MarketStats stats = await OwnerService.getMarketStats(
        widget.productType,
      );
      if (mounted) setState(() => _stats = stats);
    } catch (_) {
      // Keep showing the last figures; try again on the next tick.
    }
  }

  @override
  Widget build(BuildContext context) {
    final MarketStats? stats = _stats;
    // Quietly skip while loading, on error, or before any deal exists.
    if (stats == null || stats.lastDealQuantity == null) {
      return const SizedBox.shrink();
    }

    final double? average = stats.avgDayPrice;
    final String orders = stats.avgDayOrderCount == 1
        ? '1 order'
        : '${stats.avgDayOrderCount} orders';
    final String averageLabel = stats.avgDayIsToday
        ? "Today's Avg Price"
        : 'Avg Price for ${shortDate(stats.avgDay)}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF6D6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFF2D675)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2681F),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 7, color: Color(0xFFFFE08A)),
                      SizedBox(width: 4),
                      Text(
                        'LIVE DEAL',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: 'Deal Closed: ',
                      children: [
                        TextSpan(
                          text: '${withCommas(stats.lastDealQuantity!)} Nuts',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const TextSpan(text: ' at '),
                        TextSpan(
                          text:
                              'Rs. ${stats.lastDealPrice!.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: kOwnerGreen,
                          ),
                        ),
                        const TextSpan(text: '/nut'),
                      ],
                    ),
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF4A3B10),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Average of the orders customers need on that day.
          if (average != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.trending_up, size: 15, color: kOwnerBrown),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    '$averageLabel: Rs. ${average.toStringAsFixed(2)} / nut'
                    '  ($orders)',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: kOwnerBrown,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Primary green full-width button with an optional trailing arrow.
class OwnerPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool arrow;

  const OwnerPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.arrow = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: kOwnerGreen,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFB8C9BE),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            if (arrow) ...[
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward, size: 18),
            ],
          ],
        ),
      ),
    );
  }
}

/// Segmented-pill tabs used by Deal Window and My Sell Requests.
class OwnerTabs extends StatelessWidget {
  final List<String> labels;
  final List<int> badges;
  final int selected;
  final ValueChanged<int> onSelected;

  const OwnerTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
    this.badges = const [],
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (int i = 0; i < labels.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () => onSelected(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: i == selected ? kOwnerGreen : Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: i == selected
                          ? kOwnerGreen
                          : const Color(0xFFBDBDBD),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        labels[i],
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: i == selected ? Colors.white : kOwnerInk,
                        ),
                      ),
                      if (i < badges.length && badges[i] > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDDCDC),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${badges[i]}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: kOwnerRed,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Spinner / error / empty states shared by the owner lists.
class OwnerMessage extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onRetry;

  const OwnerMessage({
    super.key,
    required this.icon,
    required this.text,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 20),
      child: Column(
        children: [
          Icon(icon, size: 34, color: kOwnerMuted),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: kOwnerMuted,
            ),
          ),
          if (onRetry != null)
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh'),
              style: TextButton.styleFrom(foregroundColor: kOwnerGreen),
            ),
        ],
      ),
    );
  }
}

/// The dashed line above a card's total, as in the Deal Window design.
class DashedDivider extends StatelessWidget {
  const DashedDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final int dashes = (constraints.maxWidth / 8).floor();
          return Row(
            children: [
              for (int i = 0; i < dashes; i++)
                Expanded(
                  child: Container(
                    height: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    color: const Color(0xFFD9D6CF),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Photo card for a product category, used on the buyer's and estate
/// owner's category screens alike.
class CategoryImageCard extends StatelessWidget {
  final String title;
  final String imageUrl;
  final String? trailing;
  final VoidCallback? onTap;

  const CategoryImageCard({
    super.key,
    required this.title,
    required this.imageUrl,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            SizedBox(
              height: 130,
              width: double.infinity,
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                // Wikimedia asks apps to say who they are.
                headers: const {
                  'User-Agent': 'CocoConnect/1.0 (university project)',
                },
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : const ColoredBox(color: Color(0xFFF1F1EC)),
                errorBuilder: (context, error, stackTrace) => const ColoredBox(
                  color: Color(0xFFE8F5E9),
                  child: Center(
                    child: Icon(Icons.image, size: 40, color: kOwnerGreen),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.arrow_forward,
                    size: 18,
                    color: Color(0xFF1B5E20),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B5E20),
                      ),
                    ),
                  ),
                  if (trailing != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: kOwnerGreenSoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        trailing!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: kOwnerGreen,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
