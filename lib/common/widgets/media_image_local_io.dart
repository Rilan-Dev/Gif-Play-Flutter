import 'dart:io';

import 'package:flutter/material.dart';

/// Native-platform renderer for a local filesystem path.
Widget buildLocalImage(
  BuildContext context,
  String path, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
}) {
  return Image.file(
    File(path),
    width: width,
    height: height,
    fit: fit,
    errorBuilder: (context, error, stackTrace) => Center(
      child: Icon(Icons.error, color: Theme.of(context).colorScheme.error),
    ),
  );
}
