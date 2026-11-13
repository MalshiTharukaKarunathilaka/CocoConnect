import 'package:flutter/material.dart';

enum JobCategory { general, nut, machine }

extension JobCategoryX on JobCategory {
  String get label => switch (this) {
        JobCategory.general => 'General Work',
        JobCategory.nut => 'Nut Gatherer',
        JobCategory.machine => 'Machine Work',
      };

  IconData get icon => switch (this) {
        JobCategory.general => Icons.handyman_outlined,
        JobCategory.nut => Icons.park_outlined,
        JobCategory.machine => Icons.agriculture_outlined,
      };
}

class Worker {
  final String name;
  final String district;
  final double rating;
  final int ratingCount;
  final bool verified;
  const Worker({
    required this.name,
    required this.district,
    required this.rating,
    required this.ratingCount,
    required this.verified,
  });
}

class Estate {
  final String id;
  final String name;
  final String initials;
  final String owner;
  final String district;
  final double distanceKm;
  final bool everyDay;
  const Estate({
    required this.id,
    required this.name,
    required this.initials,
    required this.owner,
    required this.district,
    required this.distanceKm,
    required this.everyDay,
  });
}

class Job {
  final String id;
  final String estateId;
  final JobCategory category;
  final String title;
  final String description;
  final int rate;
  final int capacity;

  /// Workers already accepted by OTHER people. The current worker's own
  /// acceptance is added on top by the app.
  final int baseAccepted;
  final String duration;
  const Job({
    required this.id,
    required this.estateId,
    required this.category,
    required this.title,
    required this.description,
    required this.rate,
    required this.capacity,
    required this.baseAccepted,
    required this.duration,
  });
}

enum Sender { worker, owner }

class ChatMessage {
  final Sender from;
  final String text;
  const ChatMessage(this.from, this.text);
}
