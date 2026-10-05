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
      'No friends studying right now. They\'ll show up here once someone starts focusing.';

  @override
  String get socialLoadError =>
      'Couldn\'t load your friends\' status. Check your connection and try again.';

  @override
  String get leagueTierBronze => 'Bronze Hourglass';

  @override
  String get leagueTierSilver => 'Silver Hourglass';

  @override
  String get leagueTierGold => 'Gold Hourglass';

  @override
  String get leagueTierSapphire => 'Sapphire Hourglass';

  @override
  String get leagueTierDiamond => 'Diamond Hourglass';

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
      'Each league period you\'re grouped with up to 30 people at a similar level. Whoever focuses the most during the period climbs to the top.';

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
      'Complete your first pomodoro this period to join a room of up to 30 people at a similar level. Your rank and promotion status will show up here.';

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
  String get errShortPassword => 'Password must be at least 6 characters.';

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
  String get onboardingWelcomeTitle => 'Welcome! 👋';

  @override
  String get onboardingWelcomeBody =>
      'I\'m your focus companion. Before we start, could you pick your birth year? We only ask to check the minimum age.';

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
      'At least 6 characters, with an uppercase letter, a lowercase letter and a number.';

  @override
  String get passwordRuleLength => 'At least 6 characters';

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
      'Email our support team about an inappropriate name or behavior.';

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
}
