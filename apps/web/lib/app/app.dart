import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/booking/data/booking_models.dart';
import '../features/booking/providers.dart';

const _ink = Color(0xFF101A2B);
const _blue = Color(0xFF1463D9);
const _green = Color(0xFF097A55);
const _red = Color(0xFFB42318);
const _paper = Color(0xFFF8FAFC);
const _line = Color(0xFFD8E0EA);

class LastSlotApp extends StatelessWidget {
  const LastSlotApp({super.key, this.initialLocation});

  final String? initialLocation;

  @override
  Widget build(BuildContext context) {
    final browserPath = Uri.base.path;
    final router = GoRouter(
      initialLocation:
          initialLocation ?? (browserPath == '/' ? '/book' : browserPath),
      routes: [
        GoRoute(path: '/', redirect: (_, _) => '/book'),
        GoRoute(path: '/book', builder: (_, _) => const BookingPage()),
        GoRoute(path: '/admin', builder: (_, _) => const AdminPage()),
      ],
    );
    return MaterialApp.router(
      title: 'Last Slot',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: _paper,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _blue,
          brightness: Brightness.light,
          surface: Colors.white,
        ),
        textTheme: const TextTheme(
          displaySmall: TextStyle(
            fontSize: 44,
            height: 1.05,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.5,
            color: _ink,
          ),
          headlineMedium: TextStyle(
            fontSize: 28,
            height: 1.15,
            fontWeight: FontWeight.w700,
            letterSpacing: -.6,
            color: _ink,
          ),
          titleLarge: TextStyle(fontWeight: FontWeight.w700, color: _ink),
          bodyLarge: TextStyle(fontSize: 17, height: 1.55, color: _ink),
          bodyMedium: TextStyle(fontSize: 14, height: 1.45, color: _ink),
        ),
      ),
      routerConfig: router,
    );
  }
}

class BookingPage extends ConsumerStatefulWidget {
  const BookingPage({super.key});

  @override
  ConsumerState<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends ConsumerState<BookingPage> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slot = ref.watch(slotProvider);
    final attempt = ref.watch(bookingControllerProvider);
    return _PageFrame(
      currentPath: '/book',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 860;
          final intro = _Intro(wide: wide);
          final booking = _BookingCard(
            slot: slot,
            attempt: attempt,
            nameController: _nameController,
            onSubmit: () => ref
                .read(bookingControllerProvider.notifier)
                .submit(_nameController.text),
          );
          return Column(
            children: [
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: intro),
                    const SizedBox(width: 72),
                    SizedBox(width: 410, child: booking),
                  ],
                )
              else ...[
                intro,
                const SizedBox(height: 36),
                booking,
              ],
              const SizedBox(height: 72),
              const _ProofPath(),
              const SizedBox(height: 28),
              const _BoundaryNote(),
            ],
          );
        },
      ),
    );
  }
}

class AdminPage extends ConsumerWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slot = ref.watch(slotProvider);
    return _PageFrame(
      currentPath: '/admin',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            container: true,
            header: true,
            label: 'Booking ledger',
            child: Text(
              'Booking ledger',
              style: Theme.of(context).textTheme.displaySmall,
            ),
          ),
          const SizedBox(height: 12),
          const SizedBox(
            width: 620,
            child: Text(
              'A read-only view of the persisted result through the same public API.',
            ),
          ),
          const SizedBox(height: 38),
          slot.when(
            loading: () => const _LoadingCard(),
            error: (_, _) => const _ErrorCard(
              title: 'Ledger unavailable',
              detail:
                  'The public read path could not load the slot. Try again shortly.',
            ),
            data: (value) => _LedgerCard(slot: value),
          ),
          const SizedBox(height: 42),
          const _ProofPath(),
        ],
      ),
    );
  }
}

class _PageFrame extends StatelessWidget {
  const _PageFrame({required this.currentPath, required this.child});

