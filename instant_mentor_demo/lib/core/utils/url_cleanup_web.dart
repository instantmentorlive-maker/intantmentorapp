// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class UrlCleanup {
  static void removeAuthParamsIfPresent() {
    final uri = Uri.base;
    final hasPkceParams = uri.queryParameters.containsKey('code') ||
        uri.queryParameters.containsKey('error') ||
        uri.queryParameters.containsKey('provider') ||
        uri.queryParameters.containsKey('type');
    if (!hasPkceParams) return;

    final cleaned = Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: uri.path.isEmpty ? '/' : uri.path,
      // drop query/fragment
    );
    // Replace state without reloading
    html.window.history.replaceState(null, html.document.title, cleaned.toString());
  }
}
