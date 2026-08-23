import 'dart:convert';

class KhatmaPlan {
  final String id;
  final String name;
  final int targetDays;
  final int currentJuz;
  final int currentPage; // Global page number 1-604
  final DateTime startDate;

  KhatmaPlan({
    required this.id,
    required this.name,
    required this.targetDays,
    required this.currentJuz,
    required this.currentPage,
    required this.startDate,
  });

  factory KhatmaPlan.defaultPlan() => KhatmaPlan(
        id: 'default',
        name: 'ختمة شهرية',
        targetDays: 30,
        currentJuz: 1,
        currentPage: 1,
        startDate: DateTime.now(),
      );

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'targetDays': targetDays,
      'currentJuz': currentJuz,
      'currentPage': currentPage,
      'startDate': startDate.toIso8601String(),
    };
  }

  factory KhatmaPlan.fromMap(Map<String, dynamic> map) {
    return KhatmaPlan(
      id: map['id'] ?? 'default',
      name: map['name'] ?? 'ختمتي',
      targetDays: map['targetDays'] ?? 30,
      currentJuz: map['currentJuz'] ?? 1,
      currentPage: map['currentPage'] ?? 1,
      startDate: DateTime.tryParse(map['startDate'] ?? '') ?? DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory KhatmaPlan.fromJson(String source) =>
      KhatmaPlan.fromMap(json.decode(source));

  KhatmaPlan copyWith({
    String? id,
    String? name,
    int? targetDays,
    int? currentJuz,
    int? currentPage,
    DateTime? startDate,
  }) {
    return KhatmaPlan(
      id: id ?? this.id,
      name: name ?? this.name,
      targetDays: targetDays ?? this.targetDays,
      currentJuz: currentJuz ?? this.currentJuz,
      currentPage: currentPage ?? this.currentPage,
      startDate: startDate ?? this.startDate,
    );
  }
}
