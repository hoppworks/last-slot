enum SlotStatus { available, booked }

class BookingSnapshot {
  const BookingSnapshot({
    required this.id,
    required this.customerName,
    required this.createdAt,
  });

  factory BookingSnapshot.fromJson(Map<String, Object?> json) {
    return BookingSnapshot(
      id: json['id']! as String,
      customerName: json['customerName']! as String,
      createdAt: json['createdAt']! as String,
    );
  }

  final String id;
  final String customerName;
  final String createdAt;
}

class SlotSnapshot {
  const SlotSnapshot({
    required this.id,
    required this.title,
    required this.startsAt,
    required this.status,
    this.booking,
  });

  factory SlotSnapshot.fromJson(Map<String, Object?> json) {
    final rawStatus = json['status']! as String;
    final status = switch (rawStatus) {
      'available' => SlotStatus.available,
      'booked' => SlotStatus.booked,
      _ => throw FormatException('Unknown slot status: $rawStatus'),
    };
    final rawBooking = json['booking'];
    return SlotSnapshot(
      id: json['id']! as String,
      title: json['title']! as String,
      startsAt: json['startsAt']! as String,
      status: status,
      booking: rawBooking is Map<String, Object?>
          ? BookingSnapshot.fromJson(rawBooking)
          : null,
    );
  }

  final String id;
  final String title;
  final String startsAt;
  final SlotStatus status;
  final BookingSnapshot? booking;
}

class BookingResult {
  const BookingResult({
    required this.booking,
    required this.slot,
    required this.replayed,
  });

  factory BookingResult.fromJson(Map<String, Object?> json) {
    return BookingResult(
      booking: BookingSnapshot.fromJson(
        json['booking']! as Map<String, Object?>,
      ),
      slot: SlotSnapshot.fromJson(json['slot']! as Map<String, Object?>),
      replayed: json['replayed']! as bool,
    );
  }

  final BookingSnapshot booking;
  final SlotSnapshot slot;
  final bool replayed;
}
