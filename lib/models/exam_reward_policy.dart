/// Client reference for the proposed32 full-completion policy. Accepted server
/// snapshots always take precedence; this never grants a reward locally.
class ExamRewardPolicy {
  const ExamRewardPolicy(this.points, this.sand);
  final int points;
  final int sand;

  static const version = 2;
  static const byExam = <String, ExamRewardPolicy>{
    'lgs_verbal': ExamRewardPolicy(15, 60),
    'lgs_quantitative': ExamRewardPolicy(16, 70),
    'ydt': ExamRewardPolicy(24, 95),
    'tus_basic': ExamRewardPolicy(27, 110),
    'tus_clinical': ExamRewardPolicy(27, 110),
    'dus': ExamRewardPolicy(30, 120),
    'tyt': ExamRewardPolicy(33, 130),
    'ayt': ExamRewardPolicy(36, 145),
    'kpss_bachelor_gygk': ExamRewardPolicy(26, 105),
    'kpss_associate_gygk': ExamRewardPolicy(26, 105),
    'kpss_secondary_gygk': ExamRewardPolicy(26, 105),
    'kpss_field_business': ExamRewardPolicy(10, 40),
    'kpss_field_accounting': ExamRewardPolicy(10, 40),
    'kpss_field_law': ExamRewardPolicy(10, 40),
    'kpss_field_public_administration': ExamRewardPolicy(10, 40),
    'kpss_field_economics': ExamRewardPolicy(10, 40),
    'kpss_field_finance': ExamRewardPolicy(10, 40),
    'kpss_field_international_relations': ExamRewardPolicy(10, 40),
    'kpss_field_labour_economics': ExamRewardPolicy(10, 40),
    'kpss_field_statistics': ExamRewardPolicy(12, 50),
  };
}
