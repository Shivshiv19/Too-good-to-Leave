import 'package:surplus_marketplace/features/account/domain/entities/help_category.dart';

/// §5f.6/§5f.7. `body` is the restricted markdown subset (§5f.7).
final class HelpTopic {
  const HelpTopic({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    this.relatedTopicIds = const [],
  });

  final String id;
  final String title;
  final String body;
  final HelpCategory category;
  final List<String> relatedTopicIds;
}
