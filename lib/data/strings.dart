/// UI 문구 — 전부 영어, 키로 관리 (CLAUDE.md 규칙 8).
///
/// 위젯에 문자열을 직접 쓰지 않는다. 화면이 바뀌어도 문구는 여기서만 고친다.
/// `{name}` 같은 자리표시자는 [fill] 로 채운다.
library;

/// `S.homeGreeting` 처럼 쓴다.
abstract final class S {
  // ---------------------------------------------------------------- 공통
  static const appName = 'PURE';
  static const tagline = 'Motion, made uniquely yours.';
  static const actionSave = 'Save';
  static const actionCancel = 'Cancel';
  static const actionDelete = 'Delete';
  static const actionRename = 'Rename';
  static const actionDone = 'Done';
  static const actionRetry = 'Try again';
  static const actionNotNow = 'Not now';
  static const actionOpenSettings = 'Open Settings';
  static const actionPlayOnPurebot = 'Play on Purebot';
  static const actionStop = 'Stop';
  static const actionView = 'View';
  static const actionPlayAgain = 'Play again';
  static const actionSkip = 'Skip';
  static const actionBack = 'Back';

  // ---------------------------------------------------------------- 00 스플래시
  static const splashTagline = tagline;

  // ---------------------------------------------------------------- M 사이드바
  static const menuNewMotion = 'New motion';
  static const menuHome = 'Home';
  static const menuLibrary = 'Library';
  static const menuRobot = 'Robot';
  static const menuActivityHistory = 'Activity history';
  static const menuRecentChats = 'Recent chats';
  static const menuSeeAll = 'See all';
  static const menuMeSettings = 'Me · Settings';

  // ---------------------------------------------------------------- 06 홈
  /// `{name}` 자리에 프로필 이름이 들어간다.
  static const homeGreeting = 'Hi {name}, what’s happening?';
  static const homeInputHint = 'Tell Purebot what happened…';
  static const homeDemoModeOn = 'Demo mode on';
  static const homeDemoModeOff = 'Demo mode off';

  // 06-2 입력
  static const composerRecordVideo = 'Record a video';
  static const composerChooseFromLibrary = 'Choose from library';
  static const composerTrimTitle = 'Pick 30 seconds';
  static const composerTrimUse = 'Use this clip';
  static const composerListening = 'Listening…';
  static const composerAttachmentRemoved = 'Attachment removed';

  // 06-3 생성 중
  static const generatingSlow = 'Still working on it…';

  // 06-4 / 06-6 재생
  /// `{time}` 자리에 0:03 형식.
  static const playingBar = 'Purebot is moving {time}';
  static const playingOnPurebot = 'Playing on Purebot…';
  static const exampleChip = 'Example';

  // 06-7 저장 시트
  static const saveSheetTitle = 'Save this motion';
  static const saveSheetNameLabel = 'Name';
  static const saveSheetHowLabel = 'How should it play?';
  static const saveSheetPlayWithoutAsking = 'Play without asking';
  static const saveSheetAskBeforePlaying = 'Ask before playing';
  static const saveSheetOnlyWhenIAsk = 'Only when I ask';
  /// `{name}` 자리에 기존 모션 이름.
  static const saveSheetReplaceWarning =
      '{name} already plays in this situation. Saving will ask before playing it instead.';
  static const saveSheetReplaceAction = 'Replace and save';

  // 06-8 대화 기록
  static const chatHistoryTitle = 'Recent chats';
  static const chatHistoryToday = 'Today';
  static const chatHistoryEarlier = 'Earlier';
  /// `{count}` 자리에 숫자.
  static const chatHistoryReplies = '{count} replies';
  static const chatHistorySaved = '{count} saved';

  // 06-9 질문형
  /// `{step}` / `{total}`.
  static const questionProgress = 'Step {step}/{total}';
  static const questionSofter = 'Softer';
  static const questionSaveIt = 'Save it';

  // ---------------------------------------------------------------- 05 시그니처
  static const signatureTitle = 'Motion signature';
  static const signatureStep1 = 'What is Purebot like?';
  static const signatureStep2 = 'How does it come to you?';
  static const signatureStep3 = 'How does it move?';
  static const signatureStep4 = 'Does this feel right?';
  static const signatureLooksGood = 'Looks good';
  static const signatureABitSofter = 'A bit softer';
  static const signatureStartOver = 'Start over';
  static const signatureSaved = 'Motion signature saved';

