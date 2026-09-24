import 'dart:io';

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';

/// What a reader is shown when something fails: the reason in their own
/// language, never the exception. The tasmee panel printed «DioException
/// [connection error]: … Failed host lookup: 'github.com'» in English inside
/// an Arabic screen when the network dropped mid-download (emulator-5554,
/// 2026-09-24). The detail still goes to the log.
String userErrorText(Object e) {
  debugPrint('userErrorText: $e');
  return isNetworkError(e) ? 'errors.offline'.tr() : 'errors.generic'.tr();
}

/// A failure of the connection itself - no network, a lookup that failed,
/// a host that did not answer in time - rather than of the content.
bool isNetworkError(Object e) {
  if (e is SocketException || e is HttpException) return true;
  if (e is DioException) {
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return true;
      default:
        return e.error is SocketException;
    }
  }
  return false;
}
