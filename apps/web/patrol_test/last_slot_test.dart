import 'package:flutter_test/flutter_test.dart' show Timeout;
import 'package:patrol/patrol.dart';

const _appUrl = String.fromEnvironment(
  'E2E_APP_URL',
  defaultValue: 'http://127.0.0.1:8081',
);

final _nameField = WebSelector(role: 'textbox');
final _bookButton = WebSelector(text: 'Book the last slot');
final _confirmedOutcome = WebSelector(
  role: 'button',
  text: 'Refresh confirmed booking',
);
final _conflictOutcome = WebSelector(
  role: 'button',
  text: 'Refresh conflict state',
);
final _inspectLedger = WebSelector(text: 'Inspect 1 confirmed booking');

Future<void> _enterName(PatrolIntegrationTester $, String name) async {
  await $.platform.web.tap(_nameField);

  // Patrol's `enterText` intentionally maps to Playwright `fill`. Flutter Web
  // only updates a TextEditingController for real keyboard events, so this is
  // deliberately physical browser input through Patrol's web bridge.
  for (final character in name.split('')) {
    await $.platform.web.pressKey(key: character);
  }
}

String _e2eUrl(String path) => '$_appUrl$path?e2e=1';

void main() {
  patrolTest(
    'two visitors see one confirmation, one conflict, and fresh pages read the persisted state',
    ($) async {
      final firstVisitor = await $.platform.web.openNewPage(
        url: _e2eUrl('/book'),
      );
      final secondVisitor = await $.platform.web.openNewPage(
        url: _e2eUrl('/book'),
      );

      await $.platform.web.switchToPage(pageId: firstVisitor);
      await _enterName($, 'Ada');

      await $.platform.web.switchToPage(pageId: secondVisitor);
      await _enterName($, 'Linus');

      // The dedicated HTTP/DB integration proof releases two requests through
      // a real barrier. This browser proof owns the other half of the claim:
      // users can see both public outcomes and a fresh public read afterwards.
      await $.platform.web.switchToPage(pageId: firstVisitor);
      await $.platform.web.tap(_bookButton);
      await $.platform.web.tap(_confirmedOutcome);

      await $.platform.web.switchToPage(pageId: secondVisitor);
      await $.platform.web.tap(_bookButton);
      await $.platform.web.tap(_conflictOutcome);

      // Fresh browser pages have no local attempt state. The conflict action
      // appears there only after the public API returns a booked slot.
      final freshFirstVisitor = await $.platform.web.openNewPage(
        url: _e2eUrl('/book'),
      );
      await $.platform.web.switchToPage(pageId: freshFirstVisitor);
      await $.platform.web.tap(_conflictOutcome);

      final freshSecondVisitor = await $.platform.web.openNewPage(
        url: _e2eUrl('/book'),
      );
      await $.platform.web.switchToPage(pageId: freshSecondVisitor);
      await $.platform.web.tap(_conflictOutcome);

      final ledger = await $.platform.web.openNewPage(url: _e2eUrl('/admin'));
      await $.platform.web.switchToPage(pageId: ledger);

      // This only exists when the public ledger has loaded exactly one booking.
      // No database or private API assertion participates in this proof.
      await $.platform.web.tap(_inspectLedger);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