  // ---------------------------------------------------------------- 07 라이브러리
  static const libraryTitle = 'Library';
  static const libraryFilterAll = 'All';
  static const libraryFilterAuto = 'Auto';
  static const libraryFilterManual = 'Manual';
  static const libraryAutoGroup = 'Plays automatically';
  static const librarySearchHint = 'Search motions';
  /// `{date}`.
  static const librarySavedOn = 'Saved {date}';
  /// `{count}`.
  static const libraryEditedTimes = 'Edited {count} times';
  static const libraryEditInChat = 'Edit in chat';
  /// `{count}`.
  static const librarySearchResults = '{count} results';

  // ---------------------------------------------------------------- 08 로봇
  static const robotTitle = 'Robot';
  static const robotConnected = 'Connected';
  static const robotMotionSignature = 'Motion signature';
  static const robotActivityHistory = 'Activity history';
  static const robotMyRobots = 'My robots';
  static const robotPreviewOnPurebot = 'Preview on Purebot';
  static const robotResetToDefault = 'Reset to default';
  static const robotResetConfirm = 'Reset the motion signature to its default?';
  static const robotUpdateNow = 'Update now';
  static const robotFirmwareReady = 'Firmware {version} ready';
  static const robotUpdateDone = 'Purebot is up to date';
  static const robotActivityAll = 'All';
  static const robotActivityAuto = 'Auto';
  static const robotActivityByYou = 'By you';

  // ---------------------------------------------------------------- 09 마이
  static const meTitle = 'Me';
  static const meEdit = 'Edit';
  static const meYourName = 'Your name';
  static const meNotifications = 'Notifications';
  static const meAccount = 'Account';
  static const meHelp = 'Help & FAQ';
  static const meTerms = 'Terms & Privacy';
  /// `{version}`.
  static const meVersion = 'Version {version}';
  static const meLogOut = 'Log out';
  static const meDeleteAccount = 'Delete account';

  // ---------------------------------------------------------------- 10 알림
  static const notificationsTitle = 'Notifications';

  // ---------------------------------------------------------------- 토스트
  static const toastSavedToLibrary = 'Saved to Library';
  static const toastSaved = 'Saved';
  static const toastDeleted = 'Deleted';
  static const toastRenamed = 'Renamed';
  static const toastDemoDataReset = 'Demo data reset';

  // ---------------------------------------------------------------- 빈 화면
  static const emptyLibraryTitle = 'No motions yet';
  static const emptyLibraryBody = 'Tell Purebot what happened and save what you like.';
  static const emptyLibraryAction = 'Go to Home';
  static const emptySearchTitle = 'No matches';
  static const emptySearchBody = 'Try another word, or make a new one.';
  static const emptySearchAction = 'Make it on Home';
  static const emptyNotifications = "You're all caught up";
  static const emptyChatHistory = 'No chats yet';

  // ---------------------------------------------------------------- 오류
  static const errorGenerateFailed = "Couldn't make this motion";
  static const errorGenerateFailedBody = 'Something went wrong. Try again in a moment.';
  static const errorOffline = 'Using demo motions while offline';
  static const errorNameTaken = 'That name is already used';
  static const errorNameEmpty = 'Enter a name';
  static const errorSimFailed = "Couldn't start the simulator";

  // ---------------------------------------------------------------- 권한
  static const permCameraTitle = 'Camera access needed';
  static const permPhotosTitle = 'Photo access needed';
  static const permMicTitle = 'Microphone access needed';
  static const permSpeechTitle = 'Speech recognition needed';
  static const permBody = 'Turn it on in Settings to use this.';

  // ---------------------------------------------------------------- 삭제 확인
  static const deleteMotionTitle = 'Delete this motion?';
  /// `{situation}`.
  static const deleteMotionAutoWarning =
      'It will stop playing automatically when {situation}.';
}

/// `{key}` 자리표시자를 채운다.
///
///     fill(S.homeGreeting, {'name': 'SeungA'})  // "Hi SeungA, what's happening?"
String fill(String template, Map<String, Object?> values) {
  var out = template;
  values.forEach((key, value) {
    out = out.replaceAll('{$key}', '$value');
  });
  return out;
}
