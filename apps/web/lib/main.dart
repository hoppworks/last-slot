import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';

// Retained for the lifetime of an explicitly accessibility-enabled E2E page.
SemanticsHandle? e2eSemanticsHandle;

void main() {
  final shouldEnableE2eSemantics = Uri.base.queryParameters['e2e'] == '1';
  runApp(const ProviderScope(child: LastSlotApp()));

  // The Patrol browser journey targets the release build behind Nginx. Flutter
  // Web normally puts its accessibility switch outside the viewport; an
  // explicit test URL enables the exact same semantics tree deterministically.
  if (shouldEnableE2eSemantics) {
    e2eSemanticsHandle = SemanticsBinding.instance.ensureSemantics();
  }
}
