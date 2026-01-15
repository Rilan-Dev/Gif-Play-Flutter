import 'package:intl/intl.dart';

/// Utility class for formatting timestamps as relative time.
///
/// This class provides methods for formatting dates as relative time
/// (e.g., "5 minutes ago", "2 days ago") and grouping items by time categories.
class TimeAgoUtil {
  /// Formats a date as relative time.
  ///
  /// Example: "5 minutes ago", "2 days ago"
  static String format(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds} seconds ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 30) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months months ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years years ago';
    }
  }

  /// Formats a date as detailed relative time.
  ///
  /// For recent dates, returns relative time.
  /// For older dates, returns formatted date.
  static String formatDetailed(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds} seconds ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else {
      return DateFormat('MMM d, yyyy').format(dateTime);
    }
  }

  /// Gets the time category for a date.
  ///
  /// Example: "Just now", "Minutes ago", "This week"
  static String getCategory(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return 'Minutes ago';
    } else if (difference.inHours < 24) {
      return 'Hours ago';
    } else if (difference.inDays < 7) {
      return 'This week';
    } else if (difference.inDays < 30) {
      return 'This month';
    } else if (difference.inDays < 365) {
      return 'This year';
    } else {
      return 'Older';
    }
  }

  /// Groups items by time category.
  ///
  /// This is useful for displaying items in sections by time.
  static Map<String, List<T>> groupByTimeCategory<T>(
    List<T> items,
    DateTime Function(T item) getTimestamp,
  ) {
    final Map<String, List<T>> groupedItems = {};
    
    for (final item in items) {
      final timestamp = getTimestamp(item);
      final category = getCategory(timestamp);
      
      if (!groupedItems.containsKey(category)) {
        groupedItems[category] = [];
      }
      
      groupedItems[category]!.add(item);
    }
    
    // Sort each category by timestamp (newest first)
    groupedItems.forEach((key, value) {
      value.sort((a, b) => getTimestamp(b).compareTo(getTimestamp(a)));
    });
    
    // Define the order of categories
    final categoryOrder = [
      'Just now',
      'Minutes ago',
      'Hours ago',
      'This week',
      'This month',
      'This year',
      'Older',
    ];
    
    // Create a new map with the correct order
    final Map<String, List<T>> orderedGroups = {};
    for (final category in categoryOrder) {
      if (groupedItems.containsKey(category)) {
        orderedGroups[category] = groupedItems[category]!;
      }
    }
    
    return orderedGroups;
  }

  /// Formats a date as a short string.
  ///
  /// Example: "Today", "Yesterday", "Mon", "Jan 5"
  static String formatShort(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final date = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    if (date == today) {
      return 'Today';
    } else if (date == yesterday) {
      return 'Yesterday';
    } else if (date.isAfter(today.subtract(const Duration(days: 7)))) {
      return DateFormat('E').format(dateTime); // Day of week
    } else if (date.year == now.year) {
      return DateFormat('MMM d').format(dateTime); // Month and day
    } else {
      return DateFormat('MMM d, y').format(dateTime); // Month, day, and year
    }
  }
}