  final String currentPath;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 64),
                child: Column(
                  children: [
                    _Header(currentPath: currentPath),
                    const SizedBox(height: 72),
                    child,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.currentPath});

  final String currentPath;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.radio_button_checked_rounded, color: _blue, size: 21),
        const SizedBox(width: 9),
        const Text(
          'LAST SLOT',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.4),
        ),
        const Spacer(),
        TextButton(
          onPressed: currentPath == '/book' ? null : () => context.go('/book'),
          child: const Text('Booking'),
        ),
        TextButton(
          onPressed: currentPath == '/admin'
              ? null
              : () => context.go('/admin'),
          child: const Text('Ledger'),
        ),
      ],
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Eyebrow('EXECUTABLE RELIABILITY CASE STUDY'),
        const SizedBox(height: 18),
        Semantics(
          container: true,
          header: true,
          label: 'One slot. Two browsers. One correct result.',
          child: Text(
            'One slot. Two browsers. One correct result.',
            style: Theme.of(context).textTheme.displaySmall,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Two independent visitors can race for this final appointment. The database permits exactly one booking; the other visitor receives an honest conflict.',
        ),
        const SizedBox(height: 30),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: const [
            _FactChip(icon: Icons.storage_outlined, text: 'Database invariant'),
            _FactChip(icon: Icons.replay_outlined, text: 'Idempotent retry'),
            _FactChip(icon: Icons.visibility_outlined, text: 'Public readback'),
          ],
        ),
      ],
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({
    required this.slot,
    required this.attempt,
    required this.nameController,
    required this.onSubmit,
  });

  final AsyncValue<SlotSnapshot> slot;
  final BookingAttemptState attempt;
  final TextEditingController nameController;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: slot.when(
          loading: () => const _LoadingCard(),
          error: (_, _) => const _ErrorCard(
            title: 'Slot unavailable',
            detail:
                'The booking surface cannot reach the public API right now.',
          ),
          data: (value) => _BookingForm(
            slot: value,
            attempt: attempt,
            nameController: nameController,
            onSubmit: onSubmit,
          ),
        ),
      ),
    );
  }
}

class _BookingForm extends StatelessWidget {
  const _BookingForm({
    required this.slot,
    required this.attempt,
    required this.nameController,
    required this.onSubmit,
  });

  final SlotSnapshot slot;
  final BookingAttemptState attempt;
  final TextEditingController nameController;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final isSubmitting = attempt is BookingSubmitting;
    final BookingConfirmed? confirmed = attempt is BookingConfirmed
        ? attempt as BookingConfirmed
        : null;
    final BookingInputInvalid? invalid = attempt is BookingInputInvalid
        ? attempt as BookingInputInvalid
        : null;
    final isBooked = slot.status == SlotStatus.booked;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Eyebrow('THE FINAL APPOINTMENT'),
        const SizedBox(height: 14),
        Semantics(
          container: true,
          label: slot.title,
          child: ExcludeSemantics(
            child: Text(
              slot.title,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _formatDate(slot.startsAt),
          style: const TextStyle(color: Color(0xFF536174)),
        ),
        const SizedBox(height: 20),
        _SlotState(status: slot.status),
        const SizedBox(height: 24),
        if (confirmed != null)
          _ResultBanner.confirmed(confirmed.result.booking.customerName)
        else if (attempt is BookingConflict || isBooked)
          const _ResultBanner.conflict()
        else if (attempt is BookingTemporarilyUnavailable)
          _ResultBanner.unavailable(onRetry: onSubmit)
        else ...[
          TextField(
            controller: nameController,
            enabled: !isSubmitting,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onSubmit(),
            decoration: InputDecoration(
              labelText: 'Your name',
              hintText: 'Ada Lovelace',
              errorText: invalid?.message,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: isSubmitting ? null : onSubmit,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 17),
              ),
              child: Text(
                isSubmitting ? 'Submitting booking…' : 'Book the last slot',
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        const Text(
          'A retry after a temporary failure reuses the same idempotency key.',
          style: TextStyle(fontSize: 12, color: Color(0xFF536174)),
        ),
      ],
    );
  }
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner._({
    required this.color,
    required this.icon,
    required this.title,
    required this.detail,
    this.onRetry,
    this.isAlert = false,
  });

  factory _ResultBanner.confirmed(String name) => _ResultBanner._(
    color: _green,
    icon: Icons.check_circle_outline,
    title: 'Booking confirmed',
    detail: '$name holds this appointment. The result is persisted.',
  );

  const _ResultBanner.conflict()
    : this._(
        color: _red,
        icon: Icons.priority_high_rounded,
        title: 'Slot already booked',
        detail:
            'Another visitor completed the booking first. No second booking was created.',
        isAlert: true,
      );

  factory _ResultBanner.unavailable({
    required VoidCallback onRetry,
  }) => _ResultBanner._(
    color: const Color(0xFF9A6700),
    icon: Icons.sync_problem_outlined,
    title: 'Booking temporarily unavailable',
    detail:
        'The request may not have reached the service. Retry safely with the same intent.',
    onRetry: onRetry,
  );

  final Color color;
  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback? onRetry;
  final bool isAlert;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: .35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: color, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(detail),
          if (onRetry != null) ...[
            const SizedBox(height: 10),
            TextButton(onPressed: onRetry, child: const Text('Retry booking')),
          ],
        ],
      ),
    );
    return Semantics(
      container: true,
      liveRegion: true,
      label: title,
      child: ExcludeSemantics(child: content),
    );
  }
}

