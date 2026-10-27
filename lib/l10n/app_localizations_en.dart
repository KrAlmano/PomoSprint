// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get authEmailHint => 'name@example.com';

  @override
  String get authAppleSignInBtn => 'Sign in with Apple';

  @override
  String get authSocialConsentPrefix => 'By continuing, you agree to our ';

  @override
  String get authSocialConsentSuffix => '.';

  @override
  String authResendAvailableIn(int seconds) {
    return 'You can resend in ${seconds}s';
  }

  @override
  String get onboardingSelectCategoryError =>
      'Pick at least one category to continue.';

  @override
  String get onboardingUnder13Error =>
      'You must be at least 13 years old to use PomoSprint.';

  @override
  String get onboardingSessionExpired =>
      'Your session has expired. Please sign in again.';

  @override
  String get onboardingSaveError =>
      'Couldn\'t save your answers. Please try again.';

  @override
  String onboardingCategoryStepBodyLimit(int limit) {
    return 'Now pick the subjects/areas you\'ll study; you can change them anytime. You can pick up to $limit.';
  }

  @override
  String onboardingCategoryStepPreparedBody(int limit) {
    return 'Your subjects/areas are preselected; change them if you like. Tap one to remove it or add your own. You can pick up to $limit.';
  }

  @override
  String get categoryNameExistsMsg =>
      'A category with this name already exists.';

  @override
  String get categoriesLoadError =>
      'Couldn\'t load your categories. Check your connection and try again.';

  @override
  String get categorySaveError =>
      'Couldn\'t save the change. Please try again.';

  @override
  String get categoriesRetryBtn => 'Retry';

  @override
  String get rankingTabLeague => 'League';

  @override
  String get rankingTabMonthly => 'Monthly';

  @override
  String get rankingTabFriends => 'Friends';

  @override
  String get rankingMonthlyResetIn => 'Monthly leaderboard resets in';

  @override
  String get rankingLoadError =>
      'Couldn\'t load the leaderboard. Check your connection and try again.';

  @override
  String rankingMyStatus(int rank, int points) {
    return 'Your rank: #$rank · $points pts';
  }

  @override
  String rankingPoints(int points) {
    return '$points pts';
  }

  @override
  String rankingCountdownDays(int days, int hours, int minutes) {
    return '${days}d ${hours}h ${minutes}m';
  }

  @override
  String rankingCountdownHours(int hours, int minutes, int seconds) {
    return '${hours}h ${minutes}m ${seconds}s';
  }

  @override
  String get rankingCountdownResetting => 'Resetting...';

  @override
  String get socialRetry => 'Try Again';

  @override
  String get socialRefreshFailed =>
      'Couldn\'t refresh. Showing the last loaded data.';

  @override
  String get socialErrNetwork =>
      'Couldn\'t connect. Check your internet and try again.';

  @override
  String get socialErrSession =>
      'Your session has expired. Please sign in again.';

  @override
  String get socialErrGeneric => 'Something went wrong. Please try again.';

  @override
  String get socialErrInsufficientCoins =>
      'You don\'t have enough sand grains.';

  @override
  String get socialErrAvatarLocked => 'You don\'t own this avatar yet.';

  @override
  String get socialYourFriends => 'Your Friends';

  @override
  String get socialFocusingNow => 'Focusing Right Now';

  @override
  String get socialFocusing => 'Focusing';

  @override
  String socialFocusingOn(String category) {
    return 'Focusing on $category';
  }

  @override
  String get socialNoLiveFriends =>
      'None of your friends are focusing or on a break right now. They’ll appear here when they start studying.';

  @override
  String get socialLoadError =>
      'Couldn\'t load your friends\' status. Check your connection and try again.';

  @override
  String get leagueTierBronze => 'Bronze League';

  @override
  String get leagueTierSilver => 'Silver League';

  @override
  String get leagueTierGold => 'Gold League';

  @override
  String get leagueTierSapphire => 'Sapphire League';

  @override
  String get leagueTierDiamond => 'Diamond League';

  @override
  String leagueTierLeagueName(String tier) {
    return '$tier League';
  }

  @override
  String get leagueInfoTitle => 'How the League System Works';

  @override
  String get leagueInfoWhatTitle => 'What is a League?';

  @override
  String get leagueInfoWhatBody =>
      'After your first session that earns points, you join a league room with people at a similar level. Room capacity and period rules come from the server; earning points moves you up the ranking.';

  @override
  String get leagueInfoTiersTitle => 'League Tiers';

  @override
  String get leagueInfoYouAreHere => 'You are here';

  @override
  String get leagueInfoPointsTitle => 'How Do You Earn Points?';

  @override
  String leagueInfoPoints25(String points) {
    return '25-minute focus: $points pts';
  }

  @override
  String leagueInfoPoints50(String points) {
    return '50-minute focus: $points pts';
  }

  @override
  String get leagueInfoStreakBonus => 'Streak bonus:';

  @override
  String leagueInfoStreakRange(String from, String to, String pct) {
    return '$from-$to days: $pct%';
  }

  @override
  String leagueInfoStreakRangeOpen(String from, String pct) {
    return '$from+ days: $pct%';
  }

  @override
  String get leagueInfoStreakKeep =>
      'Keep your streak alive by completing at least 1 pomodoro every day.';

  @override
  String leagueInfoPausePenalty(String pct) {
    return 'Pausing a session reduces its points by $pct%.';
  }

  @override
  String leagueInfoCoins(String coins, String limit) {
    return '🪙 Sand grains: You earn $coins sand grains from every completed session (up to $limit sessions a day). Spend them to unlock new hourglass characters in your collection.';
  }

  @override
  String get leagueInfoPromotionTitle => 'Promotion & Demotion';

  @override
  String leagueInfoPeriodEnds(String date) {
    return 'This league period ends on $date. When it ends, you move up, stay or move down based on your rank.';
  }

  @override
  String get leagueInfoPeriodGeneric =>
      'When the league period ends, you move up, stay or move down based on your rank.';

  @override
  String get leagueInfoTopTier =>
      'You\'re in the top league, there\'s nowhere higher to go.';

  @override
  String leagueInfoPromote(int count) {
    return 'This period the top $count who earned points move up a league.';
  }

  @override
  String leagueInfoDemote(int count) {
    return 'The bottom $count move down a league.';
  }

  @override
  String get leagueInfoNoDemotionBronze =>
      'There\'s no demotion from the Bronze league.';

  @override
  String get leagueInfoNoDemotionThisPeriod =>
      'No one moves down from this league this period.';

  @override
  String get leagueAwaitingPlacementTitle => 'You\'re not in a league room yet';

  @override
  String get leagueAwaitingPlacementBody =>
      'Complete your first pomodoro that earns points to join a suitable league room at your tier. Your ranking and current period rules appear here.';

  @override
  String get leagueInfoDailyLimitTitle => 'Daily Limit';

  @override
  String leagueInfoDailyLimitBody(String limit) {
    return 'Up to $limit sessions a day earn points and sand (league points, monthly ranking, total points). Sessions after that only add to your study time and streak.';
  }

  @override
  String get leagueInfoFaqTitle => 'Why Didn\'t My Points Go Up?';

  @override
  String leagueInfoFaqLimit(String limit) {
    return 'You may have hit the daily $limit-session limit.';
  }

  @override
  String get leagueInfoFaqCancelled =>
      'The session may have been cancelled too early.';

  @override
  String get leagueInfoFaqReset => 'The league period may have just reset.';

  @override
  String get leagueInfoFaqPending =>
      'Sessions completed offline are sent once you\'re back online; your points are added then.';

  @override
  String get friendsTitle => 'Friends';

  @override
  String get friendsMyCode => 'Your Friend Code';

  @override
  String get friendsCopyCode => 'Copy code';

  @override
  String get friendsCodeCopied => 'Code copied!';

  @override
  String get friendsAddByCode => 'Add Friend by Code';

  @override
  String get friendsCodeHint => 'E.g. A1B2C3';

  @override
  String friendsAdded(String name) {
    return '✅ $name was added to your friends list!';
  }

  @override
  String friendsRequestSent(String name) {
    return '📨 Friend request sent to $name. Waiting for approval.';
  }

  @override
  String get friendsErrNotFound => 'No user found with this code.';

  @override
  String get friendsErrSelf => 'You can\'t add your own code.';

  @override
  String get friendsErrAlreadyFriends =>
      'You\'re already friends with this user.';

  @override
  String get friendsErrAlreadyPending =>
      'There\'s already a pending friend request with this user.';

  @override
  String get friendsErrAddFailed =>
      'Couldn\'t add friend. Check the code and try again.';

  @override
  String friendsIncoming(int count) {
    return 'Incoming Requests ($count)';
  }

  @override
  String get friendsAccept => 'Accept';

  @override
  String get friendsReject => 'Reject';

  @override
  String get friendsAccepted => '✅ Friend request accepted!';

  @override
  String get friendsRespondFailed =>
      'Couldn\'t respond to the request. Please try again.';

  @override
  String get friendsRequestGone => 'This request is no longer valid.';

  @override
  String friendsYourFriends(int count) {
    return 'Your Friends ($count)';
  }

  @override
  String get friendsEmpty =>
      'No friends yet. Share your code or enter one above!';

  @override
  String get friendsLoadError =>
      'Couldn\'t load your friends list. Check your connection and try again.';

  @override
  String get profileNameTooShort => 'Name must be at least 2 characters.';

  @override
  String get profileNameTooLong => 'Name can be at most 30 characters.';

  @override
  String get profileDeleteConfirm =>
      'Are you sure you want to permanently delete your account and all your data?\n\nAll of this is deleted and can\'t be undone: your study history and sessions, points and streak, sand grains and avatars, categories, friends and league record.';

  @override
  String get profileDeleting => 'Deleting your account...';

  @override
  String get profileDeleteError =>
      'Couldn\'t delete your account. Check your connection and try again.';

  @override
  String profileDeleteConfirmPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count sessions on this device that haven\'t been sent yet will also be deleted.',
      one:
          '1 session on this device that hasn\'t been sent yet will also be deleted.',
    );
    return '$_temp0';
  }

  @override
  String get profileDeleteConfirmApple =>
      'Because you signed in with Apple, Apple will verify you once more before deletion so that PomoSprint\'s Sign in with Apple connection is removed too.';

  @override
  String profileDeleteConfirmCopyHint(String email) {
    return 'If you\'d like a copy of your data, email $email from your account\'s email address before deleting.';
  }

  @override
  String get accountDeletedNotice =>
      'Your account and all your data have been deleted.';

  @override
  String get accountDeletedAppleNotice =>
      'To also remove the Sign in with Apple connection, on your iPhone go to Settings > Apple Account (your name) > Sign in with Apple > PomoSprint > Stop Using.';

  @override
  String get sessionExpiredNotice =>
      'Your session has ended. Your password may have changed or your account may have been signed out from another device. Please sign in again.';

  @override
  String get appleCredentialRevokedNotice =>
      'You were signed out because Sign in with Apple was turned off for PomoSprint on this device. Sign in with Apple again to continue.';

  @override
  String get noticeDismissTooltip => 'Dismiss';

  @override
  String get profileNotificationsDenied =>
      'Notification permission wasn\'t granted. You can enable notifications for PomoSprint in your phone\'s Settings.';

  @override
  String get profileSettingSaveError =>
      'Couldn\'t save the setting. Please try again.';

  @override
  String avatarBalance(int coins) {
    return 'Your balance: $coins sand grains';
  }

  @override
  String get avatarPurchaseTitle => 'Buy';

  @override
  String get specialAvatarsTitle => 'Special Avatars';

  @override
  String avatarPurchaseBody(String name, int price) {
    return 'Buy $name for $price sand grains?';
  }

  @override
  String avatarNotEnoughCoins(int missing) {
    return 'Not enough sand grains: you need $missing more.';
  }

  @override
  String avatarPurchased(String name) {
    return '$name is yours!';
  }

  @override
  String get avatarPremiumTitle => 'Premium Avatar';

  @override
  String get avatarPremiumBody =>
      'This avatar is available to Premium members.';

  @override
  String avatarPremiumUnlockBody(String name) {
    return 'With Premium you can unlock $name for free.';
  }

  @override
  String get avatarUnlockBtn => 'Unlock';

  @override
  String get coinsCaption => '🪙 SAND';

  @override
  String pendingSessionsBanner(int count) {
    return 'You have $count unsynced session(s). Tap to retry.';
  }

  @override
  String sessionPointsBreakdown(int base, int bonus, int pct, int total) {
    return '🔥 $base pts + $bonus streak bonus ($pct%) = $total pts!';
  }

  @override
  String sessionDailyLimitReached(int limit) {
    return 'You\'ve reached today\'s points and sand limit ($limit sessions). Further sessions only add to your study time and streak.';
  }

  @override
  String get sessionResultSaving => 'Saving your session…';

  @override
  String sessionResultPoints(int points) {
    return '+$points pts';
  }

  @override
  String sessionResultCoins(int coins) {
    return '+$coins sand';
  }

  @override
  String sessionResultStreak(int days) {
    return '$days-day streak';
  }

  @override
  String get sessionResultDuplicate =>
      'This session was already saved; its points were added earlier.';

  @override
  String get sessionResultTestNotSaved => 'Test session — not saved';

  @override
  String get sessionResultOk => 'OK';

  @override
  String get sessionNotSavedTitle => 'Session not saved';

  @override
  String get sessionQueuedOffline =>
      'Session saved on your device; it will sync automatically once you\'re back online. To earn points and sand, get online within 24 hours.';

  @override
  String get sessionQueuedClockSkew =>
      'Session on hold: your device clock seems different from the server\'s. Check your time settings; the session will be retried automatically.';

  @override
  String get sessionQueuedTimingUnverified =>
      'Session on hold: the session time couldn\'t be verified with the server yet. It will be retried automatically.';

  @override
  String get sessionQueuedOverlap =>
      'This session overlaps an earlier record; it\'s on hold and will be retried later.';

  @override
  String get sessionRejectedTooOld =>
      'This session couldn\'t be saved because it\'s older than 24 hours.';

  @override
  String get sessionRejectedClock =>
      'This session couldn\'t be saved: your device clock seems to be ahead. Check your time settings.';

  @override
  String get sessionRejectedNotElapsed =>
      'This session couldn\'t be saved: according to the server, the session time hadn\'t run out yet.';

  @override
  String get sessionRejectedFutureStart =>
      'This session couldn\'t be saved: its start time couldn\'t be verified against the server clock.';

  @override
  String get sessionRejectedOverlap =>
      'This session couldn\'t be saved: another session is already recorded for the same time.';

  @override
  String get sessionRejectedGeneric =>
      'This session couldn\'t be saved: it failed server validation.';

  @override
  String rejectedSessionsNotice(int count) {
    return '⚠️ $count pending session(s) were rejected by the server and couldn\'t be saved.';
  }

  @override
  String get rejectedSessionsTitle => 'Unsaved sessions';

  @override
  String get rejectedSessionsInfo =>
      'Sessions the server didn\'t accept are listed here; they don\'t count toward points, sand or your streak. The last 50 are kept on this device.';

  @override
  String get rejectedSessionsEmpty => 'No unsaved sessions.';

  @override
  String rejectedSessionsLink(int count) {
    return 'Unsaved sessions ($count)';
  }

  @override
  String get rejectedSessionsView => 'View';

  @override
  String get pausedSessionExpired =>
      'Your paused session went past 24 hours, so it couldn\'t be saved and was reset.';

  @override
  String get leaveWhileRunningTitle => 'Session in progress';

  @override
  String get leaveWhileRunningBody =>
      'The timer keeps running even if you leave. When you come back, your session continues where it left off.';

  @override
  String get leaveWhileRunningStay => 'Stay';

  @override
  String get leaveWhileRunningLeave => 'Leave';

  @override
  String get notifSessionDoneTitle => 'Pomodoro complete! 🎉';

  @override
  String notifSessionDoneBody(String category) {
    return 'Your $category session is done. Open the app within 24 hours to earn your points and sand.';
  }

  @override
  String get notifChannelName => 'Session notifications';

  @override
  String get notifChannelDescription =>
      'Lets you know when your Pomodoro session ends.';

  @override
  String get lockTimerChannelName => 'Running session';

  @override
  String get lockTimerChannelDescription =>
      'Shows the time left on your lock screen and in the notification shade while a session runs.';

  @override
  String lockTimerRunningBody(String time) {
    return 'Focusing · ends at $time';
  }

  @override
  String lockTimerPausedBody(String remaining) {
    return 'Paused · $remaining left';
  }

  @override
  String get lockTimerStatusRunning => 'Focusing';

  @override
  String get lockTimerStatusPaused => 'Paused';

  @override
  String get lockTimerStatusDone => 'Session complete';

  @override
  String get lockTimerDoneHint =>
      'Open PomoSprint within 24 hours to save your session.';

  @override
  String get statsLoadErrorTitle => 'Couldn\'t load your stats';

  @override
  String get statsLoadErrorOffline =>
      'Couldn\'t reach the server. Check your internet connection and try again.';

  @override
  String get statsLoadErrorSignedOut =>
      'Please sign in again to see your stats.';

  @override
  String get statsLoadErrorGeneric =>
      'Something went wrong while loading your data. Please try again.';

  @override
  String get statsRetry => 'Try Again';

  @override
  String get statsStaleNotice =>
      'Couldn\'t refresh; showing the last loaded data.';

  @override
  String statsPendingSessions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sessions waiting to sync',
      one: '1 session waiting to sync',
    );
    return '$_temp0';
  }

  @override
  String get statsNoStudyTodayTitle => 'You haven\'t studied yet today';

  @override
  String get statsNoStudyTodayDesc =>
      'Start a Pomodoro and today\'s subject breakdown will appear here.';

  @override
  String get statsNoStudyThisWeekTitle => 'No study this week yet';

  @override
  String get statsNoStudyThisWeekDesc =>
      'Start a Pomodoro and your weekly analysis will build up here.';

  @override
  String get statsGoalSheetSubtitle =>
      'How long do you want to focus each day?';

  @override
  String statsGoalPomodoroApprox(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '≈ $count Pomodoros',
      one: '≈ 1 Pomodoro',
    );
    return '$_temp0';
  }

  @override
  String get statsGoalSaveFailed =>
      'Couldn\'t save your goal. Check your connection and try again.';

  @override
  String statsTodayPomodoros(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Pomodoros completed today',
      one: '1 Pomodoro completed today',
    );
    return '$_temp0';
  }

  @override
  String get statsWeeklyGoalTitle => 'Weekly Goal';

  @override
  String statsWeeklyGoalSubtitle(String weekly) {
    return '$weekly · your daily goal × 7';
  }

  @override
  String statsWeekLabel(int index) {
    return 'Week $index';
  }

  @override
  String statsWeekStudyTotal(String duration) {
    return '$duration Study';
  }

  @override
  String statsWeekChangeUp(String percent) {
    return '$percent more than the same days last week';
  }

  @override
  String statsWeekChangeDown(String percent) {
    return '$percent less than the same days last week';
  }

  @override
  String statsMonthMotivation(String percent) {
    return 'You\'ve increased your focus by $percent compared to the same period last month. Great job!';
  }

  @override
  String get statsMonthEmptyTitle => 'No study recorded this month yet';

  @override
  String get statsMonthEmptyDesc =>
      'Your monthly tracking will appear here once you complete your first Pomodoro this month.';

  @override
  String get statsOtherCategory => 'Other';

  @override
  String get statsShowAsDuration => 'Show as duration';

  @override
  String get statsShowAsPercent => 'Show as percentage';

  @override
  String get statsOfflinePendingOnly =>
      'Couldn\'t reach the server; showing only the sessions waiting to sync on this device.';

  @override
  String get statsOtherCategories => 'Other categories';

  @override
  String statsMoreCategories(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count more categories',
      one: '+1 more category',
    );
    return '$_temp0';
  }

  @override
  String get statsGoalReached => 'You reached today\'s goal, well done!';

  @override
  String get statsTipFocusBlock =>
      'Before you start a session, pick one specific task to finish in it.';

  @override
  String get statsWeekNotStarted => 'Not started yet';

  @override
  String get statsWeekChangeSame =>
      'Same as the same days of the previous week';

  @override
  String statsGoalPomodorosNeeded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Pomodoros to reach it',
      one: '1 Pomodoro to reach it',
    );
    return '$_temp0';
  }

  @override
  String get authErrWeakPassword =>
      'Your password is too weak. It must contain at least 1 lowercase letter (a-z), 1 uppercase letter (A-Z) and 1 digit (0-9).';

  @override
  String get authErrEmailExistsResent =>
      'This email is already registered! A verification link has been resent to your inbox.';

  @override
  String get authErrInvalidCredentials =>
      'Invalid email or password, or your account may not be confirmed yet. Check your password; if the problem continues, you can resend the confirmation email below.';

  @override
  String get authErrEmailNotConfirmed =>
      'Your email address has not been confirmed yet. Please click the confirmation link in your inbox.';

  @override
  String get authErrRateLimited =>
      'Too many attempts. Please wait a few minutes and try again.';

  @override
  String get authErrNetwork =>
      'Could not reach the internet or the server. Please check your connection.';

  @override
  String get authErrInvalidEmail => 'Please enter a valid email address.';

  @override
  String get authErrCloudUnavailable =>
      'Could not connect to the server. Please check your internet connection.';

  @override
  String get authErrProfileLoad =>
      'Your profile could not be loaded. Please check your connection and sign in again.';

  @override
  String get authErrGoogleFailed => 'Google sign-in failed. Please try again.';

  @override
  String get authErrAppleFailed => 'Apple sign-in failed. Please try again.';

  @override
  String get authErrUnknown => 'Something went wrong. Please try again.';

  @override
  String get authErrSignUpTimeout =>
      'The sign-up request timed out. Your account may still have been created: check your email or try signing in.';

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
      'Earned by finishing a league period in the top 3 with points: 1st gets the Champion Award, 2nd and 3rd get the Podium Award.';

  @override
  String get leagueAwardLockedTitle => 'This Avatar Is Locked';

  @override
  String get leagueAwardLockedBody =>
      'To earn this avatar, finish a league period in this tier in the top 3 with points. It can\'t be purchased.';

  @override
  String get leagueAwardLockedBodyChampion =>
      'To earn this Champion Award, finish a league period in this tier in 1st place with points. It can\'t be purchased.';

  @override
  String get leagueAwardLockedBodyPodium =>
      'To earn this Podium Award, finish a league period in this tier in 2nd or 3rd place with points (1st place gets the Champion Award). It can\'t be purchased.';

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
  String get appleOnAndroidLink => 'Signed up with Apple?';

  @override
  String get appleOnAndroidTitle =>
      'Signing in on Android to an account created with Apple';

  @override
  String get appleOnAndroidBody =>
      'Sign in with Apple isn\'t available on Android, but you can sign in with email and password:\n\n1. Find your account\'s email address. If you chose \"Hide My Email\" with Apple, it\'s a private relay address (…@privaterelay.appleid.com); on your iPhone it\'s shown under Settings > Apple Account (your name) > Sign in with Apple > PomoSprint.\n2. Enter that address on this screen, tap \"Forgot Password?\" and set a password using the link we send.\n3. Then sign in with that address and your new password.\n\nIf the email doesn\'t arrive, write to destek@pomosprint.app.';

  @override
  String get resendVerificationLink => 'Resend Verification Email 📬';

  @override
  String loginVerificationPendingInfo(String email) {
    return 'We sent a confirmation link to $email. After tapping it, sign in here with your password.';
  }

  @override
  String get loginResendPrompt => 'Didn\'t get the email? Resend';

  @override
  String get errEnterEmailForResend =>
      'Enter your email address first to resend the confirmation email.';

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
  String get errShortPassword => 'Password must be at least 8 characters.';

  @override
  String get errAcceptTerms =>
      'Please accept the Terms of Service to continue.';

  @override
  String get errEmailExists =>
      'This email address is already registered. Please sign in. If you signed up with Google or Apple using this address, use that button, or set a password with \"Forgot Password?\".';

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
  String get logoutConfirmTitle => 'Log out?';

  @override
  String get logoutConfirmBody =>
      'You\'ll be signed out on this device. You can sign back in with the same account anytime.';

  @override
  String logoutPendingWarning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sessions haven\'t been sent to the server yet.',
      one: '1 session hasn\'t been sent to the server yet.',
    );
    return '$_temp0 If you don\'t sign in with the same account on this device within 24 hours of the session\'s start, its points, sand grains and streak credit will be lost.';
  }

  @override
  String get logoutRunningWarning =>
      'You have a session in progress. It stays saved on this device and continues when you sign back in with the same account, but you won\'t get the end notification after logging out.';

  @override
  String get logoutSendAndExit => 'Send and log out';

  @override
  String get logoutAnyway => 'Log out anyway';

  @override
  String get logoutSendFailed =>
      'Couldn\'t send your sessions right now. Check your connection and try again.';

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
  String get onboardingWelcomeTitle => 'Welcome to PomoSprint';

  @override
  String get onboardingWelcomeBody =>
      'Focus, track your study and progress with people sharing your goal. Let’s set up the app for you.';

  @override
  String get onboardingSegmentTitle => 'So, which journey are you on?';

  @override
  String get onboardingSegmentBody =>
      'What will we study together? Let me suggest some categories. If none fits, pick \"Other\".';

  @override
  String get onboardingSegmentLgs =>
      '🎓  LGS (Turkish high school entrance exam)';

  @override
  String get onboardingSegmentYks =>
      '📚  YKS (Turkish university entrance exam)';

  @override
  String get onboardingSegmentKpss => '📝  KPSS (Turkish civil service exam)';

  @override
  String get onboardingSegmentLanguage =>
      '🌍  Language exam (YDS, YÖKDİL, IELTS, TOEFL)';

  @override
  String get onboardingSegmentUniversity => '🏛️  University';

  @override
  String get onboardingSegmentWork => '💼  Work & Personal Growth';

  @override
  String get onboardingCategoryStepTitle => 'Great choice! 🎉';

  @override
  String get onboardingCategoryStepPreparedTitle => 'Picked for your goal 🎯';

  @override
  String get onboardingCreateOwnCategory => '+ Create my own category';

  @override
  String get onboardingGoalStepTitle => 'Choose your daily goal';

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

  @override
  String get categoryLastActiveRequired =>
      'You need at least one active category. Add a new category or unarchive one first.';

  @override
  String get timerResetBtn => 'Reset';

  @override
  String get timerResetConfirmTitle => 'Reset this session?';

  @override
  String get timerResetConfirmBody =>
      'This session will be discarded without being saved, and you won\'t earn points or sand. This can\'t be undone.';

  @override
  String get timerResetConfirmAction => 'Reset';

  @override
  String get timerDurationLocked =>
      'Reset the session first to change its length.';

  @override
  String get timerQuickTestBadge => 'TEST';

  @override
  String get timerQuickTestSemantics =>
      'Quick test timer: sessions aren\'t saved';

  @override
  String get rankingZonePromotionChip => '↑ Promotion';

  @override
  String get rankingZoneDemotionChip => '↓ Demotion';

  @override
  String get rankingZonePromotionMe =>
      'You\'re in the promotion zone: if the period ends like this, you move up a league.';

  @override
  String get rankingZoneNeedsPointsMe =>
      'You\'re in the promotion zone, but you can\'t move up with 0 points. Complete a session.';

  @override
  String get rankingZoneDemotionMe =>
      'You\'re in the demotion zone: if the period ends like this, you move down a league.';

  @override
  String get authSocialNoticePrefix => 'By continuing, you accept our ';

  @override
  String get authSocialNoticeTermsLink => 'Terms of Service';

  @override
  String get authSocialNoticeMiddle => ' and confirm that you have read the ';

  @override
  String get authSocialNoticeKvkkLink => 'Privacy Notice (KVKK)';

  @override
  String get authSocialNoticeSuffix => '.';

  @override
  String legalOpenFailed(String url) {
    return 'Couldn\'t open the page. You can visit it in your browser: $url';
  }

  @override
  String get registerNameLabel => 'Display name';

  @override
  String get registerNameHelper =>
      'Shown to others in rankings and friend lists.';

  @override
  String get registerErrNameRequired => 'Enter a display name.';

  @override
  String get registerErrNameTooLong => 'Name can be at most 50 characters.';

  @override
  String get nameNotAllowed =>
      'This name isn\'t allowed. Please choose a different one.';

  @override
  String get registerErrEmailRequired => 'Enter your email address.';

  @override
  String get registerErrPasswordRequired => 'Choose a password.';

  @override
  String get registerPasswordHelper =>
      'At least 8 characters, with an uppercase letter, a lowercase letter and a number.';

  @override
  String get passwordRuleLength => 'At least 8 characters';

  @override
  String get passwordRuleCase => 'Upper and lower case (A-Z, a-z)';

  @override
  String get passwordRuleDigit => 'At least one number (0-9)';

  @override
  String get changePasswordTile => 'Change password';

  @override
  String get changePasswordTileSub =>
      'Confirm with your current password and set a new one.';

  @override
  String get changePasswordCurrent => 'Current password';

  @override
  String get changePasswordNew => 'New password';

  @override
  String get changePasswordRepeat => 'New password (again)';

  @override
  String get changePasswordMismatch => 'The new passwords don\'t match.';

  @override
  String get changePasswordSame =>
      'Your new password must be different from your current one.';

  @override
  String get changePasswordWrongCurrent =>
      'Your current password is incorrect.';

  @override
  String get changePasswordSave => 'Update password';

  @override
  String get changePasswordSuccess =>
      'Your password was updated. You may have been signed out on your other devices.';

  @override
  String get registerShowPassword => 'Show password';

  @override
  String get registerHidePassword => 'Hide password';

  @override
  String get registerConsentsTitle => 'Agreements';

  @override
  String get registerConsentRequiredTag => 'Required';

  @override
  String get registerConsentOptionalTag => 'Optional';

  @override
  String get registerConsentTermsPrefix => 'I have read and accept the ';

  @override
  String get registerConsentTermsLink => 'Terms of Service';

  @override
  String get registerConsentTermsSuffix => '.';

  @override
  String get registerConsentPrivacyPrefix => 'I have read the ';

  @override
  String get registerConsentKvkkLink => 'Privacy Notice (KVKK)';

  @override
  String get registerConsentPrivacyConnector => ' and the ';

  @override
  String get registerConsentPrivacyLink => 'Privacy Policy';

  @override
  String get registerConsentPrivacySuffix => '.';

  @override
  String get registerConsentMarketing =>
      'Send me emails about new features and updates (consent to commercial electronic messages).';

  @override
  String get registerConsentMarketingHint =>
      'You can unsubscribe at any time using the link in the emails.';

  @override
  String get errAcknowledgePrivacy =>
      'Please confirm that you have read the Privacy Notice (KVKK) and the Privacy Policy.';

  @override
  String get profileLegalSectionTitle => 'Privacy & legal';

  @override
  String get kvkkNoticeLink => 'Privacy Notice (KVKK)';

  @override
  String get deleteAccountSub =>
      'Permanently deletes your account and all of your data.';

  @override
  String get hiddenUsersTitle => 'Show hidden users';

  @override
  String hiddenUsersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count users hidden · tap to reset the list',
      one: '1 user hidden · tap to reset the list',
      zero: 'No hidden users',
    );
    return '$_temp0';
  }

  @override
  String get hiddenUsersCleared => 'Hidden users will be visible again.';

  @override
  String get userActionsTooltip => 'User options';

  @override
  String get reportUserAction => 'Report user';

  @override
  String get reportUserActionSub =>
      'Report an inappropriate name, content or behavior in the app.';

  @override
  String get hideUserAction => 'Hide this user';

  @override
  String get hideUserActionSub =>
      'Their name is hidden in rankings and they won\'t appear in the live feed. You can undo this in Profile.';

  @override
  String userHiddenMsg(String name) {
    return '$name is now hidden.';
  }

  @override
  String get undoAction => 'Undo';

  @override
  String get hiddenUserLabel => 'Hidden user';

  @override
  String reportEmailSubject(String name) {
    return 'PomoSprint user report: $name';
  }

  @override
  String reportEmailBody(String name, String userId, String place) {
    return 'Reported display name: $name\nUser ID: $userId\nSeen in: $place\n\nWhat are you reporting? Please describe briefly:\n';
  }

  @override
  String get reportUserIdUnknown => 'unknown (rankings don\'t show user IDs)';

  @override
  String get reportPlaceLeague => 'Rankings · League';

  @override
  String get reportPlaceMonthly => 'Rankings · Monthly';

  @override
  String get reportPlaceFriendsRanking => 'Rankings · Friends';

  @override
  String get reportPlaceLiveFeed => 'Social · Focusing now';

  @override
  String get reportPlaceFriendsList => 'Friends list';

  @override
  String get reportPlaceFriendRequest => 'Friend request';

  @override
  String reportMailFailed(String email) {
    return 'Couldn\'t open an email app. You can send your report to $email.';
  }

  @override
  String get reportCopyAddress => 'Copy address';

  @override
  String get onboardingBirthYearRequired => 'Pick your birth year to continue.';

  @override
  String get onboardingBirthYearPlaceholder => 'Select your birth year';

  @override
  String get profileNotificationsLabelSub =>
      'Session end alert and lock screen timer';

  @override
  String get profileNotificationsBlockedSub =>
      'Notification permission is off. Allow it in your phone\'s settings for the session end alert and the lock screen timer.';

  @override
  String get profileOpenSettings => 'Open settings';

  @override
  String get profileSocialVisibilityTitle =>
      'Appear in rankings and the live list';

  @override
  String get profileSocialVisibilitySub =>
      'When on, your name and avatar appear in the monthly ranking, in the public list on pomosprint.app (shortened name) and in your friends\' live list while you study. Your league group and friends always see you.';

  @override
  String get gameRulesTitle => 'How it works';

  @override
  String get gameRulesProfileSub => 'Pausing, daily limit, points and sand';

  @override
  String gameRulesSessions(String pct) {
    return 'Sessions last 25 or 50 minutes. You get one pause per session; pausing lowers your points by $pct%. Stopping a second time resets the session.';
  }

  @override
  String gameRulesPoints(
    String points25,
    String points50,
    String coins,
    String limit,
  ) {
    return 'Every completed session earns points (25 min: $points25, 50 min: $points50) and $coins sand grains. Up to $limit sessions a day count; after that they only add to your study time and streak.';
  }

  @override
  String get gameRulesLeague =>
      'Your points move you up in your league and studying every day earns a streak bonus. Spend sand grains on new hourglasses in your collection.';

  @override
  String get profileHelpSectionTitle => 'Help';

  @override
  String get profileSupportTitle => 'Support & feedback';

  @override
  String get profileSupportSub => 'Email us about a problem or an idea';

  @override
  String profileAppVersion(String version) {
    return 'Version $version';
  }

  @override
  String get supportEmailSubject => 'PomoSprint support & feedback';

  @override
  String supportEmailBody(String version, String device) {
    return 'Your message:\n\n\n---\nApp version: $version\nDevice: $device';
  }

  @override
  String supportMailFailed(String email) {
    return 'Couldn\'t open an email app. You can write to us at $email.';
  }

  @override
  String get selectCategory => 'SELECT CATEGORY';

  @override
  String get sessionCompletedTitle => 'Congratulations! 🎉';

  @override
  String sessionCompletedBody(int minutes) {
    return 'You successfully completed a $minutes-minute\nfocus session! ⏳';
  }

  @override
  String get sessionCompletedOk => 'Awesome!';

  @override
  String get timerGetReady => 'Get ready! Focusing...';

  @override
  String get languagePickerLabel => 'App language';

  @override
  String get onboardingSegmentOther => '✨  Other / prefer not to say';

  @override
  String get onboardingVisibilityTitle => 'Do you want to appear in rankings?';

  @override
  String get onboardingVisibilityBody =>
      'If you turn this on, your name and avatar appear in the monthly ranking, in the public list on pomosprint.app (with your name shortened) and in your friends\' live list while you study. When it\'s off, you don\'t appear in those places. People in your league group and your friends always see you. You can change this anytime in Profile.';

  @override
  String get onboardingVisibilityYes => 'Yes, show me in rankings';

  @override
  String get onboardingVisibilityNo => 'No, keep me out of them';

  @override
  String get onboardingRulesBody => 'A few rules to know before you start:';

  @override
  String timerDurationOption(int minutes) {
    return '$minutes-minute session';
  }

  @override
  String get timerEditCategories => 'Edit categories';

  @override
  String timerRemainingSemantics(int minutes, int seconds) {
    return '$minutes min $seconds s remaining';
  }

  @override
  String get timerNotificationsDenied =>
      'No notification permission: we can\'t alert you when the session ends and the lock screen timer won\'t show.';

  @override
  String onboardingCategoriesSkippedLimit(int count, int limit) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected categories weren\'t added',
      one: '1 selected category wasn\'t added',
    );
    return '$_temp0 because you reached the category limit ($limit). You can manage them in My Categories.';
  }

  @override
  String get categoryColorInvalidMsg =>
      'This color can\'t be used. Pick a color from the list.';

  @override
  String get categoryIconInvalidMsg =>
      'This category icon can\'t be used. Please try again.';

  @override
  String leagueInfoPromoteMinPoints(int count, int points) {
    return 'This period the top $count who earned at least $points points move up a league.';
  }

  @override
  String get leagueAloneInRoomTitle => 'You\'re alone in your room for now';

  @override
  String get leagueAloneInRoomBody =>
      'Right now you\'re the only one in this league room. People who join will show up here; complete pomodoros to earn points.';

  @override
  String get friendsErrInvalidCode =>
      'A friend code has 6–8 letters and digits. Check the code.';

  @override
  String get friendsErrRateLimited =>
      'Too many attempts. Please try again later.';

  @override
  String get friendsErrCooldown =>
      'This user recently declined your request. You can try again later.';

  @override
  String get friendsErrBlocked =>
      'You can\'t add this user because you blocked them.';

  @override
  String leagueAwardsSubMinPoints(int points) {
    return 'Earned by finishing a league period in the top 3 with at least $points points: 1st gets the Champion Award, 2nd and 3rd get the Podium Award.';
  }

  @override
  String leagueAwardMinMembersNote(int members) {
    return 'Awards are only given in rooms with at least $members members at the end of the period.';
  }

  @override
  String leagueAwardLockedBodyMinPoints(int points) {
    return 'To earn this avatar, finish a league period in this tier in the top 3 with at least $points points. It can\'t be purchased.';
  }

  @override
  String leagueAwardLockedBodyChampionMinPoints(int points) {
    return 'To earn this Champion Award, finish a league period in this tier in 1st place with at least $points points. It can\'t be purchased.';
  }

  @override
  String leagueAwardLockedBodyPodiumMinPoints(int points) {
    return 'To earn this Podium Award, finish a league period in this tier in 2nd or 3rd place with at least $points points (1st place gets the Champion Award). It can\'t be purchased.';
  }

  @override
  String rankingZoneNeedsMinPointsMe(int points) {
    return 'You\'re in the promotion zone, but you need at least $points points to move up. Keep completing sessions.';
  }

  @override
  String get forgotPasswordDescription =>
      'Enter your email address. We will send a verification link to reset your password.';

  @override
  String get sendPasswordResetEmail => 'Send verification email';

  @override
  String get passwordResetSentTitle => 'Check your email';

  @override
  String get passwordResetSentDescription =>
      'If an account is registered with this address, we sent a password reset link. Check your inbox and spam folder, then follow the link to set a new password.';

  @override
  String get passwordResetLocalTitle => 'Local email';

  @override
  String get passwordResetLocalDescription =>
      'This build uses the local environment. Emails are kept in the local Mailpit inbox and are not sent to your real inbox. Accounts and passwords here are separate from your normal account. Use the normal PomoSprint launch option to reset your normal account.';

  @override
  String get timerQuickRecordedSemantics =>
      'Local quick test timer: sessions are saved as 25 or 50 minutes';

  @override
  String get friendsOutgoingTitle => 'Sent requests';

  @override
  String get friendsCancelRequest => 'Cancel request';

  @override
  String get friendsRemoveAction => 'Remove friend';

  @override
  String get friendsRemoveConfirm =>
      'Remove this friend? You will need to send a new request to become friends again.';

  @override
  String get friendsCancelConfirm => 'Cancel this friend request?';

  @override
  String get blockedUsersTitle => 'Blocked users';

  @override
  String get blockUserAction => 'Block user';

  @override
  String get blockUserConfirm =>
      'Your friendship and requests will be removed. You cannot see each other in the live feed or send friend requests.';

  @override
  String get unblockUserAction => 'Unblock user';

  @override
  String get unblockUserConfirm =>
      'The block will be removed. Your previous friendship will not be restored automatically.';

  @override
  String get friendActionCompleted => 'Done.';

  @override
  String get friendActionFailed =>
      'Could not complete the action. Refresh the list and try again.';

  @override
  String get friendActionConfirm => 'Confirm';

  @override
  String get friendActionCancel => 'Cancel';

  @override
  String get reportReasonLabel => 'Reason for reporting';

  @override
  String get reportChooseReason => 'Choose a reason for reporting.';

  @override
  String get reportReasonOffensiveName => 'Inappropriate name';

  @override
  String get reportReasonOffensiveContent => 'Inappropriate content';

  @override
  String get reportReasonHarassment => 'Harassment or bullying';

  @override
  String get reportReasonSpam => 'Spam';

  @override
  String get reportReasonImpersonation => 'Impersonation';

  @override
  String get reportReasonOther => 'Other';

  @override
  String get reportDetailsLabel => 'Details (optional)';

  @override
  String get reportSendButton => 'Send report';

  @override
  String get reportSent =>
      'Your report was received. Our support team will review it.';

  @override
  String get reportAlreadyReceived =>
      'We already received your report about this user.';

  @override
  String get reportRateLimited =>
      'You reached the daily report limit. Please try again later.';

  @override
  String get reportUserUnavailable =>
      'This user is no longer available to report. Refresh the list.';

  @override
  String get reportSendFailed => 'Could not send the report. Please try again.';

  @override
  String get marathonTitle => 'Marathon';

  @override
  String get marathonSingle => 'Single session';

  @override
  String get marathonChooseCount => 'How many sessions would you like?';

  @override
  String marathonCountOption(int count) {
    return '$count Pomodoros';
  }

  @override
  String marathonProgress(int current, int total) {
    return 'Pomodoro $current/$total';
  }

  @override
  String get marathonBreakTitle => 'Break';

  @override
  String get marathonBreakHint =>
      'When your break ends, tap “I’m here” within 1 minute to continue.';

  @override
  String get marathonAutomaticHint =>
      'A marathon is a study plan with 2, 3 or 4 Pomodoros in a row. Choose 25 or 50 minutes for the plan; all Pomodoros in the marathon use that same duration.\n\nTake a 5-minute break between sessions. When it ends, tap “I’m here” within 1 minute to start the next session. An internet connection is required to confirm.\n\nIf you miss a confirmation or choose to end the marathon early, the remaining plan stops. Completed sessions and their regular points are kept, but no completion bonus is awarded. Breaks and confirmation waiting time do not count as study time.';

  @override
  String marathonBreakRemainingSemantics(int minutes, int seconds) {
    return 'Break: $minutes minutes and $seconds seconds remaining';
  }

  @override
  String get marathonStart => 'START MARATHON';

  @override
  String get marathonStop => 'End marathon';

  @override
  String get marathonStopped =>
      'Marathon ended. Your completed Pomodoros and regular points were kept.';

  @override
  String get marathonStopConfirmTitle => 'End this marathon?';

  @override
  String marathonStopConfirmBody(int completed, int total) {
    return 'You completed $completed/$total Pomodoros. Completed sessions are kept; the current Pomodoro will not be saved.';
  }

  @override
  String get marathonStopConfirmAction => 'End marathon';

  @override
  String get marathonCompletedTitle => 'Marathon complete!';

  @override
  String marathonCompletedBody(int count, int minutes) {
    return 'You focused for $minutes minutes across $count Pomodoros.';
  }

  @override
  String get marathonSaving => 'Saving Pomodoro…';

  @override
  String get marathonRetrySave => 'Retry saving';

  @override
  String get marathonSaveFailed =>
      'Your completed Pomodoro is stored on this device. Retry to send the saved session. If the continuation window expires, the marathon stops; your completed session is kept.';

  @override
  String get marathonStoppedRejected =>
      'This Pomodoro could not be saved. The marathon stopped; your earlier sessions were kept.';

  @override
  String marathonMinutesSummary(int focusMinutes, int elapsedMinutes) {
    return '$focusMinutes min focus · about $elapsedMinutes min with breaks';
  }

  @override
  String get marathonResumePlan => 'Resume marathon';

  @override
  String get notifMarathonBreakDoneTitle => 'Break is over';

  @override
  String notifMarathonBreakDoneBody(int nextSession, int totalSessions) {
    return 'Marathon: Pomodoro $nextSession/$totalSessions. Open the app and tap “I’m here” within 1 minute to continue.';
  }

  @override
  String get socialOnBreak => 'On break';

  @override
  String get socialNoBreakFriends =>
      'None of your friends are on a break right now.';

  @override
  String marathonBonusPoints(int points) {
    return '+$points marathon bonus';
  }

  @override
  String marathonBonusHint(int points) {
    return 'Complete the marathon for $points extra points';
  }

  @override
  String get marathonBonusPending =>
      'Your marathon bonus will be calculated when pending Pomodoros are saved and the completion requirements are met.';

  @override
  String get marathonUnavailable => 'Marathon is currently unavailable.';

  @override
  String get marathonStartFailed =>
      'The marathon could not start. Please try again.';

  @override
  String get marathonPresenceTitle => 'Are you here?';

  @override
  String get marathonPresenceHint =>
      'Your break is over. Tap “I’m here” within 1 minute to start the next session.';

  @override
  String get marathonPresenceConfirm => 'I’m here';

  @override
  String get marathonPresenceChecking => 'Confirming…';

  @override
  String get marathonPresenceConnectionNeeded =>
      'Confirmation failed. Check your internet connection and try again before time runs out.';

  @override
  String get marathonPresenceExpired =>
      'The marathon stopped because you did not confirm. Your completed sessions were kept.';

  @override
  String marathonPresenceRemainingSemantics(int minutes, int seconds) {
    return '$minutes minutes and $seconds seconds left to confirm';
  }

  @override
  String get marathonStepStart => 'Start';

  @override
  String get marathonStepGoal => 'Goal';

  @override
  String marathonSessionCount(int count) {
    return '$count sessions';
  }

  @override
  String get marathonStepCompleted => 'Completed';

  @override
  String get marathonStepCurrent => 'Current session';

  @override
  String get marathonStepUpcoming => 'Next session';

  @override
  String get marathonStoppedInvalid =>
      'Your Pomodoro was saved. The marathon stopped because its verification could not be completed; your sessions were kept.';

  @override
  String get marathonPlanTitle => 'Plan your marathon';

  @override
  String get marathonDurationLabel => 'Pomodoro duration';

  @override
  String get marathonStartingWelcome =>
      'Your marathon is starting. Happy focusing!';

  @override
  String get marathonViewProgress => 'Marathon progress';

  @override
  String get marathonInfoTitle => 'What is a marathon?';

  @override
  String marathonInfoBonusMatrix(
    int shortTwo,
    int shortThree,
    int shortFour,
    int longTwo,
    int longThree,
    int longFour,
  ) {
    return 'Completion bonus\n25 min: 2 sessions +$shortTwo, 3 sessions +$shortThree, 4 sessions +$shortFour points.\n50 min: 2 sessions +$longTwo, 3 sessions +$longThree, 4 sessions +$longFour points.\n\nThese extra points are awarded once, after every session has been saved and earned regular points, and every continuation is confirmed on time. They are added to the regular session points and do not earn extra sand.';
  }

  @override
  String get onboardingGuideTitle => 'Get to know the app';

  @override
  String get onboardingGuideBody =>
      'See how each screen works before you begin.';

  @override
  String get onboardingGuidePomoTitle => 'Pomo';

  @override
  String get onboardingGuidePomoBody =>
      'Choose a category and a 25- or 50-minute session, then tap Start. You can pause once per session; pausing reduces its points. Completed sessions are saved.';

  @override
  String get onboardingGuideMarathonTitle => 'Marathon';

  @override
  String get onboardingGuideMarathonBody =>
      'Use Start Marathon to plan 2, 3 or 4 sessions. Each break lasts 5 minutes. Tap I’m here within 1 minute after the break to continue; without confirmation, the marathon ends. Completed sessions keep their normal points. Finishing the whole plan adds +2/+3/+5 points for 25-minute sessions or +4/+6/+10 for 50-minute sessions, respectively.';

  @override
  String get onboardingGuideReportsTitle => 'Reports';

  @override
  String get onboardingGuideReportsBody =>
      'Daily, weekly and monthly reports combine Pomodoro sessions, Marathon focus sessions and completed exams. Breaks and abandoned exams are excluded. The study day changes at 04:00; exam time appears in its own Exam row.';

  @override
  String get onboardingGuideRankingTitle => 'Ranking';

  @override
  String get onboardingGuideRankingBody =>
      'Study and exam leagues are separate and group people by their goal. Global rankings cover all goals. Periods renew at 00:00 Istanbul time on the first day of each month. Small groups may remain in preparation; the ? guide in Rankings explains promotion and reward conditions.';

  @override
  String get onboardingGuideSocialTitle => 'Social';

  @override
  String get onboardingGuideSocialBody =>
      'Add friends by code and manage requests. Visible friends appear as Focusing, On break only during Marathon breaks, or Taking an exam. The open list refreshes periodically. Change visibility in Settings, hide users or block them.';

  @override
  String get onboardingGuideProfileTitle => 'Profile';

  @override
  String get onboardingGuideProfileBody =>
      'Tap your avatar at the top to open Profile. Manage categories, use earned sand to expand your avatar collection, and choose an avatar. You can also find language, theme, notification and visibility settings, help, privacy and account actions here.';

  @override
  String leagueInfoWhatBodyWithCapacity(int capacity) {
    return 'After your first completed session that earns points, you join a suitable existing room in the same tier and period. A room holds up to $capacity people; a new room opens when it is full. Period rankings use points from sessions accepted by the server.';
  }

  @override
  String leagueLaunchPreparingBody(int users) {
    return 'Leagues are preparing. Once $users different users have completed a session in the last 14 days, the first official competition starts in the next full 14-day period. Sessions, points and reports are saved; preparation has no promotion, demotion or league avatar awards. Preparation points do not carry into the official competition.';
  }

  @override
  String leagueLaunchScheduledBody(String date) {
    return 'The first official league period starts on $date. Until then, sessions and reports are saved without promotion, demotion or league avatar awards. Preparation points do not carry into the competition.';
  }

  @override
  String get leagueLaunchScheduledShort => 'Official league period starts';

  @override
  String leaguePromotionPolicyBody(
    int active,
    int days,
    int minutes,
    int points,
  ) {
    return 'Promotion requires at least $active active people who completed a session in your room this period. The promotion quota is one third of the active count, rounded down (3 active people: 1; 25 active people: 8). Complete at least $minutes focus minutes across $days different study days, earn at least $points points and finish within the quota this period. Diamond League has no promotion.';
  }

  @override
  String leaguePromotionCurrentQuota(int count) {
    return 'Current promotion quota in this room: the first $count places. The study day, minute and point requirements also apply.';
  }

  @override
  String get leagueNoPromotionCurrentPeriod =>
      'This room currently has too few active participants for promotion. Completed sessions continue to be saved.';

  @override
  String get leagueDemotionPolicyBody =>
      'Demotion applies only in rooms with at least 10 active people: the bottom one third of the active count, rounded down, move down one tier. People who joined in the last 3 days and those in Bronze League are protected.';

  @override
  String leagueAwardActiveRequirements(
    int members,
    int days,
    int minutes,
    int points,
  ) {
    return 'An official league period needs at least $members active people in the room. Complete $minutes focus minutes across at least $days different study days and earn $points points. Preparation has no awards.';
  }

  @override
  String get leaguePreparationNoChanges =>
      'Everyone stays in their current league during preparation; no promotion, demotion or league avatar awards are given.';

  @override
  String get leagueLaunchPreparingShort =>
      'Preparation · Promotion, demotion and league awards have not started yet.';

  @override
  String get examTab => 'Practice';

  @override
  String get examTitle => 'Practice exams';

  @override
  String get examNew => 'New practice exam';

  @override
  String get examHistory => 'My practice exams';

  @override
  String get examLeague => 'Practice league';

  @override
  String get examIntro =>
      'Choose an exam and use its full time. You can add your scores afterwards.';

  @override
  String get examUnavailable => 'Practice mode is coming soon';

  @override
  String get examUnavailableBody =>
      'Practice mode is not enabled on this server yet. You can browse exams while regular study and Marathon remain available.';

  @override
  String get examCatalogFallback =>
      'Showing offline exam information. A server connection is required to start.';

  @override
  String get examStart => 'Start practice exam';

  @override
  String get examRulesTitle => 'Before you start';

  @override
  String get examRulesBody =>
      'Practice exams have no breaks or pauses. The timer continues while the app is closed. Abandoning before the full time earns no points or practice sand; the attempt stays in your history. Scores do not affect points or leagues.';

  @override
  String get examReady => 'Start when you are ready';

  @override
  String get examNoPause => 'No pauses or breaks';

  @override
  String get examRunning => 'Practice exam in progress';

  @override
  String get examTimeRemaining => 'Time remaining';

  @override
  String get examAbandon => 'Abandon practice exam';

  @override
  String get examAbandonTitle => 'Abandon this practice exam?';

  @override
  String get examAbandonBody =>
      'This attempt will be saved as abandoned. It will not earn points, practice sand or study time.';

  @override
  String get examCompleted => 'Practice exam completed';

  @override
  String get examAbandoned => 'Abandoned';

  @override
  String get examPending => 'Waiting for server confirmation';

  @override
  String get examPendingBody =>
      'Your attempt is saved on this device. The same record will be retried when the connection returns.';

  @override
  String get examStartPending => 'Waiting for start confirmation';

  @override
  String get examStartPendingBody =>
      'The start request has not been confirmed yet. Retrying will not create another attempt.';

  @override
  String get examError =>
      'Could not load practice exam data. Check your connection and try again.';

  @override
  String get examConflict =>
      'Finish your current study session or practice exam first.';

  @override
  String get examRetry => 'Try again';

  @override
  String get examEnterResults => 'Enter your scores';

  @override
  String get examEditResults => 'Edit your scores';

  @override
  String get examResultsTitle => 'Results by subject';

  @override
  String get examResultsInfo =>
      'Scores are for personal reports and insights; they do not affect points or sand.';

  @override
  String get examCorrect => 'Correct';

  @override
  String get examWrong => 'Wrong';

  @override
  String get examBlank => 'Unanswered';

  @override
  String get examNet => 'Net score';

  @override
  String get examSaveResults => 'Save results';

  @override
  String get examResultsInvalid =>
      'For each subject, correct, wrong and unanswered must add up to the question count. Enter non-negative whole numbers only.';

  @override
  String get examResultsSaved => 'Your scores were saved.';

  @override
  String get examResultsSaveError =>
      'Results could not be saved. Your entries were kept; you can try again.';

  @override
  String get examNoHistory => 'No practice exams yet';

  @override
  String get examNoHistoryBody =>
      'Started and abandoned practice exams appear here.';

  @override
  String get examPracticeSand => 'Practice sand';

  @override
  String get examInsights => 'Study time and scores';

  @override
  String get examInsightsEmpty =>
      'At least two results for the same subject are needed for a comparison. Your study time and scores will appear together here.';

  @override
  String get examInsightsDisclaimer =>
      'This comparison shows an association; it does not imply that study time alone caused a score change.';

  @override
  String get examLeagueEmpty =>
      'You join the league after your first completed practice exam.';

  @override
  String get examLeaguePreparing =>
      'Waiting for enough active users to start competition in this group.';

  @override
  String get examGlobal => 'Global';

  @override
  String get examTargetGroup => 'My target group';

  @override
  String get examRewardAvatars => 'Practice league avatars';

  @override
  String get examRewardAvatarsPending =>
      'Special artwork is being prepared. Unearned rewards are not shown as owned while artwork is pending.';

  @override
  String get examFinishedNoResults => 'Scores have not been entered yet';

  @override
  String get examStartTime => 'Started';

  @override
  String get examEndTime => 'Finished';

  @override
  String get examDismiss => 'Done';

  @override
  String get examLgsBreakInfo =>
      'LGS has two separate sessions. The actual exam includes a 45-minute break between the verbal and quantitative sessions.';

  @override
  String get examLoadMore => 'Show more';

  @override
  String get examNoAward => 'No reward';

  @override
  String get examNetUnavailable => '—';

  @override
  String get examQueuedResults =>
      'Your results are saved on this device and will be sent when the connection returns.';

  @override
  String get examTotalStudy => 'Total study';

  @override
  String get examNoVerifiedDuration =>
      'Study time is added only for completed practice exams confirmed by the server.';

  @override
  String get examStarting => 'Starting…';

  @override
  String get examSaving => 'Saving…';

  @override
  String get examAllGroups => 'All exams';

  @override
  String examQuestionsMinutes(int questions, int minutes) {
    return 'Questions: $questions · Time: $minutes min';
  }

  @override
  String examSubjectQuestions(int questions) {
    return '$questions questions';
  }

  @override
  String examNetRule(int divisor) {
    return 'Net = Correct − Wrong / $divisor';
  }

  @override
  String examRewardSummary(int points, int sand) {
    return '$points points · $sand practice sand';
  }

  @override
  String examInsightsChange(
    String subject,
    int minutes,
    String before,
    String after,
  ) {
    return '$subject: $minutes min of study. Your net score: $before → $after.';
  }

  @override
  String examResultsQuestionTotal(int actual, int expected) {
    return 'Total $actual / $expected';
  }

  @override
  String examMonthlyReset(String date) {
    return 'Period ends: $date';
  }

  @override
  String get onboardingSegmentTus => 'TUS (Medical Specialty Exam)';

  @override
  String get onboardingLanguageTitle => 'Which language would you like to use?';

  @override
  String get onboardingLanguageBody =>
      'You can change your language later in Settings.';

  @override
  String get onboardingGuideExamTitle =>
      'Practice exams: experience exam timing';

  @override
  String get onboardingGuideExamBody =>
      'Choose an exam to load its duration and question count. Practice exams have no breaks or pauses. Finishing the full time earns separate exam points and sand. Abandoned attempts stay in history without rewards or study-time credit.';

  @override
  String get onboardingGuideInsightsTitle => 'Nets and study–net insights';

  @override
  String get onboardingGuideInsightsBody =>
      'In My exams, enter and edit correct, wrong and blank answers per subject. Nets are personal reports and never change your points or league. When enough data is available, see study time alongside changes in your nets.';

  @override
  String get languageNativeTr => 'Türkçe';

  @override
  String get languageNativeEn => 'English';

  @override
  String get languageSettingsTitle => 'App Language';

  @override
  String get categoriesSectionTitle => 'MY CATEGORIES';

  @override
  String get editProfileAction => 'Edit Profile';

  @override
  String get effHigh => 'High';

  @override
  String get effNormal => 'Normal';

  @override
  String get effVeryHigh => 'Very High';

  @override
  String get legacyEmailReadonlyHint =>
      'Email address cannot be changed for security.';

  @override
  String get heatmapLess => 'Less';

  @override
  String get heatmapMore => 'More';

  @override
  String get manageCategoriesTileSub =>
      'Add, edit, reorder & archive categories';

  @override
  String get manageCategoriesTileTitle => 'Manage Categories';

  @override
  String get monthIntensitySuffix => 'Intensity';

  @override
  String get mostEfficientDayLabel => 'Most Efficient Day';

  @override
  String get profileFullNameLabel => 'Full Name';

  @override
  String get newWeekLabel => 'New';

  @override
  String get noReportsDesc =>
      'When you start the timer and complete your first Pomodoro session, your breakdown and reports will appear here.';

  @override
  String get noStudyThisDay => 'No study this day';

  @override
  String get notificationsAndLockScreen => 'Notifications & lock screen timer';

  @override
  String get preferencesSectionTitle => 'Preferences';

  @override
  String get reportsWeeklyTab => 'Weekly Focus';

  @override
  String get reportsMonthlyTab => 'Monthly Tracking';

  @override
  String get reportsDailyTab => 'Daily Focus';

  @override
  String get topSubjectsLabel => 'Most Studied Subjects';

  @override
  String get topicComparisonTitle => 'Topic Comparison';

  @override
  String get totalFocusLabel => 'Total\nFocus';

  @override
  String get weekDayBreakdownTitle => 'Day-by-Day Breakdown';

  @override
  String get weeklyAnalysisCaption => 'WEEKLY ANALYSIS';

  @override
  String get legacyWeeklyDistSub => 'Summary of today';

  @override
  String get legacyWeeklyDistTitle => 'Today\'s Distribution';

  @override
  String get weeklyEfficiencyCaption => 'WEEKLY EFFICIENCY';

  @override
  String get weeklySummaryTitle => 'Weekly Summary';

  @override
  String get weeklyTrendCaption => 'WEEKLY TREND';

  @override
  String get statsSessionTypesTitle => 'Session types';

  @override
  String get statsNormalSessions => 'Regular sessions';

  @override
  String get statsCompletedMarathons => 'Completed marathons';

  @override
  String get statsCompletedExams => 'Completed practice exams';

  @override
  String get statsExamCategory => 'Practice exams';

  @override
  String get statsOpenExamDetails => 'My practice exams, scores and insights';

  @override
  String get statsUnknownSessionTypes =>
      'The older server does not yet distinguish regular sessions from Marathon for these records. Time totals are preserved.';

  @override
  String get statsExamTotalsInfo =>
      'Total time includes Pomodoro, Marathon focus sessions and completed practice exams. Practice exam time is not distributed across subjects.';

  @override
  String statsMarathonFocusCount(int count) {
    return '$count Marathon focus sessions';
  }

  @override
  String statsFocusEquivalent(int count) {
    return '$count × 25-minute focus equivalents';
  }

  @override
  String statsCountsPending(int count) {
    return '$count sessions awaiting server confirmation';
  }

  @override
  String get socialTakingExam => 'Taking an exam';

  @override
  String get rankingTabGlobal => 'Global';

  @override
  String get rankingGlobalResetIn => 'Global leaderboard resets in';

  @override
  String get leagueCalendarMonthBody =>
      'Focus and practice exam leagues have separate points. Both reset at 00:00 Istanbul time on the first day of each month. Daily study and streak tracking still use the 04:00 boundary.';

  @override
  String leagueCalendarPreparingBody(String date) {
    return 'Monthly competition is being prepared. Official start: $date (Istanbul). Promotion and award requirements apply when the room has enough active participants. Completed sessions and earned lifetime points are preserved.';
  }

  @override
  String get leagueCalendarPreparingGeneric =>
      'Monthly competition is being prepared. There is no promotion, relegation or league award without enough active participants; your sessions are still saved.';

  @override
  String get leagueTargetTitle => 'Your league target';

  @override
  String leagueTargetCurrent(String target) {
    return 'This month: $target';
  }

  @override
  String leagueTargetPending(String target, String date) {
    return 'Next target: $target · $date (Istanbul)';
  }

  @override
  String get leagueTargetChange => 'Change target';

  @override
  String get leagueTargetDialogTitle => 'Choose your league target';

  @override
  String get leagueTargetPolicy =>
      'Your focus and practice exam leagues match you with users sharing your target. Before your first session, the target changes immediately. A change during the month takes effect at 00:00 Istanbul time on the first day of the next month; your current points and room are preserved. The global view does not change your target or grant extra rewards.';

  @override
  String get leagueTargetSave => 'Save target';

  @override
  String get leagueTargetSaveError =>
      'Could not save the target. Check your connection and try again.';

  @override
  String get leagueTargetOther => 'Other';

  @override
  String get leagueGlobalScopeBody =>
      'This month’s focus points across all targets. Practice exam points have a separate league; the global view gives no additional reward.';
}
