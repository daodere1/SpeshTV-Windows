String youtubeEmbedOrigin(String packageName) {
  final id = packageName.trim().toLowerCase();
  if (!RegExp(r'^[a-z0-9_]+(?:\.[a-z0-9_]+)+$').hasMatch(id)) {
    throw ArgumentError.value(packageName, 'packageName');
  }
  return 'https://$id';
}
