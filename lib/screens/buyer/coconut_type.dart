import 'package:flutter/material.dart';

/// One sellable coconut form. The marketplace, request and negotiation
/// screens are all driven by this, so the three types share a single
/// implementation instead of duplicated screens.
class CoconutType {
  /// Value stored in the database's product_type column - "RAW_COCONUT".
  final String code;

  /// Plural label used in headings - "Raw Coconuts".
  final String label;

  /// Singular form used in body copy - "Raw coconut".
  final String singular;

  /// Short description shown on the selection card.
  final String subtitle;

  /// Value shown against "Husk" in the produce details.
  final String husk;

  final IconData icon;
  final Color iconColor;

  /// Indicative price per nut, in rupees. Processed forms fetch more.
  final int pricePerNut;

  const CoconutType({
    required this.code,
    required this.label,
    required this.singular,
    required this.subtitle,
    required this.husk,
    required this.icon,
    required this.iconColor,
    required this.pricePerNut,
  });

  static const CoconutType raw = CoconutType(
    code: 'RAW_COCONUT',
    label: 'Raw Coconuts',
    singular: 'Raw coconut',
    subtitle: 'Whole nuts, husk intact',
    husk: 'Unhusked',
    icon: Icons.park,
    iconColor: Color(0xFF3B8F65),
    pricePerNut: 130,
  );

  static const CoconutType husked = CoconutType(
    code: 'HUSKED_COCONUT',
    label: 'Husked Coconuts',
    singular: 'Husked coconut',
    subtitle: 'Husk partially removed',
    husk: 'Partially husked',
    icon: Icons.spa,
    iconColor: Color(0xFFB26A2C),
    pricePerNut: 145,
  );

  static const CoconutType dehusked = CoconutType(
    code: 'DEHUSKED_COCONUT',
    label: 'Dehusked Coconuts',
    singular: 'Dehusked coconut',
    subtitle: 'Husk fully removed',
    husk: 'Fully dehusked',
    icon: Icons.egg_outlined,
    iconColor: Color(0xFF8D6E4A),
    pricePerNut: 160,
  );

  static const List<CoconutType> all = [raw, husked, dehusked];

  /// Falls back to raw for product types this app doesn't know about.
  static CoconutType fromCode(String? code) => all.firstWhere(
    (type) => type.code == code?.toUpperCase(),
    orElse: () => raw,
  );
}
