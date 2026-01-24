import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

enum LogLevel {
  debug,
  info,
  warning,
  error,
}

class Logger {
  static const String _defaultTag = 'Rotante';
  
  static void debug(String message, {String? tag}) {
    _log(LogLevel.debug, message, tag: tag);
  }
  
  static void info(String message, {String? tag}) {
    _log(LogLevel.info, message, tag: tag);
  }
  
  static void warning(String message, {String? tag}) {
    _log(LogLevel.warning, message, tag: tag);
  }
  
  static void error(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.error, message, tag: tag, error: error, stackTrace: stackTrace);
  }
  
  static void _log(
    LogLevel level,
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (kReleaseMode && level == LogLevel.debug) {
      return;
    }

    final effectiveTag = tag ?? _defaultTag;
    final levelName = level.name.toUpperCase();
    final timestamp = DateTime.now().toIso8601String();
    
    final logMessage = '[$timestamp] $levelName [$effectiveTag] $message';
    
    // Print to console for visibility
    // ignore: avoid_print
    print(logMessage);
    if (error != null) {
      // ignore: avoid_print
      print('  Error: $error');
    }
    if (stackTrace != null) {
      // ignore: avoid_print
      print('  StackTrace: $stackTrace');
    }
    
    // Also log to developer console
    switch (level) {
      case LogLevel.debug:
      case LogLevel.info:
        developer.log(logMessage);
        break;
      case LogLevel.warning:
        developer.log(logMessage, level: 900);
        break;
      case LogLevel.error:
        developer.log(
          logMessage,
          level: 1000,
          error: error,
          stackTrace: stackTrace,
        );
        break;
    }
  }
}
