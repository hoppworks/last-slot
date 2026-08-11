import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_slot/app/app.dart';
import 'package:last_slot/features/booking/data/booking_models.dart';
import 'package:last_slot/features/booking/data/booking_repository.dart';
import 'package:last_slot/features/booking/providers.dart';

void main() {
  testWidgets('booking surface exposes the invariant and available slot', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookingRepositoryProvider.overrideWithValue(
            _FakeBookingRepository(
              const SlotSnapshot(
                id: '11111111-1111-4111-8111-111111111111',
                title: 'Architecture review',
                startsAt: '2030-02-01T09:00:00+00:00',
                status: SlotStatus.available,
              ),
            ),
          ),
        ],
        child: const LastSlotApp(initialLocation: '/book'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('One slot. Two browsers. One correct result.'),
      findsOneWidget,
    );
    expect(find.text('Architecture review'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Your name'), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Book the last slot'),
      findsOneWidget,
    );
  });
}

class _FakeBookingRepository implements BookingRepository {
  const _FakeBookingRepository(this.slot);

  final SlotSnapshot slot;

  @override
  Future<SlotSnapshot> getSlot() async => slot;

  @override
  Future<BookingResult> createBooking({
    required String customerName,
    required String idempotencyKey,
  }) {
    throw UnimplementedError('not used by this rendering test');
  }
}