class _LedgerCard extends StatelessWidget {
  const _LedgerCard({required this.slot});

  final SlotSnapshot slot;

  @override
  Widget build(BuildContext context) {
    final booking = slot.booking;
    final booked = slot.status == SlotStatus.booked;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 780),
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  slot.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              _SlotState(status: slot.status),
            ],
          ),
          const Divider(height: 34),
          Semantics(
            container: true,
            label: booked ? '1 confirmed booking' : '0 confirmed bookings',
            child: ExcludeSemantics(
              child: Text(
                booked ? '1 confirmed booking' : '0 confirmed bookings',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (booking != null) ...[
            const _Eyebrow('BOOKED BY'),
            const SizedBox(height: 7),
            Semantics(
              container: true,
              label: booking.customerName,
              child: ExcludeSemantics(
                child: Text(
                  booking.customerName,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Recorded ${_formatDate(booking.createdAt)}',
              style: const TextStyle(color: Color(0xFF536174)),
            ),
          ] else
            const Text('No booking has been persisted yet.'),
        ],
      ),
    );
  }
}

class _SlotState extends StatelessWidget {
  const _SlotState({required this.status});
  final SlotStatus status;

  @override
  Widget build(BuildContext context) {
    final booked = status == SlotStatus.booked;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (booked ? _red : _green).withValues(alpha: .09),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Semantics(
        container: true,
        label: booked ? 'Booked' : 'Available',
        child: ExcludeSemantics(
          child: Text(
            booked ? 'Booked' : 'Available',
            style: TextStyle(
              color: booked ? _red : _green,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _ProofPath extends StatelessWidget {
  const _ProofPath();
  @override
  Widget build(BuildContext context) {
    const steps = [
      'Flutter UI',
      'Gateway',
      'Booking service',
      'PostgreSQL',
      'Admin readback',
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _ink,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'THE PROOF PATH',
            style: TextStyle(
              color: Color(0xFF9CBFFF),
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final step in steps) _PathStep(label: step)],
          ),
          const SizedBox(height: 14),
          const Text(
            'The database constraint decides the race. The browser journey makes that decision visible.',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _PathStep extends StatelessWidget {
  const _PathStep({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      border: Border.all(color: const Color(0xFF40526D)),
      borderRadius: BorderRadius.circular(7),
    ),
    child: Text(
      label,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
    ),
  );
}

class _BoundaryNote extends StatelessWidget {
  const _BoundaryNote();
  @override
  Widget build(BuildContext context) => const Align(
    alignment: Alignment.centerLeft,
    child: Text(
      'Deliberately narrow: one synthetic slot. No authentication, payments, or invented uptime claims.',
      style: TextStyle(color: Color(0xFF536174)),
    ),
  );
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Center(
      child: Semantics(
        label: 'Loading slot',
        child: CircularProgressIndicator(),
      ),
    ),
  );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.title, required this.detail});
  final String title;
  final String detail;
  @override
  Widget build(BuildContext context) => _ResultBanner._(
    color: _red,
    icon: Icons.error_outline,
    title: title,
    detail: detail,
    isAlert: true,
  );
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: _blue,
      fontSize: 12,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.15,
    ),
  );
}

class _FactChip extends StatelessWidget {
  const _FactChip({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: _line),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: _blue),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

String _formatDate(String value) {
  final parsed = DateTime.tryParse(value)?.toLocal();
  if (parsed == null) return value;
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  final minute = parsed.minute.toString().padLeft(2, '0');
  return '${months[parsed.month - 1]} ${parsed.day}, ${parsed.year} · ${parsed.hour}:$minute';
}
