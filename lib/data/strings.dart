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

  /// 시안은 인사말을 두 줄로 끊어 놓았다 — 이름이 길어도 리듬이 유지된다.
  static const homeGreetingLine1 = 'Hi {name},';
  static const homeGreetingLine2 = 'what’s happening?';
  /// 시안 06-1 의 플레이스홀더 문구.
  static const homeInputHint = 'Say or type…';
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
  /// 시안 `483:19352`.
  static const saveSheetPlayWithoutAskingHint =
      'Starts as soon as the condition is met';
  static const saveSheetAskBeforePlaying = 'Ask before playing';
  /// 시안 `483:19356`.
  static const saveSheetAskBeforePlayingHint =
      'Shows a confirmation before it plays';
  static const saveSheetOnlyWhenIAsk = 'Only when I ask';
  /// `{name}` 은 기존 모션 이름, `{situation}` 은 상황 문구.
  ///
  /// 시안(`480:3930`)은 "Saving will replace it." 로 끝나지만 실제로는 지우지
  /// 않고 "물어보고 재생" 으로 내린다 (부록 D). 뒷문장만 동작에 맞췄다.
  static const saveSheetReplaceWarning =
      '\u201c{name}\u201d already plays when {situation}. '
      'Saving will ask before playing it instead.';
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
  // 시안 05-1~05-4. 두 줄로 끊어 놓았다.
  static const signatureStep1 = 'If Purebot were\na person\u2026';
  static const signatureStep2 = 'How should it\ncome to you?';
  static const signatureStep3 = 'Which move feels\nlike Purebot?';
  static const signatureStep4 = 'This is its hello.\nHow does it feel?';
  /// 05-3 A/B 비교 — `{side}` 는 A 또는 B.
  static const signaturePlayingSide = 'Playing {side} on Purebot\u2026';
  static const signatureLooksGood = 'Looks good';
  static const signatureABitSofter = 'A bit softer';
  static const signatureStartOver = 'Start over';
  static const signatureSaved = 'Motion signature saved';

  // ---------------------------------------------------------------- 07 라이브러리
  static const libraryTitle = 'Library';
  static const libraryFilterAll = 'All';
  static const libraryFilterAuto = 'Auto';
  static const libraryFilterManual = 'Manual';
  /// 목록에서 수동 모션의 한 줄 (시안 07-1 `481:2792`).
  static const libraryManualLine = 'Manual';
  static const libraryAutoGroup = 'Plays automatically';
  static const librarySearchHint = 'Search motions';
  /// `{date}`.
  static const librarySavedOn = 'Saved {date}';
  /// `{count}`.
  static const libraryEditedTimes = 'Edited {count} times';
  static const libraryEditInChat = 'Edit in chat';
  // 07-2 상세의 반응 카드 (시안 `481:2999`).
  static const libraryTriggerAuto = 'Plays automatically when';
  static const libraryTriggerAsk = 'Asks before playing when';
  static const libraryTriggerHint =
      'To change this, edit the motion in chat and save it again.';
  /// `{count}`. 하나면 [librarySearchResultOne] 을 쓴다 (시안 07-3 "1 result").
  static const librarySearchResults = '{count} results';
  static const librarySearchResultOne = '{count} result';
  static const librarySearchCancel = 'Cancel';

  // ---------------------------------------------------------------- 08 로봇
  static const robotTitle = 'Robot';
  static const robotConnected = 'Connected';
  static const robotMotionSignature = 'Motion signature';
  // 08-2 (시안 `481:3484` 외).
  static const robotSignatureTitle = 'Its motion signature';
  static const robotSignatureBody =
      'Tap a part to change it. Your saved motions keep their own style.';
  static const robotSignaturePersonality = 'Personality';
  static const robotSignatureRelationship = 'Relationship';
  static const robotSignatureMotion = 'Motion';
  static const robotSignatureSound = 'Sound';
  /// 시안 더미 — 소리는 아직 없는 기능이다.
  static const robotSignatureSoundValue = 'One soft cue';
  /// `{lively}` / `{bold}`.
  static const robotSignaturePersonalityValue = 'Lively {lively} / Bold {bold}';
  /// `{motion}` / `{richness}`.
  static const robotSignatureMotionValue = '{motion} / {richness}';
  static const robotActivityHistory = 'Activity history';
  // 08-1 (시안 `488:4707` 외).
  static const robotTriggerNow = 'Trigger now';
  static const robotHelp = 'Help with this robot';
  /// `{name}` / `{time}` / `{how}` — 메뉴에 보이는 마지막 활동 한 줄.
  static const robotLastActivity = 'Last: {name} / {time} ({how})';
  /// `{version}`.
  static const robotVersionReady = 'Version {version} is ready';
  static const robotMyRobots = 'My robots';
  // 08-3 (시안 `481:3613` 외).
  static const robotAddRobot = 'Add a robot';
  /// `{name}`.
  static const robotRemoveFromAccount = 'Remove {name} from account';
  static const robotRemoveTitle = 'Remove {name}?';
  static const robotRemoveBody =
      'It\u2019ll be disconnected from your account. Your motions stay in Library, '
      'and you can add it again anytime.';
  static const robotRemoveAction = 'Remove';
  /// `{model}` / `{status}`.
  static const robotDeviceLine = '{model}  /  {status}';
  static const robotPreviewOnPurebot = 'Preview on Purebot';
  static const robotResetToDefault = 'Reset to default';
  static const robotResetConfirm = 'Reset the motion signature to its default?';
  static const robotUpdateNow = 'Update now';
  // 08-4 (시안 `481:3836` 외).
  static const robotFirmwareTitle = 'Firmware update';
  /// `{version}`.
  static const robotFirmwareVersion = 'Version {version}';
  /// `{current}` / `{size}`.
  static const robotFirmwareMeta = 'Current version {current}  /  {size}';
  static const robotFirmwareSize = '12 MB';
  static const robotFirmwareWhatsNew = 'What\u2019s new';
  /// 시안 `481:3839` 의 세 줄.
  static const List<String> robotFirmwareNotes = [
    'Smoother arm movement at low speed',
    'Sound cues play in sync with motion',
    'Faster reconnect after Wi-Fi drops',
  ];
  static const robotFirmwareHint =
      'Keep Purebot plugged in and close to your phone. It can\u2019t move while '
      'updating (about 3 min).';
  /// `{name}`.
  static const robotFirmwareUpdating = 'Updating {name}\u2026';
  /// `{percent}` / `{left}`.
  static const robotFirmwareProgress = '{percent}%  /  about {left} left';
  static const robotFirmwareDontUnplug =
      'Don\u2019t unplug Purebot or close the app.';
  /// `{name}`.
  static const robotFirmwareUpToDate = '{name} is up to date';
  /// `{version}`.
  static const robotFirmwareChecked = 'Version {version}  /  Checked just now';
  static const robotFirmwareUpToDateNote =
      'Updates install automatically when Wi-Fi is idle.';
  static const robotFirmwareReady = 'Firmware {version} ready';
  static const robotUpdateDone = 'Purebot is up to date';
  static const robotActivityAll = 'All';
  static const robotActivityAuto = 'Auto';
  static const robotActivityByYou = 'By you';
  // 08-5 (시안 `481:4287` 외).
  static const activityYesterday = 'Yesterday';
  static const activityKept = 'Kept for 30 days';
  /// `{situation}` — 자동으로 돈 것.
  static const activityAutoLine = 'Auto / {situation}';
  static const activityAutoPlain = 'Auto';
  static const activityByYouLine = 'By you / from Library';

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
  // 시안 07-1.empty `481:2940` / `481:2941`.
  static const emptyLibraryTitle = 'No motions yet';
  static const emptyLibraryBody =
      'Save a motion from Home and\nit\u2019ll show up here.';
  static const emptyLibraryAction = 'Go to Home';
  // 시안 07-3.no_results `482:5135` / `482:5136`. `{query}` 는 찾던 말.
  static const emptySearchTitle = 'No motions match \u201c{query}\u201d';
  static const emptySearchBody = 'Try another word, or make it on Home.';
  static const emptySearchAction = 'Make it on Home';
  static const emptyNotifications = "You're all caught up";
  static const emptyChatHistory = 'No chats yet';

  // ---------------------------------------------------------------- 오류
  static const errorGenerateFailed = "Couldn't make this motion";
  /// 시안 06-E1 `480:3035` 의 문구.
  static const errorGenerateFailedBody =
      'Try a clearer video, or tell me in words how it should move.';
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
  /// `{name}` — 시안 07-2 `481:3102`.
  static const deleteMotionTitle = 'Delete \u201c{name}\u201d?';
  /// `{situation}` — 시안 07-2 `481:3104`.
  static const deleteMotionBodyAuto =
      'Purebot will stop playing it when {situation}. This can\u2019t be undone.';
  static const deleteMotionBody = 'This can\u2019t be undone.';

  // ---------------------------------------------------------------- 이름 변경
  /// 시안 07-2 `481:3402`.
  static const renameTitle = 'Rename motion';
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
