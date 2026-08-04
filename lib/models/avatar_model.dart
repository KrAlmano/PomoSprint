import 'package:flutter/material.dart';

class AvatarCharacter {
  final String id;
  final String name;
  final String nameEn;
  final String emoji;
  final String imagePath;
  final Color backgroundColor;
  final int requiredMinutes; // Kilitsiz seçim için 0
  final String accessoryDescription;

  const AvatarCharacter({
    required this.id,
    required this.name,
    required this.nameEn,
    required this.emoji,
    required this.imagePath,
    required this.backgroundColor,
    required this.requiredMinutes,
    required this.accessoryDescription,
  });

  bool isUnlocked(int totalStudyMinutes) => true; // Tüm 16 avatar kilitsiz!

  String get unlockLabel => 'Açık';

  /// Dil seçimine göre avatarın görünen adını döndürür.
  String getName(bool isTurkish) => isTurkish ? name : nameEn;

  static List<AvatarCharacter> allAvatars() => const [
        AvatarCharacter(
          id: 'avatar_1_gamer',
          name: 'Oyuncu Kum Saati',
          nameEn: 'Gamer Hourglass',
          emoji: '🎧',
          imagePath: 'assets/avatars/avatar_1_gamer.png',
          backgroundColor: Color(0xFFE0F2FE),
          requiredMinutes: 0,
          accessoryDescription: 'Kulaklıklı Oyuncu',
        ),
        AvatarCharacter(
          id: 'avatar_2_glasses',
          name: 'Gözlüklü Kum Saati',
          nameEn: 'Glasses Hourglass',
          emoji: '👓',
          imagePath: 'assets/avatars/avatar_2_glasses.png',
          backgroundColor: Color(0xFFDCFCE7),
          requiredMinutes: 0,
          accessoryDescription: 'Yuvarlak Gözlüklü',
        ),
        AvatarCharacter(
          id: 'avatar_3_gentleman',
          name: 'Centilmen Kum Saati',
          nameEn: 'Gentleman Hourglass',
          emoji: '🎩',
          imagePath: 'assets/avatars/avatar_3_gentleman.png',
          backgroundColor: Color(0xFFFFEDD5),
          requiredMinutes: 0,
          accessoryDescription: 'Şapkalı & Bıyıklı',
        ),
        AvatarCharacter(
          id: 'avatar_4_bowtie',
          name: 'Hakim Kum Saati',
          nameEn: 'Judge Hourglass',
          emoji: '⚖️',
          imagePath: 'assets/avatars/avatar_4_bowtie.png',
          backgroundColor: Color(0xFFFEF9C3),
          requiredMinutes: 0,
          accessoryDescription: 'Hakim Tokmaklı',
        ),
        AvatarCharacter(
          id: 'avatar_5_flower',
          name: 'Çiçekli Kum Saati',
          nameEn: 'Flower Hourglass',
          emoji: '🌸',
          imagePath: 'assets/avatars/avatar_5_flower.png',
          backgroundColor: Color(0xFFFCE7F3),
          requiredMinutes: 0,
          accessoryDescription: 'Çiçek Taçlı',
        ),
        AvatarCharacter(
          id: 'avatar_6_cool',
          name: 'Süslü Kum Saati',
          nameEn: 'Glam Hourglass',
          emoji: '💅',
          imagePath: 'assets/avatars/avatar_6_cool.png',
          backgroundColor: Color(0xFFFEF08A),
          requiredMinutes: 0,
          accessoryDescription: 'Süslü Gözlüklü',
        ),
        AvatarCharacter(
          id: 'avatar_7_scholar',
          name: 'Mezun Kum Saati',
          nameEn: 'Graduate Hourglass',
          emoji: '🎓',
          imagePath: 'assets/avatars/avatar_7_scholar.png',
          backgroundColor: Color(0xFFDBEAFE),
          requiredMinutes: 0,
          accessoryDescription: 'Kepli & Akademik',
        ),
        AvatarCharacter(
          id: 'avatar_8_striped',
          name: 'Sevimli Kum Saati',
          nameEn: 'Cute Hourglass',
          emoji: '👔',
          imagePath: 'assets/avatars/avatar_8_striped.png',
          backgroundColor: Color(0xFFE0E7FF),
          requiredMinutes: 0,
          accessoryDescription: 'Çizgili Papyonlu',
        ),
        AvatarCharacter(
          id: 'avatar_9_viking',
          name: 'Viking Kum Saati',
          nameEn: 'Viking Hourglass',
          emoji: '🛡️',
          imagePath: 'assets/avatars/avatar_9_viking.png',
          backgroundColor: Color(0xFFFFE4E6),
          requiredMinutes: 0,
          accessoryDescription: 'Viking Miğferli',
        ),
        AvatarCharacter(
          id: 'avatar_10_dentist',
          name: 'Dişçi Kum Saati',
          nameEn: 'Dentist Hourglass',
          emoji: '🦷',
          imagePath: 'assets/avatars/avatar_10_dentist.png',
          backgroundColor: Color(0xFFE0F2FE),
          requiredMinutes: 0,
          accessoryDescription: 'Dişçi Kum Saati',
        ),
        AvatarCharacter(
          id: 'avatar_11_doctor',
          name: 'Doktor Kum Saati',
          nameEn: 'Doctor Hourglass',
          emoji: '🩺',
          imagePath: 'assets/avatars/avatar_11_doctor.png',
          backgroundColor: Color(0xFFCCFBF1),
          requiredMinutes: 0,
          accessoryDescription: 'Stetoskoplu Doktor',
        ),
        AvatarCharacter(
          id: 'avatar_12_builder',
          name: 'Mimar Kum Saati',
          nameEn: 'Architect Hourglass',
          emoji: '🪖',
          imagePath: 'assets/avatars/avatar_12_builder.png',
          backgroundColor: Color(0xFFFEF3C7),
          requiredMinutes: 0,
          accessoryDescription: 'Sarı Baretli Mimar',
        ),
        AvatarCharacter(
          id: 'avatar_13_pilot',
          name: 'Pilot Kum Saati',
          nameEn: 'Pilot Hourglass',
          emoji: '✈️',
          imagePath: 'assets/avatars/avatar_13_pilot.png',
          backgroundColor: Color(0xFFE0F2FE),
          requiredMinutes: 0,
          accessoryDescription: 'Kanatlı Pilot Şapkalı',
        ),
        AvatarCharacter(
          id: 'avatar_14_teacher',
          name: 'Öğretmen Kum Saati',
          nameEn: 'Teacher Hourglass',
          emoji: '📚',
          imagePath: 'assets/avatars/avatar_14_teacher.png',
          backgroundColor: Color(0xFFFDE68A),
          requiredMinutes: 0,
          accessoryDescription: 'Gözlüklü & Kepli Öğretmen',
        ),
        AvatarCharacter(
          id: 'avatar_15_athlete',
          name: 'Sporcu Kum Saati',
          nameEn: 'Athlete Hourglass',
          emoji: '⚽',
          imagePath: 'assets/avatars/avatar_15_athlete.png',
          backgroundColor: Color(0xFFDCFCE7),
          requiredMinutes: 0,
          accessoryDescription: 'Dinamik Sporcu',
        ),
        AvatarCharacter(
          id: 'avatar_16_basic',
          name: 'Klasik Kum Saati',
          nameEn: 'Classic Hourglass',
          emoji: '⌛',
          imagePath: 'assets/avatars/avatar_16_basic.png',
          backgroundColor: Color(0xFFF3F4F6),
          requiredMinutes: 0,
          accessoryDescription: 'Sade & Klasik Kum Saati',
        ),
      ];
}
