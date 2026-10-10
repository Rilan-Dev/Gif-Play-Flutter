/// Determines whether an overlapping feed request belongs to a different
/// Space and must be queued until the current fetch releases ownership.
String? pendingSpaceForOverlappingFetch({
  required String? expectedSpaceId,
  required String? activeSpaceId,
  required String? lastSpaceId,
  required String? activeFetchSpaceId,
}) {
  final requestedSpaceId =
      expectedSpaceId ?? activeSpaceId ?? lastSpaceId;
  if (requestedSpaceId == null ||
      requestedSpaceId == activeFetchSpaceId) {
    return null;
  }
  return requestedSpaceId;
}
