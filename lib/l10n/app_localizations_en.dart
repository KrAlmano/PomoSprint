// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get navTimer => 'Timer';

  @override
  String get navSocial => 'Social';

  @override
  String get navReports => 'Reports';

  @override
  String get navProfile => 'Profile';

  @override
  String get navHistory => 'History';

  @override
  String get navRanking => 'Leaderboard';

  @override
  String get navCategories => 'Categories';

  @override
  String get titleTimer => 'PomoSprint';

  @override
  String get titleReports => 'Study Reports & History';

  @override
  String get titleRanking => 'Leaderboard';

  @override
  String get titleSocial => 'Virtual Library & Tables';

  @override
  String get titleCategories => 'Course Categories';

  @override
  String get selectSubject => 'SELECT SUBJECT';

  @override
  String get addSubject => 'Add Subject';

  @override
  String get btnStart => 'START';

  @override
  String get btnPause => 'PAUSE';

  @override
  String get btnReset => 'RESET';

  @override
  String get modePomodoro => 'Pomodoro';

  @override
  String get modeShortBreak => 'Short Break';

  @override
  String get modeLongBreak => 'Long Break';

  @override
  String get dailyStreak => 'Daily Streak';

  @override
  String get dailyGoal => 'Daily Goal';

  @override
  String get sessionCompleted => 'Congrats! Session Completed 🎉';

  @override
  String get durationPlanning => 'Duration Planning';

  @override
  String get pauseCreditAvailable => '1/1 Pause Credit Available';

  @override
  String get pauseCreditUsed => '0/1 Pause Credit (Limit Reached)';

  @override
  String focusTimeMinutes(Object minutes) {
    return '$minutes MIN FOCUS TIME';
  }

  @override
  String get catMath => 'Mathematics';

  @override
  String get catPhysics => 'Physics';

  @override
  String get catHistory => 'History';

  @override
  String get catChemistry => 'Chemistry';

  @override
  String get catBiology => 'Biology';

  @override
  String get catLiterature => 'Literature';

  @override
  String get catEnglish => 'English';

  @override
  String get avatarGamer => 'Gamer Apprentice';

  @override
  String get avatarGamerDesc => 'Starter character. Complete 1 session.';

  @override
  String get avatarGlasses => 'Glasses Scholar';

  @override
  String get avatarGlassesDesc => 'Complete 5 sessions to unlock.';

  @override
  String get avatarGentleman => 'Gentleman';

  @override
  String get avatarGentlemanDesc => 'Complete 10 sessions to unlock.';

  @override
  String get avatarCyberpunk => 'Cyberpunk';

  @override
  String get avatarCyberpunkDesc => 'Complete 15 sessions to unlock.';

  @override
  String get avatarCat => 'Cat Lover';

  @override
  String get avatarCatDesc => 'Complete 20 sessions to unlock.';

  @override
  String get avatarCoder => 'Coding Expert';

  @override
  String get avatarCoderDesc => 'Complete 30 sessions to unlock.';

  @override
  String get avatarNinja => 'Ninja';

  @override
  String get avatarNinjaDesc => 'Complete 50 sessions to unlock.';

  @override
  String get avatarAstronaut => 'Astronaut';

  @override
  String get avatarAstronautDesc => 'Complete 75 sessions to unlock.';

  @override
  String get avatarViking => 'Viking';

  @override
  String get avatarVikingDesc => 'Complete 100 sessions to unlock.';

  @override
  String get selectCharacter => 'Choose Your Character';

  @override
  String get selectCharacterSub =>
      'Choose the character to accompany your focus sessions.';

  @override
  String get confirmSelection => 'Confirm Selection';

  @override
  String get leagueAwardsTitle => 'League Achievements';

  @override
  String get leagueAwardsSub =>
      'Earned by finishing 1st, 2nd, or 3rd in a league period.';

  @override
  String get leagueAwardLockedTitle => 'This Avatar Is Locked';

  @override
  String get leagueAwardLockedBody =>
      'To earn this avatar, you need to finish 1st, 2nd, or 3rd in this tier during a league period. It can\'t be purchased.';

  @override
  String get leagueAwardLockedOk => 'Got It';

  @override
  String get lockedCharacter => 'Locked Character';

  @override
  String get welcomeBackTitle => 'Welcome back. Ready to focus?';

  @override
  String get emailOrUsername => 'Username or Email';

  @override
  String get password => 'Password';

  @override
  String get loginBtn => 'Sign In';

  @override
  String get forgotPassword => 'Forgot Password?';

  @override
  String get noAccountText => 'Don\'t have an account? ';

  @override
  String get signUpLink => 'Sign Up';

  @override
  String get googleLogin => 'Sign in with Google';

  @override
  String get resendVerificationLink => 'Resend Verification Email 📬';

  @override
  String get errFillFields => 'Please fill in all fields.';

  @override
  String get errInvalidCredentials => 'Invalid email or password!';

  @override
  String get verificationResentMsg =>
      '📬 Verification link resent. Please check your inbox.';

  @override
  String get passwordResetMsg =>
      'We sent a password reset link to your email. Check your inbox (and spam folder).';

  @override
  String get errEnterEmailForReset =>
      'Enter your email address first to reset your password.';

  @override
  String get createAccountTitle => 'Create New Account';

  @override
  String get createAccountSub => 'Join PomoSprint and start focusing.';

  @override
  String get orDivider => 'OR';

  @override
  String get fullName => 'Full Name';

  @override
  String get fullNameHint => 'e.g. Jane Doe';

  @override
  String get termsAgree =>
      'I agree to the Terms of Service and Privacy Policy.';

  @override
  String get termsAgreePrefix => 'I agree to the ';

  @override
  String get termsLinkTerms => 'Terms of Service';

  @override
  String get termsAgreeConnector => ' and ';

  @override
  String get termsLinkPrivacy => 'Privacy Policy';

  @override
  String get termsAgreeSuffix => '.';

  @override
  String get privacyPolicyLink => 'Privacy Policy';

  @override
  String get termsOfServiceLink => 'Terms of Service';

  @override
  String get updatesAgree => 'I want to receive updates and new features.';

  @override
  String get registerBtn => 'Sign Up';

  @override
  String get alreadyHaveAccount => 'Already have an account? ';

  @override
  String get verificationSentTitle => 'Verification Email Sent! 📬';

  @override
  String verificationSentDesc(Object email) {
    return 'We sent a verification link to $email.\n\nPlease open your inbox and click the verification link. Once verified, you can sign in!';
  }

  @override
  String get backToLoginBtn => 'Got it, Back to Sign In';

  @override
  String get errFillEmailPassword => 'Please enter your email and password.';

  @override
  String get errShortPassword => 'Password must be at least 6 characters.';

  @override
  String get errAcceptTerms => 'Please accept the terms to continue.';

  @override
  String get errEmailExists =>
      'This email address is already registered! Please sign in.';

  @override
  String get reportsTabSubject => 'Subject Reports';

  @override
  String get reportsTabHistory => 'Study History';

  @override
  String get totalFocusTime => 'Total Focus';

  @override
  String get subjectBreakdown => 'Subject Focus Breakdown';

  @override
  String get noDataTitle => 'No detailed report yet, start studying! 🚀';

  @override
  String get noDataDesc =>
      'When you start the timer and complete your first Pomodoro, your reports will appear here.';

  @override
  String get startStudyingBtn => 'Start Studying Now';

  @override
  String get minutesUnit => 'min';

  @override
  String get hoursUnit => 'h';

  @override
  String get completedSessions => 'Completed Sessions';

  @override
  String sessionsCount(Object count) {
    return '$count Sessions';
  }

  @override
  String get weekly => 'Weekly';

  @override
  String get allTime => 'All Time';

  @override
  String get noUsersInRanking => 'No users registered in leaderboard yet.';

  @override
  String minutesStudy(Object minutes) {
    return '$minutes min study';
  }

  @override
  String get userDefault => 'User';

  @override
  String get youBadge => '(You)';

  @override
  String get virtualLibrary => 'Virtual Library & Tables';

  @override
  String studentsStudying(Object count) {
    return '$count Students Studying at Tables';
  }

  @override
  String get emptyTables => 'Tables Empty - Be the First to Sit!';

  @override
  String get leaveTable => 'Leave Table';

  @override
  String get joinTable => 'Join Table';

  @override
  String get tableFull => 'Table Full';

  @override
  String get silentRoom => 'Silent Only';

  @override
  String get chatPlaceholder => 'Type a message...';

  @override
  String get addCategoryTitle => 'Add New Category';

  @override
  String get addCategorySub =>
      'Create a new course or subject to organize your study.';

  @override
  String get categoryNameHint => 'Category Name (e.g. History)';

  @override
  String get chooseColor => 'Choose Color';

  @override
  String addedToast(Object name) {
    return '$name added!';
  }

  @override
  String get deleteBtn => 'Delete';

  @override
  String get profileTitle => 'Profile & Settings';

  @override
  String get editProfile => 'PROFILE INFORMATION';

  @override
  String get nameSurname => 'Full Name';

  @override
  String get email => 'Email Address';

  @override
  String get emailReadonlyHint =>
      'Email address cannot be changed for security reasons.';

  @override
  String get appLanguage => 'APP LANGUAGE';

  @override
  String get langTr => 'Turkish 🇹🇷';

  @override
  String get langEn => 'English 🇬🇧';

  @override
  String get changeAvatar => 'Change Avatar';

  @override
  String get totalPoints => 'Total Points';

  @override
  String get streakDays => 'Streak Days';

  @override
  String get deleteAccount => 'Delete Account';

  @override
  String get logout => 'Log Out';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get notifications => 'Notifications';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get preferences => 'PREFERENCES';

  @override
  String get nameUpdatedSuccess => 'Profile name updated successfully!';

  @override
  String get pointsCaption => 'POINTS';

  @override
  String get pauseUsedSnackbar =>
      'You\'ve used your 1/1 pause credit! You can\'t pause again.';

  @override
  String get pauseLimitTitle => 'Pause Limit Reached!';

  @override
  String get pauseLimitContent =>
      'You\'ve already used your one-time pause for this session.\n\nIf you stop now, your session progress will be completely reset.';

  @override
  String get resetAndStop => 'Reset & Stop';

  @override
  String get continueBtn => 'Continue';

  @override
  String get sessionReset => 'Your session progress has been reset.';

  @override
  String get dailyGoalLabel => 'Daily Goal';

  @override
  String get setDailyGoalTitle => 'Set Daily Goal';

  @override
  String get setDailyGoalSub =>
      'How many Pomodoros do you want to complete today?';

  @override
  String get saveGoalBtn => 'Save Goal';

  @override
  String get efficiencyScoreCaption => 'EFFICIENCY SCORE';

  @override
  String get efficiencyMsgExceeded => 'You exceeded your goal, amazing! 🔥';

  @override
  String get efficiencyMsgClose => 'You\'re getting close to your goal!';

  @override
  String get efficiencyMsgLow => 'You could study a bit more today';

  @override
  String get todayStudiesHeader => 'Today\'s Studies';

  @override
  String get detailsLink => 'Details';

  @override
  String get weeklyDistTitle => 'Weekly Distribution';

  @override
  String get weeklyDistSub => 'Summary of the last 7 days';

  @override
  String get hourToggle => 'Hours';

  @override
  String get totalLabel => 'Total';

  @override
  String get efficiencyTipHeader => 'Efficiency Tip';

  @override
  String get hourAbbr => 'h';

  @override
  String get minAbbr => 'm';

  @override
  String get tip1 =>
      'Studying math in the morning increases your focus capacity by 15%.';

  @override
  String get tip2 =>
      'Take a 5-minute break after every 25-minute focus session.';

  @override
  String get tip3 =>
      'Completing 4 pomodoros a day builds a consistent study habit.';

  @override
  String get tip4 =>
      'Studying difficult topics in the morning improves productivity.';

  @override
  String get addBtn => 'Add';

  @override
  String get onboardingSelectOptionError => 'Please select an option.';

  @override
  String get onboardingTimeoutError =>
      'Connection timed out. Please check your internet and try again.';

  @override
  String onboardingGenericError(Object error) {
    return 'Something went wrong, please try again: $error';
  }

  @override
  String get onboardingAddCategoryTitle => 'Add Category';

  @override
  String get onboardingCategoryHint => 'Category name';

  @override
  String get onboardingMaxCategoriesMsg => 'You can select up to 8 categories.';

  @override
  String get onboardingWelcomeTitle => 'Welcome! 👋';

  @override
  String get onboardingWelcomeBody =>
      'I\'m your focus companion. Before I join you, can I know your birth year?';

  @override
  String get onboardingSegmentTitle => 'So, which journey are you on?';

  @override
  String get onboardingSegmentBody =>
      'What will we study together? Let me pick the best categories for you.';

  @override
  String get onboardingSegmentLgs => '🎓  LGS';

  @override
  String get onboardingSegmentYks => '📚  YKS';

  @override
  String get onboardingSegmentUniversity => '🏛️  University';

  @override
  String get onboardingSegmentWork => '💼  Work & Personal Growth';

  @override
  String get onboardingCategoryStepTitle => 'Great choice! 🎉';

  @override
  String get onboardingCategoryStepBody =>
      'Now pick the subjects/areas you\'ll study — you can change them anytime. Free plan allows up to 8.';

  @override
  String get onboardingCreateOwnCategory => '+ Create my own category';

  @override
  String get onboardingGoalStepTitle => 'One last step! 🚀';

  @override
  String get onboardingGoalStepBody =>
      'How much do you want to focus together each day?';

  @override
  String get onboardingGoal1h => '1 Hour';

  @override
  String get onboardingGoal2h => '2 Hours';

  @override
  String get onboardingGoal3h => '3 Hours';

  @override
  String get onboardingGoal4hPlus => '4 Hours+';

  @override
  String get onboardingFinishBtn => 'Finish';

  @override
  String get categoriesManagementTitle => 'My Categories';

  @override
  String categoryLimitReachedMsg(int limit) {
    return 'You\'ve reached your limit. You can add up to $limit categories.';
  }

  @override
  String get newCategoryDialogTitle => 'New Category';

  @override
  String get editCategoryDialogTitle => 'Edit Category';

  @override
  String get activeCategoryCountLabel => 'Active Category Count';

  @override
  String get archiveCategoryTooltip =>
      'Archive (kept for past reports instead of deleting)';

  @override
  String get archivedCategoriesHeader => 'Archived Categories';

  @override
  String get archivedCategoriesDesc =>
      'These categories won\'t appear in the subject picker but remain in past reports.';

  @override
  String get unarchiveTooltip => 'Unarchive';
}
