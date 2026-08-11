import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_slot/features/booking/data/booking_models.dart';
import 'package:last_slot/features/booking/data/booking_repository.dart';
import 'package:last_slot/features/booking/providers.dart';

void main() {
  test(
    'a temporary failure retries the same booking intent idempotently',
    () async {
      final repository = _RecordingRepository();
      final container = ProviderContainer(
        overrides: [bookingRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final controller = container.read(bookingControllerProvider.notifier);

      await controller.submit('Ada Lovelace');
      expect(
        container.read(bookingControllerProvider),
        isA<BookingTemporarilyUnavailable>(),
      );

      await controller.submit('Ada Lovelace');
      expect(
        container.read(bookingControllerProvider),
        isA<BookingConfirmed>(),
      );
      expect(repository.idempotencyKeys, hasLength(2));
      expect(repository.idempotencyKeys[1], repository.idempotencyKeys[0]);
    },
  );
}

class _RecordingRepository implements BookingRepository {
  final idempotencyKeys = <String>[];

  @override
  Future<BookingResult> createBooking({
    required String customerName,
    required String idempotencyKey,
  }) async {
    idempotencyKeys.add(idempotencyKey);
    if (idempotencyKeys.length == 1) {
      throw const BookingUnavailableException(503);
    }
    const booking = BookingSnapshot(
      id: '22222222-2222-4222-8222-222222222222',
      customerName: 'Ada Lovelace',
      createdAt: '2030-01-01T12:00:00+00:00',
    );
    return const BookingResult(
      booking: booking,
      replayed: true,
      slot: SlotSnapshot(
        id: lastSlotId,
        title: 'Architecture review',
        startsAt: '2030-02-01T09:00:00+00:00',
        status: SlotStatus.booked,
        booking: booking,
      ),
    );
  }

  @override
  Future<SlotSnapshot> getSlot() {
    throw UnimplementedError('not used by this controller test');
  }
}
