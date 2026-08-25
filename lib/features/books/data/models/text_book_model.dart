class TextBookModel {
  final String id;
  final String title;
  final String author;
  final List<BookChapter> chapters;

  TextBookModel({
    required this.id,
    required this.title,
    required this.author,
    required this.chapters,
  });

  factory TextBookModel.fromJson(Map<String, dynamic> json) {
    return TextBookModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      author: json['author'] ?? '',
      chapters: (json['chapters'] as List<dynamic>?)
              ?.map((c) => BookChapter.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class BookChapter {
  final String title;
  final String content;

  BookChapter({
    required this.title,
    required this.content,
  });

  factory BookChapter.fromJson(Map<String, dynamic> json) {
    return BookChapter(
      title: json['title'] ?? '',
      content: json['content'] ?? '',
    );
  }
}
