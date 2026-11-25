import 'url_opener_stub.dart'
    if (dart.library.js_interop) 'url_opener_web.dart';

class UrlOpenerHelper {
  UrlOpenerHelper._();

  static void openInNewTab(String url) {
    openExternalUrl(url);
  }
}
