import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Shown instead of a screen whose module isn't part of the company's plan.
class NotInPlanView extends StatelessWidget {
  const NotInPlanView({super.key, required this.featureName});

  final String featureName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_outline, color: AppColors.primary, size: 30),
            ),
            const SizedBox(height: 16),
            Text(
              'Not included in your plan',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              "$featureName isn't part of your company's HR360 plan. "
              'Contact your administrator to add it.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
