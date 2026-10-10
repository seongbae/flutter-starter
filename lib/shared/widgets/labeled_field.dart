import 'package:flutter/material.dart';
import '../../core/theme/app_spacing.dart';

/// Puts a [label] above a form field, the way Cadence lays out its forms
/// (instead of a floating label inside the field).
class LabeledField extends StatelessWidget {
  const LabeledField({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        child,
      ],
    );
  }
}
