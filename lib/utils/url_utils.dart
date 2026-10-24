/// Removes surrounding whitespace and any trailing slashes from an instance URL.
///
/// Endpoint paths are concatenated onto this value, so a trailing slash would
/// produce requests such as `//api/v1/stats`, which Invidious redirects to the
/// web UI instead of serving as JSON.
String normalizeInstanceUrl(String url) {
  var normalized = url.trim();
  while (normalized.endsWith('/')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  return normalized;
}

/// Adds `local=true` to an Invidious URL that may already contain a query.
///
/// Used for HLS/DASH manifest URLs when "Proxy videos" is enabled: the
/// instance then rewrites manifest segment URLs to `/companion/videoplayback`
/// instead of direct `googlevideo.com` URLs.
String addLocalProxyParameter(String url) {
  if (url.isEmpty || url.contains('local=')) {
    return url;
  }
  final separator = url.contains('?') ? '&' : '?';
  return '$url${separator}local=true';
}

/// Resolves a URL returned by the Invidious API against [instanceUrl].
///
/// Invidious returns some media URLs (DASH manifests, proxied streams,
/// thumbnails and captions) as absolute paths such as `/api/manifest/...`.
/// Native players and Dio require absolute URLs, so relative values must be
/// resolved against the selected instance. Absolute URLs are returned as-is.
String resolveInstanceUrl(String instanceUrl, String? url) {
  if (url == null || url.isEmpty) {
    return url ?? '';
  }

  final parsed = Uri.tryParse(url);
  if (parsed != null && parsed.hasScheme) {
    return url;
  }

  final base = Uri.parse('${normalizeInstanceUrl(instanceUrl)}/');
  return base.resolveUri(parsed ?? Uri()).toString();
}
