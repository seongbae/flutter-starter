import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../pages/onboarding_page.dart';
import '../../../../core/theme/app_spacing.dart';

class OnboardingStep extends StatelessWidget {
  final OnboardingStepData data;
  final int index;
  
  const OnboardingStep({
    super.key,
    required this.data,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            data.color.withValues(alpha: 0.1),
            Theme.of(context).colorScheme.surface,
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                data.image,
                size: 120,
                color: data.color,
              ).animate()
                .scale(
                  delay: 200.ms,
                  duration: 600.ms,
                  curve: Curves.easeOutBack,
                ),
              const SizedBox(height: 48),
              Text(
                data.title,
                style: Theme.of(context).textTheme.headlineLarge,
                textAlign: TextAlign.center,
              ).animate()
                .fadeIn(delay: 400.ms)
                .slideY(begin: 0.2, end: 0),
              const SizedBox(height: AppSpacing.md),
              Text(
                data.description,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ).animate()
                .fadeIn(delay: 600.ms)
                .slideY(begin: 0.2, end: 0),
            ],
          ),
        ),
      ),
    );
  }
}