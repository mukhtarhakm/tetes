import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../../features/beans/fx_conversion.dart';

enum FxFailureType { network, timeout, server, invalidResponse }

class FxException implements Exception {
  const FxException({required this.type, required this.message});

  final FxFailureType type;
  final String message;

  @override
  String toString() => message;
}

abstract interface class FxRateSource {
  Future<FxQuote> fetch(String currency);
}

class FxClient implements FxRateSource {
  FxClient({
    http.Client? client,
    this.baseUrl = AppConfig.fxBaseUrl,
    this.timeout = AppConfig.fxRequestTimeout,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;
  final String baseUrl;
  final Duration timeout;

  @override
  Future<FxQuote> fetch(String currency) async {
    final normalizedCurrency = currency.toUpperCase();
    final uri = Uri.parse(
      '$baseUrl/latest',
    ).replace(queryParameters: {'base': normalizedCurrency, 'symbols': 'IDR'});
    late http.Response response;
    try {
      response = await _client.get(uri).timeout(timeout);
    } on TimeoutException {
      throw const FxException(
        type: FxFailureType.timeout,
        message: 'Permintaan kurs membutuhkan waktu terlalu lama.',
      );
    } on SocketException {
      throw const FxException(
        type: FxFailureType.network,
        message: 'Tidak dapat terhubung ke layanan kurs.',
      );
    } on http.ClientException {
      throw const FxException(
        type: FxFailureType.network,
        message: 'Tidak dapat terhubung ke layanan kurs.',
      );
    }

    if (response.statusCode != 200) {
      throw const FxException(
        type: FxFailureType.server,
        message: 'Layanan kurs sedang bermasalah.',
      );
    }
    return parseResponse(response.body, currency: normalizedCurrency);
  }

  FxQuote parseResponse(String source, {required String currency}) {
    Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      throw const FxException(
        type: FxFailureType.invalidResponse,
        message: 'Respons kurs tidak valid.',
      );
    }
    if (decoded is! Map) {
      throw const FxException(
        type: FxFailureType.invalidResponse,
        message: 'Respons kurs tidak valid.',
      );
    }
    final body = decoded.map((key, value) => MapEntry('$key', value));
    final ratesValue = body['rates'];
    final rates = ratesValue is Map
        ? ratesValue.map((key, value) => MapEntry('$key', value))
        : null;
    final rateValue = rates?['IDR'];
    final dateValue = body['date'];
    final rate = rateValue is num ? rateValue.toDouble() : null;
    if (rate == null ||
        !rate.isFinite ||
        rate <= 0 ||
        dateValue is! String ||
        !_isValidDate(dateValue)) {
      throw const FxException(
        type: FxFailureType.invalidResponse,
        message: 'Respons kurs tidak memuat data rupiah yang valid.',
      );
    }
    return FxQuote(
      currency: currency,
      rate: rate,
      date: dateValue,
      source: FxQuoteSource.network,
    );
  }

  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }

  bool _isValidDate(String value) {
    return RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) &&
        DateTime.tryParse(value) != null;
  }
}
