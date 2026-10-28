import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/models/exam_catalog_defaults.dart';
import 'package:pomodoro/models/exam_model.dart';
import 'package:pomodoro/models/exam_reward_policy.dart';

void main() {
  test('twenty exam reward policies have the exact requested full amounts', () {
    const expected = {
      'lgs_verbal': 60,
      'lgs_quantitative': 70,
      'ydt': 95,
      'tus_basic': 110,
      'tus_clinical': 110,
      'dus': 120,
      'tyt': 130,
      'ayt': 145,
      'kpss_bachelor_gygk': 105,
      'kpss_associate_gygk': 105,
      'kpss_secondary_gygk': 105,
      'kpss_field_business': 40,
      'kpss_field_accounting': 40,
      'kpss_field_law': 40,
      'kpss_field_public_administration': 40,
      'kpss_field_economics': 40,
      'kpss_field_finance': 40,
      'kpss_field_international_relations': 40,
      'kpss_field_labour_economics': 40,
      'kpss_field_statistics': 50,
    };
    expect(ExamRewardPolicy.byExam.keys, unorderedEquals(expected.keys));
    for (final entry in expected.entries) {
      expect(
        ExamRewardPolicy.byExam[entry.key]!.sand,
        entry.value,
        reason: entry.key,
      );
    }
    expect(ExamRewardPolicy.byExam['dus']!.points, 30);
    expect(ExamRewardPolicy.byExam['ayt']!.points, 36);
  });
  test(
    'explicit old and zero server snapshots override the current fallback',
    () {
      final definition = offlineExamCatalog.byId('ayt')!;
      expect(definition.fullRewardCoins, 145);
      final old = ExamDefinition.fromJson({
        ...definition.toJson(),
        'reward_coins': 7,
        'reward_points': 36,
        'reward_policy_version': 1,
      })!;
      expect(old.fullRewardCoins, 7);
      expect(old.effectiveRewardPolicyVersion, 1);
      final restored = ExamDefinition.fromJson(old.toJson())!;
      expect(restored.fullRewardCoins, 7);
      final zero = ExamDefinition.fromJson({
        ...definition.toJson(),
        'reward_coins': 0,
        'reward_points': 0,
      })!;
      expect(zero.fullRewardCoins, 0);
      expect(zero.fullRewardPoints, 0);
    },
  );
  test(
    'new AYT90-minute policy is72 sand/18 points and subminute gives no rewards',
    () {
      final policy = ExamRewardPolicy.byExam['ayt']!;
      expect(policy.sand * 5400 ~/ 10800, 72);
      expect(5400 ~/ 300, 18);
      for (final seconds in [1, 59]) {
        expect(policy.sand * seconds ~/ 10800, 0);
        expect(seconds ~/ 300, 0);
      }
    },
  );
  test(
    'invalid negative reward metadata is rejected without affecting question metadata',
    () {
      final d = offlineExamCatalog.byId('tyt')!.toJson();
      expect(ExamDefinition.fromJson({...d, 'reward_coins': -1}), isNull);
      expect(ExamDefinition.fromJson({...d, 'reward_points': -1}), isNull);
      expect(ExamDefinition.fromJson(d)!.totalQuestions, 120);
    },
  );
}
