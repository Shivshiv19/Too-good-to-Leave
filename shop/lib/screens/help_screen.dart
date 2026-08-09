import 'package:flutter/material.dart';
import 'package:too_good_to_leave_shop/app/theme/app_theme.dart';
import 'package:too_good_to_leave_shop/design_system/components/max_width_body.dart';
import 'package:too_good_to_leave_shop/design_system/foundations/breakpoints.dart';
import 'package:too_good_to_leave_shop/design_system/foundations/dimens.dart';

const _faqs = [
  (
    'How do I list a bag?',
    'Go to the Bags tab, tap "Add bag," fill in the details, and set its '
        'status to Live when you\'re ready for customers to see it.',
  ),
  (
    'How do I confirm a pickup?',
    'Open the order from the Orders tab and ask the customer for their '
        '6-character pickup code — enter it under "Confirm pickup."',
  ),
  (
    'What happens if a customer doesn\'t show up?',
    'Once the pickup window closes, the order moves to the "Overdue" '
        'section. Open it and tap "Mark as no-show" to record it.',
  ),
  (
    'When do I get paid?',
    'Go to the Payments tab and tap "Request payout" — it covers every '
        'collected order not already paid out. This app doesn\'t process '
        'real payments, so no money actually moves in this build.',
  ),
  (
    'What\'s the commission rate?',
    'The Payments tab breaks down gross, commission, and net for every '
        'collected order — commission is 20% (illustrative, not a real '
        'live rate).',
  ),
];

/// The platform's grievance officer — Consumer Protection (E-commerce)
/// Rules 2020 mandated disclosure (the customer app's own
/// `core/domain/grievance_officer.dart`, amendment A19, documents the same
/// requirement). One shared platform-level officer, not per-shop, so this
/// is a fixed constant rather than something a shop edits.
const _grievanceOfficerName = 'Grievance Officer, Too Good To Leave';
const _grievanceOfficerEmail = 'grievance@toogoodtoleave.example';
const _grievanceOfficerPhone = '+91 80 0000 0000';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.surfaceBase,
      appBar: AppBar(
        backgroundColor: colors.surfaceBase,
        title: Text('Help & support', style: context.type.title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.x4),
        child: MaxWidthBody(
          maxWidth: Breakpoints.formMaxWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Frequently asked', style: context.type.title),
              const SizedBox(height: Space.x3),
              ...(_faqs.map(
                (faq) => Padding(
                  padding: const EdgeInsets.only(bottom: Space.x2),
                  child: _FaqTile(question: faq.$1, answer: faq.$2),
                ),
              )),
              const SizedBox(height: Space.x6),
              Text('Contact', style: context.type.title),
              const SizedBox(height: Space.x3),
              Container(
                padding: const EdgeInsets.all(Space.x4),
                decoration: BoxDecoration(
                  color: colors.surfaceRaised,
                  borderRadius: BorderRadius.circular(Radii.card),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Grievance officer',
                      style: context.type.label.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: Space.x1),
                    Text(_grievanceOfficerName, style: context.type.body),
                    Text(
                      _grievanceOfficerEmail,
                      style: context.type.body.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    Text(
                      _grievanceOfficerPhone,
                      style: context.type.body.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: Space.x2),
                    Text(
                      'Published per the Consumer Protection (E-commerce) '
                      'Rules, 2020.',
                      style: context.type.caption.copyWith(
                        color: colors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Material(
      color: colors.surfaceRaised,
      borderRadius: BorderRadius.circular(Radii.card),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Text(question, style: context.type.body),
        childrenPadding: const EdgeInsets.fromLTRB(
          Space.x4,
          0,
          Space.x4,
          Space.x4,
        ),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            answer,
            style: context.type.body.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}
