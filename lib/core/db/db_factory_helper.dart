import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:sqflite/sqflite.dart';

/// Returns the [DatabaseFactory] appropriate for the current platform.
///
/// On web  → [databaseFactoryFfiWebNoWebWorker]
///   Runs SQLite (WASM) directly in the main UI thread — no separate worker JS
///   file needed, so no build setup step required.
///
/// On native → the default sqflite factory (unchanged behaviour).
DatabaseFactory get platformDatabaseFactory =>
    kIsWeb ? databaseFactoryFfiWebNoWebWorker : databaseFactory;
