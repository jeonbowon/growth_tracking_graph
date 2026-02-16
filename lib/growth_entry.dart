// growth_entry.dart
class GrowthEntry {
  final double? height; // cm
  final double? weight; // kg
  final double? bmi; // kg/m^2 (저장값, 있을 수도/없을 수도)
  final int ageMonths;
  final String date; // yyyy-MM-dd

  const GrowthEntry({
    required this.height,
    required this.weight,
    required this.bmi,
    required this.ageMonths,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'height': height,
        'weight': weight,
        'bmi': bmi,
        'ageMonths': ageMonths,
        'date': date,
      };

  factory GrowthEntry.fromJson(Map<String, dynamic> json) => GrowthEntry(
        height: (json['height'] as num?)?.toDouble(),
        weight: (json['weight'] as num?)?.toDouble(),
        bmi: (json['bmi'] as num?)?.toDouble(),
        ageMonths: (json['ageMonths'] as num?)?.toInt() ?? 0,
        date: (json['date'] ?? '').toString(),
      );
}
