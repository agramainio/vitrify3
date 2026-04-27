import 'web_plugin_safety_stub.dart'
    if (dart.library.html) 'web_plugin_safety_web.dart';

void ensureWebPluginsRegistered() {
  ensureWebPluginsRegisteredImpl();
}
