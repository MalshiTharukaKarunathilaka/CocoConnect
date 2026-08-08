import 'package:flutter/material.dart';

const Color kBuyerGreen = Color(0xFF2E7D32);
const Color kBuyerGreenDark = Color(0xFF14432A);
const Color kBuyerBrown = Color(0xFFB26A2C);
const Color kBuyerCream = Color(0xFFFDF9F1);
const Color kBuyerGrey = Color(0xFF777777);
const Color kBuyerBorder = Color(0xFFEDE6DA);
const Color kBuyerFieldFill = Color(0xFFF8F6F1);

class BuyerScaffold extends StatelessWidget {
  final Widget body;
  final Widget? bottomNavigation;

  const BuyerScaffold({
    super.key,
    required this.body,
    this.bottomNavigation,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFEFEF),
      body: Center(
        child: Container(
          width: 390,
          height: double.infinity,
          color: kBuyerCream,
          child: SafeArea(
            child: Column(
              children: [
                Expanded(child: body),
                ?bottomNavigation,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BuyerBottomNavigation extends StatelessWidget {
  final int currentIndex;

  const BuyerBottomNavigation({
    super.key,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        color: kBuyerCream,
        border: Border(top: BorderSide(color: kBuyerBorder)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          BuyerNavItem(
            icon: Icons.dashboard,
            label: 'DASHBOARD',
            isActive: currentIndex == 0,
          ),
          BuyerNavItem(
            icon: Icons.assignment,
            label: 'ORDERS',
            isActive: currentIndex == 1,
          ),
          BuyerNavItem(
            icon: Icons.person,
            label: 'PROFILE',
            isActive: currentIndex == 2,
          ),
        ],
      ),
    );
  }
}

class BuyerNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;

  const BuyerNavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final Color color = isActive ? kBuyerGreen : kBuyerGrey;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class BuyerCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const BuyerCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

class BuyerFieldLabel extends StatelessWidget {
  final String text;

  const BuyerFieldLabel({
    super.key,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF5A5A5A),
        ),
      ),
    );
  }
}

class BuyerInputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final Widget? prefix;
  final Widget? suffix;
  final TextInputType keyboardType;
  final bool readOnly;
  final VoidCallback? onTap;

  const BuyerInputField({
    super.key,
    required this.controller,
    required this.hint,
    this.prefix,
    this.suffix,
    this.keyboardType = TextInputType.text,
    this.readOnly = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
      onTap: onTap,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 14, color: Color(0xFFAAAAAA)),
        prefixIcon: prefix,
        suffixIcon: suffix,
        prefixIconConstraints: const BoxConstraints(minWidth: 42),
        filled: true,
        fillColor: kBuyerFieldFill,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kBuyerBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kBuyerGreen),
        ),
      ),
    );
  }
}

class BuyerPrimaryButton extends StatelessWidget {
  final String label;
  final IconData? trailingIcon;
  final Color color;
  final VoidCallback? onPressed;

  const BuyerPrimaryButton({
    super.key,
    required this.label,
    this.trailingIcon,
    this.color = kBuyerGreen,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (trailingIcon != null) ...[
              const SizedBox(width: 8),
              Icon(trailingIcon, size: 18),
            ],
          ],
        ),
      ),
    );
  }
}

class BuyerOutlinedButton extends StatelessWidget {
  final String label;
  final IconData? leadingIcon;
  final VoidCallback? onPressed;

  const BuyerOutlinedButton({
    super.key,
    required this.label,
    this.leadingIcon,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF3A3A3A),
          side: const BorderSide(color: kBuyerBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (leadingIcon != null) ...[
              Icon(leadingIcon, size: 18, color: kBuyerGreen),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Stacked label above value, as used for QUANTITY / REQUIRED DATE columns.
class BuyerInfoPair extends StatelessWidget {
  final String label;
  final String value;

  const BuyerInfoPair({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: kBuyerGrey,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
      ],
    );
  }
}

class BuyerPill extends StatelessWidget {
  final String text;
  final Color background;
  final Color foreground;
  final IconData? icon;
  final double fontSize;

  const BuyerPill({
    super.key,
    required this.text,
    required this.background,
    required this.foreground,
    this.icon,
    this.fontSize = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: foreground),
            const SizedBox(width: 5),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: foreground,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class EstateListingCard extends StatelessWidget {
  final String initial;
  final Color initialBackground;
  final String estateName;
  final String ownerName;
  final String price;
  final String trustScore;
  final String quantity;
  final String availableDate;
  final VoidCallback? onTap;

  const EstateListingCard({
    super.key,
    required this.initial,
    required this.initialBackground,
    required this.estateName,
    required this.ownerName,
    required this.price,
    required this.trustScore,
    required this.quantity,
    required this.availableDate,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BuyerCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: initialBackground,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3A3A3A),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      estateName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ownerName,
                      style: const TextStyle(
                        fontSize: 11,
                        color: kBuyerGrey,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          size: 12,
                          color: kBuyerGreen,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'VERIFIED OFFER PRICE',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: kBuyerGreen,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              BuyerPill(
                text: price,
                background: const Color(0xFFDDEEE0),
                foreground: kBuyerGreen,
                fontSize: 12,
              ),
            ],
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              const Icon(Icons.star, size: 14, color: Color(0xFFE0A526)),
              const SizedBox(width: 5),
              Text(
                'Trust Score: $trustScore',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF3A3A3A),
                ),
              ),
            ],
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: kBuyerBorder),
          ),

          Row(
            children: [
              Expanded(
                child: BuyerInfoPair(label: 'QUANTITY', value: quantity),
              ),
              Expanded(
                child: BuyerInfoPair(label: 'AVAILABLE', value: availableDate),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class BuyerCategoryCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onTap;

  const BuyerCategoryCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BuyerCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFF1F1EC),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 22, color: iconColor),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: kBuyerGrey,
            ),
          ),
        ],
      ),
    );
  }
}

class NegotiationBubble extends StatelessWidget {
  final String message;
  final String time;
  final bool isMine;

  const NegotiationBubble({
    super.key,
    required this.message,
    required this.time,
    required this.isMine,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 260),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isMine ? kBuyerGreen : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: isMine ? null : Border.all(color: kBuyerBorder),
          ),
          child: Text(
            message,
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              color: isMine ? Colors.white : const Color(0xFF3A3A3A),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          time,
          style: const TextStyle(fontSize: 10, color: kBuyerGrey),
        ),
      ],
    );
  }
}
