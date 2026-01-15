import 'package:flutter/material.dart';

/// A widget for displaying error state with retry option.
///
/// This widget is used to display an error message when something
/// goes wrong, such as a network error or data loading failure.
class ErrorState extends StatelessWidget {
  /// The error message to display.
  final String message;

  /// Optional detailed error message.
  final String? details;

  /// Callback for the retry button.
  final VoidCallback onRetry;

  /// Optional icon to display. Defaults to Icons.error_outline.
  final IconData icon;

  /// Optional icon size. Defaults to 64.
  final double iconSize;

  const ErrorState({
    Key? key,
    required this.message,
    this.details,
    required this.onRetry,
    this.icon = Icons.error_outline,
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
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            if (details != null) ...[
              const SizedBox(height: 8),
              Text(
                details!,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

