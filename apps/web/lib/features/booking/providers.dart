import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'data/booking_models.dart';
import 'data/booking_repository.dart';

const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');

final dioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      // In production the Flutter app and public API share one origin via the
      // Nginx reverse proxy. An explicit value remains available for isolated
      // development, but never defaults to the browser user's localhost.
      baseUrl: apiBaseUrl.isEmpty ? Uri.base.origin : apiBaseUrl,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      sendTimeout: const Duration(seconds: 5),
    ),
  );
});

final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  return HttpBookingRepository(ref.watch(dioProvider));
});

final slotProvider = FutureProvider<SlotSnapshot>((ref) {
  return ref.watch(bookingRepositoryProvider).getSlot();
});

sealed class BookingAttemptState {
  const BookingAttemptState();
}

class BookingIdle extends BookingAttemptState {
  const BookingIdle();
}

class BookingSubmitting extends BookingAttemptState {
  const BookingSubmitting();
}

class BookingConfirmed extends BookingAttemptState {
  const BookingConfirmed(this.result);

  final BookingResult result;
}

class BookingConflict extends BookingAttemptState {
  const BookingConflict();
}

class BookingInputInvalid extends BookingAttemptState {
  const BookingInputInvalid(this.message);

  final String message;
}

class BookingTemporarilyUnavailable extends BookingAttemptState {
  const BookingTemporarilyUnavailable();
}

final bookingControllerProvider =
    NotifierProvider<BookingController, BookingAttemptState>(
      BookingController.new,
    );

class BookingController extends Notifier<BookingAttemptState> {
  String? _intentName;
  String? _idempotencyKey;

  @override
  BookingAttemptState build() => const BookingIdle();

  Future<void> submit(String rawCustomerName) async {
    final customerName = rawCustomerName.trim();
    if (customerName.length < 2 || customerName.length > 80) {
      state = const BookingInputInvalid(
        'Enter a name between 2 and 80 characters.',
      );
      return;
    }

    if (_intentName != customerName || _idempotencyKey == null) {
      _intentName = customerName;
      _idempotencyKey = const Uuid().v4();
    }

    state = const BookingSubmitting();
    try {
      final result = await ref
          .read(bookingRepositoryProvider)
          .createBooking(
            customerName: customerName,
            idempotencyKey: _idempotencyKey!,
          );
      state = BookingConfirmed(result);
      ref.invalidate(slotProvider);
    } on SlotTakenException {
      state = const BookingConflict();
      ref.invalidate(slotProvider);
    } on BookingValidationException {
      state = const BookingInputInvalid(
        'The booking request is no longer valid. Check the name and retry.',
      );
    } on BookingUnavailableException {
      state = const BookingTemporarilyUnavailable();
    }
  }
}
