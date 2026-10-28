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
  };
}
