import 'package:flutter/material.dart';

/// Web-safe fallback: local filesystem paths cannot be read directly on web.
Widget buildLocalImage(
  BuildContext context,
  String path, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
}) {
  return SizedBox(
    width: width,
    height: height,
    child: Center(
      child: Icon(Icons.image_not_supported, color: Theme.of(context).disabledColor),
    ),
  );
}
