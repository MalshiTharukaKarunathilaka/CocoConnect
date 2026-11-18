import 'package:flutter/material.dart';

/// Keeps a sheet above the keyboard and gives its content the usable viewport.
/// Clearing the inherited inset prevents individual forms from applying it twice.
WidgetBuilder mobileSheetBuilder(WidgetBuilder builder) => (context) {
  final media = MediaQuery.of(context);
  final keyboard = media.viewInsets.bottom;
  final height = (media.size.height - keyboard).clamp(0.0, media.size.height);
  return Padding(
    padding: EdgeInsets.only(bottom: keyboard),
    child: MediaQuery(
      data: media.copyWith(
        viewInsets: EdgeInsets.zero,
        size: Size(media.size.width, height),
      ),
      child: Builder(builder: builder),
    ),
  );
};
