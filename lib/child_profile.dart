// child_profile.dart
import 'dart:math';

class ChildProfile {
  final String id; // ✅ 이름이 아니라 "고유 ID"로 저장/조회
  String name;
  String gender; // '남아' or '여아'
  DateTime birthDate;

  ChildProfile({
    required this.id,
    required this.name,
    required this.gender,
    required this.birthDate,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'gender': gender,
        'birthDate': birthDate.toIso8601String(),
      };

  factory ChildProfile.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? '').toString().trim();
    final name = (json['name'] ?? '이름없음').toString();
    final gender = (json['gender'] ?? '남아').toString();
    final birthDateRaw = (json['birthDate'] ?? '').toString();

    DateTime birthDate;
    try {
      birthDate = DateTime.parse(birthDateRaw);
    } catch (_) {
      birthDate = DateTime(2000, 1, 1);
    }

    return ChildProfile(
      id: id.isNotEmpty ? id : ChildProfile.newId(),
      name: name,
      gender: gender,
      birthDate: birthDate,
    );
  }

  /// 외부 패키지(uuid) 없이 고유키 생성
  static String newId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final r = Random().nextInt(1 << 32);
    return '${now.toRadixString(16)}_${r.toRadixString(16)}';
  }
}
