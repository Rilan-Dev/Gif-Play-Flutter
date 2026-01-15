import 'package:flutter/material.dart';

/// A widget for displaying empty state with icon and message.
///
/// This widget is used to display a message when there's no content
/// to show, such as an empty list or search results.
class EmptyState extends StatelessWidget {
  /// The icon to display.
  final IconData icon;

  /// The title text to display.
  final String title;

  /// Optional message text to display below the title.
  final String? message;

  /// Optional label for the action button.
  final String? actionLabel;

  /// Optional callback for the action button.
  final VoidCallback? onAction;

  /// Optional icon size. Defaults to 64.
  final double iconSize;

  const EmptyState({
    Key? key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.iconSize = 64,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: iconSize,
              color: Theme.of(context).disabledColor,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: Text(actionLabel!),
                onPressed: onAction,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

