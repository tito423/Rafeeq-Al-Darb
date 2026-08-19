/// Zikr model — represents one dhikr/supplication entry
class Zikr {
  final int id;
  final String category;
  final String content;
  final String count;
  final String description;
  final String reference;
  final String fadl; // virtue/merit text

  const Zikr({
    required this.id,
    required this.category,
    required this.content,
    required this.count,
    required this.description,
    required this.reference,
    this.fadl = '',
  });

  int get countInt {
    final n = int.tryParse(count.replaceAll(RegExp(r'[^0-9]'), ''));
    return (n != null && n > 0) ? n : 1;
  }

  factory Zikr.fromMap(Map<String, dynamic> m) => Zikr(
        id: m['id'] as int? ?? 0,
        category: m['category'] as String? ?? '',
        content: m['content'] as String? ?? '',
        count: m['count'] as String? ?? '1',
        description: m['description'] as String? ?? '',
        reference: m['reference'] as String? ?? '',
        fadl: m['fadl'] as String? ?? '',
      );
}
