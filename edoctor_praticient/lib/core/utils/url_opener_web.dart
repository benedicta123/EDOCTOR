import 'package:web/web.dart' as web;

void openExternalUrl(String url) {
  if (url.isEmpty) return;
  web.window.open(url, '_blank');
}
