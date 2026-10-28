import 'exam_model.dart';

/// KPSS sessions use the official test totals, not approximate topic weights.
/// GY–GK is one 120-question, 130-minute session; field tests are separate.
/// The proposed server catalog and official sources are documented in analiz/.
enum KpssExamTrack { bachelor, associate, secondary, field }

KpssExamTrack? kpssTrackForExam(String id) => switch (id) {
  'kpss_bachelor_gygk' => KpssExamTrack.bachelor,
  'kpss_associate_gygk' => KpssExamTrack.associate,
  'kpss_secondary_gygk' => KpssExamTrack.secondary,
  _ when id.startsWith('kpss_field_') => KpssExamTrack.field,
  _ => null,
};

const kpssGeneralSubjects = <ExamSubject>[
  ExamSubject(
    id: 'general_ability',
    nameTr: 'Genel Yetenek',
    nameEn: 'General Ability',
    questionCount: 60,
    categoryKeys: ['Türkçe', 'Matematik', 'Genel Yetenek'],
  ),
  ExamSubject(
    id: 'general_knowledge',
    nameTr: 'Genel Kültür',
    nameEn: 'General Knowledge',
    questionCount: 60,
    categoryKeys: [
      'Tarih',
      'Coğrafya',
      'Vatandaşlık',
      'Güncel Bilgiler',
      'Genel Kültür',
    ],
  ),
];

