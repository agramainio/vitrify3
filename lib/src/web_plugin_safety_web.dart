// ignore_for_file: depend_on_referenced_packages, implementation_imports

import 'package:cloud_firestore_web/cloud_firestore_web.dart';
import 'package:file_picker/_internal/file_picker_web.dart';
import 'package:firebase_auth_web/firebase_auth_web.dart';
import 'package:firebase_core_web/firebase_core_web.dart';
import 'package:firebase_storage_web/firebase_storage_web.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:shared_preferences_web/shared_preferences_web.dart';

bool _registered = false;

void ensureWebPluginsRegisteredImpl() {
  if (_registered) {
    return;
  }

  final registrar = webPluginRegistrar;
  FirebaseFirestoreWeb.registerWith(registrar);
  FilePickerWeb.registerWith(registrar);
  FirebaseAuthWeb.registerWith(registrar);
  FirebaseCoreWeb.registerWith(registrar);
  FirebaseStorageWeb.registerWith(registrar);
  SharedPreferencesPlugin.registerWith(registrar);
  registrar.registerMessageHandler();
  _registered = true;
}
