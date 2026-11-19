import 'package:flutter/material.dart';

/// Keeps a sheet above the keyboard and gives its content the usable viewport.
/// Clearing the inherited inset prevents individual forms from applying it twice.
WidgetBuilder mobileSheetBuilder(WidgetBuilder builder) => (context) {
  final media = MediaQuery.of(context);
  final keyboard = media.viewInsets.bottom;
  return Padding(
    padding: EdgeInsets.only(bottom: keyboard),
    child: SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(viewInsets: EdgeInsets.zero, size: constraints.biggest),
          child: Builder(builder: builder),
        ),
      ),
    ),
  );
};
