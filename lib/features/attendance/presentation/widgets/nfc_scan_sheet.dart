import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_decorations.dart';
import '../../data/nfc_reader.dart';
import '../../domain/attendance_control.dart';

/// Asks the employee to tap an assigned NFC card. Returns the normalized serial
/// of an accepted card, or null if cancelled / NFC unavailable.
Future<String?> showNfcScanSheet(
  BuildContext context, {
  required NfcReader reader,
  required bool isCheckingOut,
  required List<AttendanceNfcCard> cards,
}) async {
  final action = isCheckingOut ? 'check out' : 'check in';
  if (!await reader.isAvailable()) {
    if (!context.mounted) return null;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.nfc, size: 32),
        title: const Text('Turn on NFC'),
        content: Text(
          'You need to tap your NFC card to $action. Turn on NFC in your phone '
          'settings and try again. If your phone has no NFC, contact HR.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return null;
  }
  if (!context.mounted) return null;
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isDismissible: true,
    builder: (_) => _NfcScanSheet(
      reader: reader,
      isCheckingOut: isCheckingOut,
      cards: cards,
    ),
  );
}

class _NfcScanSheet extends StatefulWidget {
  const _NfcScanSheet({
    required this.reader,
    required this.isCheckingOut,
    required this.cards,
  });

  final NfcReader reader;
  final bool isCheckingOut;
  final List<AttendanceNfcCard> cards;

  @override
  State<_NfcScanSheet> createState() => _NfcScanSheetState();
}

class _NfcScanSheetState extends State<_NfcScanSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  String? _problem;
  AttendanceNfcCard? _accepted;
  bool _closing = false;

  String get _action => widget.isCheckingOut ? 'check out' : 'check in';

  @override
  void initState() {
    super.initState();
    widget.reader.start(
      iosAlertMessage: 'Hold your phone near your NFC card to $_action.',
      onSerial: _onSerial,
      onError: (message) {
        if (mounted && _accepted == null) setState(() => _problem = message);
      },
      onCancelled: () => _close(null),
    );
  }

  void _onSerial(String serial) {
    if (!mounted || _accepted != null) return;
    final card = AttendanceControlConfig(nfcCards: widget.cards).cardForSerial(serial);
    if (card == null) {
      setState(() {
        _problem = 'This card is not assigned to you. Tap your assigned card.';
      });
      return;
    }
    setState(() {
      _accepted = card;
      _problem = null;
    });
    widget.reader.stop(iosSuccessMessage: 'Card accepted');
    Timer(const Duration(milliseconds: 700), () => _close(card.serial));
  }

  void _close(String? serial) {
    if (_closing || !mounted) return;
    _closing = true;
    Navigator.of(context).pop(serial);
  }

  @override
  void dispose() {
    _pulse.dispose();
    if (_accepted == null) widget.reader.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accepted = _accepted;
    final color = accepted != null
        ? const Color(0xFF22C55E)
        : (_problem != null ? AppColors.danger : AppColors.primary);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: Tween(begin: 0.92, end: 1.08).animate(
                CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
              ),
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.12),
                ),
                child: Icon(
                  accepted != null ? Icons.check_circle : Icons.contactless,
                  size: 52,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              accepted != null
                  ? 'Card accepted'
                  : 'Tap your NFC card to $_action',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              accepted != null
                  ? (accepted.name.isNotEmpty ? accepted.name : 'Sending your punch…')
                  : 'Hold the back of your phone close to the card until it vibrates.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppDecorations.muted(context),
              ),
              textAlign: TextAlign.center,
            ),
            if (_problem != null && accepted == null) ...[
              const SizedBox(height: 12),
              Text(
                _problem!,
                style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.danger),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 20),
            if (accepted == null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _close(null),
                  child: const Text('Cancel'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
