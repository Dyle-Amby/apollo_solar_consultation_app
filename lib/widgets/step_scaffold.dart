import 'package:flutter/material.dart';

class StepScaffold extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final String title;
  final Widget child;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final bool isLastStep;
  final bool showBack;

  const StepScaffold({
    Key? key,
    required this.currentStep,
    required this.totalSteps,
    required this.title,
    required this.child,
    required this.onNext,
    required this.onBack,
    this.isLastStep = false,
    this.showBack = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: SafeArea(
        child: Column(
          children: [

            // ── Top bar ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [

                  // Back arrow
                  GestureDetector(
                    onTap: onBack,
                    child: Icon(
                      Icons.chevron_left,
                      color: showBack
                          ? const Color(0xFF1B2B6B)
                          : Colors.transparent,
                      size: 28,
                    ),
                  ),

                  // Step counter + title
                  Column(
                    children: [
                      Text(
                        'Step $currentStep of $totalSteps',
                        style: const TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xFF1B2B6B),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  // Save icon
                  const Icon(
                    Icons.save_outlined,
                    color: Color(0xFF1B2B6B),
                    size: 24,
                  ),
                ],
              ),
            ),

            // ── Progress bar ─────────────────────────────────
            LinearProgressIndicator(
              value: currentStep / totalSteps,
              backgroundColor: const Color(0xFFDDDDDD),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF1B2B6B),
              ),
              minHeight: 4,
            ),

            // ── Scrollable content ───────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: child,
              ),
            ),

            // ── Bottom buttons ───────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              decoration: const BoxDecoration(
                color: Color(0xFFF0F2F5),
              ),
              child: Row(
                children: [

                  // Back button
                  if (showBack) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onBack,
                        icon: const Icon(
                          Icons.chevron_left,
                          size: 18,
                        ),
                        label: const Text('Back'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Color(0xFFDDDDDD)),
                          foregroundColor: const Color(0xFF1A1A1A),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],

                  // Next / Complete button
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: onNext,
                      icon: Icon(
                        isLastStep
                            ? Icons.check_circle_outline
                            : Icons.chevron_right,
                        color: Colors.white,
                        size: 18,
                      ),
                      label: Text(
                        isLastStep ? 'Complete Consultation' : 'Next',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isLastStep
                            ? const Color(0xFFE8830A)
                            : const Color(0xFF1B2B6B),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}