import 'package:dio/dio.dart';

import 'booking_models.dart';

const lastSlotId = '11111111-1111-4111-8111-111111111111';

abstract interface class BookingRepository {
  Future<SlotSnapshot> getSlot();

  Future<BookingResult> createBooking({
    required String customerName,
    required String idempotencyKey,
  });
}

class HttpBookingRepository implements BookingRepository {
  const HttpBookingRepository(this._dio);

  final Dio _dio;

  @override
  Future<SlotSnapshot> getSlot() async {
    try {
      final response = await _dio.get<Map<String, Object?>>(
        '/v1/slots/$lastSlotId',
      );
      return SlotSnapshot.fromJson(response.data!);
    } on DioException catch (error) {
      throw BookingUnavailableException.fromDio(error);
    }
  }

  @override
  Future<BookingResult> createBooking({
    required String customerName,
    required String idempotencyKey,
  }) async {
    try {
      final response = await _dio.post<Map<String, Object?>>(
        '/v1/slots/$lastSlotId/bookings',
        data: <String, Object?>{'customerName': customerName},
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
      );
      return BookingResult.fromJson(response.data!);
    } on DioException catch (error) {
      final code = _errorCode(error);
      if (error.response?.statusCode == 409 && code == 'slot_taken') {
        throw const SlotTakenException();
      }
      if (error.response?.statusCode == 422) {
        throw BookingValidationException(code ?? 'invalid_request');
      }
      throw BookingUnavailableException.fromDio(error);
    }
  }
}

String? _errorCode(DioException error) {
  final data = error.response?.data;
  if (data is! Map<String, Object?>) return null;
  final body = data['error'];
  if (body is! Map<String, Object?>) return null;
  return body['code'] as String?;
}

class SlotTakenException implements Exception {
  const SlotTakenException();
}

class BookingValidationException implements Exception {
  const BookingValidationException(this.code);

  final String code;
}

class BookingUnavailableException implements Exception {
  const BookingUnavailableException(this.statusCode);

  factory BookingUnavailableException.fromDio(DioException error) {
    return BookingUnavailableException(error.response?.statusCode);
  }

  final int? statusCode;
}
