import 'package:flutter/material.dart';

import 'app_update_service.dart';

Future<void> showAppUpdateDialog(
  BuildContext context, {
  required AppUpdateCheckResult result,
  required AppUpdateService service,
  bool userInitiated = false,
}) async {
  if (!context.mounted) return;

  if (!result.updateAvailable) {
    if (userInitiated) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('You’re up to date'),
          content: Text(
            'HR360 Go ${result.current.displayLabel} is the latest version'
            '${result.latestConfigured != null ? '' : ' we know about'}.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
    return;
  }

  await showDialog<void>(
    context: context,
    barrierDismissible: !result.forceUpdate,
    builder: (ctx) => AlertDialog(
      title: Text(result.forceUpdate ? 'Update required' : 'Update available'),
      content: Text(
        'A newer version (${result.latestConfigured}) is available.\n'
        'You have ${result.current.displayLabel}.',
      ),
      actions: [
        if (!result.forceUpdate)
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Later'),
          ),
        FilledButton(
          onPressed: () async {
            final opened = await service.openStore(url: result.storeUrl);
            if (!ctx.mounted) return;
            if (!opened) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Store link not configured. Set IOS_STORE_URL / ANDROID_STORE_URL in .env',
                  ),
                ),
              );
            }
            if (!result.forceUpdate) Navigator.of(ctx).pop();
          },
          child: const Text('Update'),
        ),
      ],
    ),
  );
}