const kpssExamDefinitions = <ExamDefinition>[
  ExamDefinition(
    id: 'kpss_bachelor_gygk',
    nameTr: "KPSS Lisans · Genel Yetenek–Genel Kültür",
    nameEn: "KPSS Bachelor’s · General Ability–General Knowledge",
    segment: 'kpss',
    durationSeconds: 7800,
    totalQuestions: 120,
    wrongAnswerDivisor: 4,
    subjects: kpssGeneralSubjects,
  ),
  ExamDefinition(
    id: 'kpss_associate_gygk',
    nameTr: "KPSS Ön Lisans · Genel Yetenek–Genel Kültür",
    nameEn: "KPSS Associate Degree · General Ability–General Knowledge",
    segment: 'kpss',
    durationSeconds: 7800,
    totalQuestions: 120,
    wrongAnswerDivisor: 4,
    subjects: kpssGeneralSubjects,
  ),
  ExamDefinition(
    id: 'kpss_secondary_gygk',
    nameTr: "KPSS Ortaöğretim · Genel Yetenek–Genel Kültür",
    nameEn: "KPSS Secondary Education · General Ability–General Knowledge",
    segment: 'kpss',
    durationSeconds: 7800,
    totalQuestions: 120,
    wrongAnswerDivisor: 4,
    subjects: kpssGeneralSubjects,
  ),
  ExamDefinition(
    id: 'kpss_field_business',
    nameTr: "KPSS Alan Bilgisi · İşletme",
    nameEn: "KPSS Field Knowledge · Business Administration",
    segment: 'kpss',
    durationSeconds: 3000,
    totalQuestions: 40,
    wrongAnswerDivisor: 4,
    subjects: [
      ExamSubject(
        id: 'business',
        nameTr: "İşletme",
        nameEn: "Business Administration",
        questionCount: 40,
        categoryKeys: ["İşletme"],
      ),
    ],
  ),
  ExamDefinition(
    id: 'kpss_field_accounting',
    nameTr: "KPSS Alan Bilgisi · Muhasebe",
    nameEn: "KPSS Field Knowledge · Accounting",
    segment: 'kpss',
    durationSeconds: 3000,
    totalQuestions: 40,
    wrongAnswerDivisor: 4,
    subjects: [
      ExamSubject(
        id: 'accounting',
        nameTr: "Muhasebe",
        nameEn: "Accounting",
        questionCount: 40,
        categoryKeys: ["Muhasebe"],
      ),
    ],
  ),
  ExamDefinition(
    id: 'kpss_field_law',
    nameTr: "KPSS Alan Bilgisi · Hukuk",
    nameEn: "KPSS Field Knowledge · Law",
    segment: 'kpss',
    durationSeconds: 3000,
    totalQuestions: 40,
    wrongAnswerDivisor: 4,
    subjects: [
      ExamSubject(
        id: 'law',
        nameTr: "Hukuk",
        nameEn: "Law",
        questionCount: 40,
        categoryKeys: ["Hukuk"],
      ),
    ],
  ),
  ExamDefinition(
    id: 'kpss_field_public_administration',
    nameTr: "KPSS Alan Bilgisi · Kamu Yönetimi",
    nameEn: "KPSS Field Knowledge · Public Administration",
    segment: 'kpss',
    durationSeconds: 3000,
    totalQuestions: 40,
    wrongAnswerDivisor: 4,
    subjects: [
      ExamSubject(
        id: 'public_administration',
        nameTr: "Kamu Yönetimi",
        nameEn: "Public Administration",
        questionCount: 40,
        categoryKeys: ["Kamu Yönetimi"],
      ),
    ],
  ),
  ExamDefinition(
    id: 'kpss_field_economics',
    nameTr: "KPSS Alan Bilgisi · İktisat",
    nameEn: "KPSS Field Knowledge · Economics",
    segment: 'kpss',
    durationSeconds: 3000,
    totalQuestions: 40,
    wrongAnswerDivisor: 4,
    subjects: [
      ExamSubject(
        id: 'economics',
        nameTr: "İktisat",
        nameEn: "Economics",
        questionCount: 40,
        categoryKeys: ["İktisat"],
      ),
    ],
  ),
  ExamDefinition(
    id: 'kpss_field_finance',
    nameTr: "KPSS Alan Bilgisi · Maliye",
    nameEn: "KPSS Field Knowledge · Public Finance",
    segment: 'kpss',
    durationSeconds: 3000,
    totalQuestions: 40,
    wrongAnswerDivisor: 4,
    subjects: [
      ExamSubject(
        id: 'finance',
        nameTr: "Maliye",
        nameEn: "Public Finance",
        questionCount: 40,
        categoryKeys: ["Maliye"],
      ),
    ],
  ),
  ExamDefinition(
    id: 'kpss_field_international_relations',
    nameTr: "KPSS Alan Bilgisi · Uluslararası İlişkiler",
    nameEn: "KPSS Field Knowledge · International Relations",
    segment: 'kpss',
    durationSeconds: 3000,
    totalQuestions: 40,
    wrongAnswerDivisor: 4,
    subjects: [
      ExamSubject(
        id: 'international_relations',
        nameTr: "Uluslararası İlişkiler",
        nameEn: "International Relations",
        questionCount: 40,
        categoryKeys: ["Uluslararası İlişkiler"],
      ),
    ],
  ),
  ExamDefinition(
    id: 'kpss_field_labour_economics',
    nameTr: "KPSS Alan Bilgisi · Çalışma Ekonomisi ve Endüstri İlişkileri",
    nameEn: "KPSS Field Knowledge · Labour Economics and Industrial Relations",
    segment: 'kpss',
    durationSeconds: 3000,
    totalQuestions: 40,
    wrongAnswerDivisor: 4,
    subjects: [
      ExamSubject(
        id: 'labour_economics',
        nameTr: "Çalışma Ekonomisi ve Endüstri İlişkileri",
        nameEn: "Labour Economics and Industrial Relations",
        questionCount: 40,
        categoryKeys: ["Çalışma Ekonomisi ve Endüstri İlişkileri"],
      ),
    ],
  ),
  ExamDefinition(
    id: 'kpss_field_statistics',
    nameTr: "KPSS Alan Bilgisi · İstatistik",
    nameEn: "KPSS Field Knowledge · Statistics",
    segment: 'kpss',
    durationSeconds: 3600,
    totalQuestions: 40,
    wrongAnswerDivisor: 4,
    subjects: [
      ExamSubject(
        id: 'statistics',
        nameTr: "İstatistik",
        nameEn: "Statistics",
        questionCount: 40,
        categoryKeys: ["İstatistik"],
      ),
    ],
  ),
];

const kpssAdditionalCategoryLabels = <(String, String)>[
  ("Genel Yetenek", "General Ability"),
  ("Genel Kültür", "General Knowledge"),
  ("İşletme", "Business Administration"),
  ("Muhasebe", "Accounting"),
  ("Hukuk", "Law"),
  ("Kamu Yönetimi", "Public Administration"),
  ("İktisat", "Economics"),
  ("Maliye", "Public Finance"),
  ("Uluslararası İlişkiler", "International Relations"),
  (
    "Çalışma Ekonomisi ve Endüstri İlişkileri",
    "Labour Economics and Industrial Relations",
  ),
  ("İstatistik", "Statistics"),
];
