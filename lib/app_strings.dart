// app_strings.dart
// 다국어 문자열 클래스.
// PlatformDispatcher.instance.locale 로 시스템 언어를 감지하므로 BuildContext 불필요.
// 현재 지원: 한국어(ko) / 영어(기본값)
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';

class AppStrings {
  AppStrings._();

  static bool? _isKoOverride;
  static const String _prefKey = 'dev_lang_override';

  /// SharedPreferences 저장값을 읽어 언어 오버라이드를 초기화합니다.
  /// main()에서 runApp() 전에 await 해야 합니다.
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    if (saved == 'ko') {
      _isKoOverride = true;
    } else if (saved == 'en') {
      _isKoOverride = false;
    } else {
      _isKoOverride = null;
    }
  }

  /// 한국어↔영어를 토글하고 SharedPreferences에 저장합니다.
  static Future<void> toggleLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final newIsKo = !isKo;
    _isKoOverride = newIsKo;
    await prefs.setString(_prefKey, newIsKo ? 'ko' : 'en');
  }

  /// 시스템 언어가 한국어인지 여부 (개발자 오버라이드 우선)
  static bool get isKo =>
      _isKoOverride ?? (PlatformDispatcher.instance.locale.languageCode == 'ko');

  /// 로케일에 따른 표준 성장 데이터 asset 경로
  static String get standardGrowthAsset => isKo
      ? 'assets/standard_growth_2017.json'
      : 'assets/standard_growth_who.json';

  // ── PageMain ──────────────────────────────────────────
  static String get appTitle =>
      isKo ? '우리아이 성장 그래프' : 'Child Growth Tracker';
  static String get noChildRegistered =>
      isKo ? '등록된 자녀가 없습니다.' : 'No children registered.';
  static String get noChildDesc =>
      isKo
          ? '아래 "프로필" 버튼으로 자녀 정보를 먼저 등록하세요.'
          : 'Please register your child\'s profile using the "Profile" button below.';
  static String get noChildHint =>
      isKo
          ? '자녀를 선택하면 "성장 데이터 입력 / 보기 및 수정 / 그래프 보기" 메뉴가 열립니다.'
          : 'Tap a child to access "Add Data / View & Edit / View Chart".';
  static String get menuProfile => isKo ? '프로필' : 'Profile';
  static String get menuStandardChart => isKo ? '표준도표' : 'Std Chart';
  static String get menuHelp => isKo ? '사용설명' : 'Help';
  static String get backupExport => isKo ? '백업 내보내기' : 'Export Backup';
  static String get backupImport => isKo ? '백업 가져오기' : 'Import Backup';
  static String get importFailed => isKo ? '가져오기 실패: ' : 'Import failed: ';
  static String get profileDeleted =>
      isKo ? '프로필이 삭제되었습니다.' : 'Profile deleted.';
  static String get confirmDeleteProfile =>
      isKo ? '프로필 삭제' : 'Delete Profile';
  static String get confirmDeleteProfileMsg =>
      isKo
          ? '정말 이 프로필을 삭제하시겠습니까?'
          : 'Are you sure you want to delete this profile?';
  static String get cancel => isKo ? '취소' : 'Cancel';
  static String get delete => isKo ? '삭제' : 'Delete';
  static String get actionAddData => isKo ? '성장 데이터 입력' : 'Add Growth Data';
  static String get actionViewEdit => isKo ? '데이터 보기 및 수정' : 'View & Edit Data';
  static String get actionViewChart => isKo ? '그래프 보기' : 'View Chart';
  static String get actionDeleteProfile => isKo ? '프로필 삭제' : 'Delete Profile';
  static String get updateReady =>
      isKo ? '새 버전이 준비되었습니다.' : 'A new version is ready.';
  static String get updateNow => isKo ? '지금 업데이트' : 'Update Now';
  /// 아이 카드의 성별·생년월일 표시 (gender 값은 항상 '남아'/'여아' 로 저장됨)
  static String childCardGenderBirth(String gender, String birth) {
    final gLabel = gender == '남아' ? genderBoy : genderGirl;
    return isKo
        ? '성별: $gLabel  ·  생년월일: $birth'
        : 'Gender: $gLabel  ·  Birth: $birth';
  }

  // ── PageProfileInput ──────────────────────────────────
  static String get profileInputTitle => isKo ? '아이 정보 입력' : 'Enter Child Info';
  static String get labelName => isKo ? '성명' : 'Name';
  static String get labelBirthDate => isKo ? '생년월일: ' : 'Birth Date: ';
  static String get selectBirthDate => isKo ? '생년월일 선택' : 'Select Birth Date';
  static String get labelGender => isKo ? '성별' : 'Gender';
  static String get genderBoy => isKo ? '남아' : 'Boy';
  static String get genderGirl => isKo ? '여아' : 'Girl';
  static String get confirm => isKo ? '확인' : 'OK';
  static String get alertTitle => isKo ? '알림' : 'Notice';
  static String get nameRequired =>
      isKo ? '이름을 입력해주세요.' : 'Please enter a name.';
  static String get nameDuplicate =>
      isKo
          ? '이미 동일한 이름의 프로필이 존재합니다.'
          : 'A profile with this name already exists.';
  static String get saveError => isKo ? '저장 중 오류 발생: ' : 'Save error: ';

  // ── ChildGrowthInput ──────────────────────────────────
  static String growthInputTitle(String name) =>
      isKo ? '$name - 성장 데이터 입력' : '$name - Add Growth Data';
  static String measureDate(String date) =>
      isKo ? '측정일: $date' : 'Date: $date';
  static String ageMonths(int months) =>
      isKo ? '월령: ${months}개월' : 'Age: $months months';
  static String get selectDate => isKo ? '날짜 선택' : 'Select Date';
  static String get labelHeight => isKo ? '키 (cm)' : 'Height (cm)';
  static String get labelWeight => isKo ? '몸무게 (kg)' : 'Weight (kg)';
  static String get labelBmi => isKo ? '체질량지수 (BMI)' : 'BMI';
  static String get autoCalc => isKo ? '자동 계산' : 'Auto Calc';
  static String get bmiNeedsHW =>
      isKo
          ? 'BMI는 키와 몸무게를 모두 입력해야 계산됩니다'
          : 'BMI requires both height and weight.';
  static String get heightOrWeightRequired =>
      isKo
          ? '키 또는 몸무게 중 하나는 입력해주세요'
          : 'Please enter at least height or weight.';
  static String get saveGrowthData => isKo ? '성장 데이터 저장' : 'Save Growth Data';
  static String get saved => isKo ? '저장되었습니다' : 'Saved.';
  static String get saveErrorMsg =>
      isKo ? '저장 중 오류가 발생했습니다.' : 'An error occurred while saving.';
  static String get backupNudgeTitle =>
      isKo ? '성장 기록을 안전하게 보관하세요' : 'Keep your growth records safe';
  static String get backupNudgeBody =>
      isKo
          ? '아이의 소중한 기록이 차곡차곡 쌓이고 있어요!\n로컬이나 카카오톡에 백업해두면, 앱 삭제나 기기 변경 시에도 편리하게 복구할 수 있습니다.'
          : 'Your child\'s precious records are building up!\nBack up to local storage or a messaging app — easy to restore even after uninstalling or changing devices.';
  static String get backupNudgeHint =>
      isKo
          ? '메인 화면 우측 상단의 [↑] 버튼으로 백업하세요.'
          : 'Tap the [↑] button at the top right of the main screen to back up.';

  // ── ChildGrowthList ───────────────────────────────────
  static String growthListTitle(String name) =>
      isKo ? '$name 성장 기록' : '$name Growth Records';
  static String get noData => isKo ? '저장된 데이터가 없습니다.' : 'No data saved.';
  static String get refresh => isKo ? '새로고침' : 'Refresh';
  static String get loadError =>
      isKo
          ? '성장 데이터 로딩 중 오류가 발생했습니다.'
          : 'Error loading growth data.';
  static String get editRecord => isKo ? '기록 수정' : 'Edit Record';
  static String get labelAgeMo => isKo ? '나이 (개월)' : 'Age (months)';
  static String get bmiAutoHint =>
      isKo
          ? '※ 키+몸무게가 있으면 BMI는 자동 계산 가능합니다.'
          : '※ BMI is auto-calculated when height and weight are both entered.';
  static String get save => isKo ? '저장' : 'Save';
  static String get heightOrWeightRequiredEdit =>
      isKo
          ? '키 또는 몸무게 중 하나는 입력되어야 합니다.'
          : 'At least height or weight is required.';
  static String get confirmDeleteRecord => isKo ? '삭제 확인' : 'Confirm Delete';
  static String get confirmDeleteRecordMsg =>
      isKo ? '이 기록을 삭제하시겠습니까?' : 'Delete this record?';
  static String get recordDeleted =>
      isKo ? '기록이 삭제되었습니다.' : 'Record deleted.';
  static String get saveErrorList =>
      isKo ? '저장 중 오류가 발생했습니다.' : 'Save error.';
  static String entryDateAge(String date, int months) =>
      isKo ? '$date · ${months}개월' : '$date · ${months}mo';
  static String entryHeightWeightBmi(String h, String w, String bmi) =>
      isKo
          ? '키 $h cm / 몸무게 $w kg / BMI $bmi'
          : 'Ht $h cm / Wt $w kg / BMI $bmi';
  static String get deleteTooltip => isKo ? '삭제' : 'Delete';
  static String get dateLabel => isKo ? '날짜: ' : 'Date: ';
  static String get labelBmiEdit => isKo ? 'BMI (자동/수동)' : 'BMI (auto/manual)';

  // ── ChildGrowthChart ──────────────────────────────────
  static String chartTitle(String name, String sexLabel) =>
      isKo ? '$name($sexLabel) 성장 그래프' : '$name ($sexLabel) Growth Chart';
  static String chartTitleShort(String name, String sexLabel) =>
      isKo ? '$name($sexLabel)' : '$name ($sexLabel)';
  static String get sexBoy => isKo ? '남아' : 'Boy';
  static String get sexGirl => isKo ? '여아' : 'Girl';
  static String get chartNoData =>
      isKo
          ? '데이터가 없습니다.\n먼저 "성장 데이터 입력"을 해주세요.'
          : 'No data available.\nPlease add growth data first.';
  static String get chartHint =>
      isKo
          ? '표준선(백분위) 위에 아이 데이터가 겹쳐집니다.\n그래프를 터치하면 단일 그래프로 전환됩니다.'
          : 'Child data is overlaid on standard percentile lines.\nTap a chart to switch to single view.';
  static String get stdLine => isKo ? '표준선' : 'Std Line';
  static String get childData => isKo ? '아이 데이터' : 'Child Data';
  static String get zoomIn => isKo ? '확대' : 'Zoom In';
  static String get zoomOut => isKo ? '축소' : 'Zoom Out';
  static String get reset => isKo ? '리셋' : 'Reset';
  static String get moveZoomHint =>
      isKo
          ? '드래그로 이동 / 핀치 또는 버튼으로 확대·축소'
          : 'Drag to pan / Pinch or buttons to zoom';
  static String get viewAll => isKo ? '전체보기' : 'All';
  static String get monthUnit => isKo ? '개월' : 'mo';
  static String centerBadge(String x, String y, String unit) =>
      isKo
          ? '중심  X=${x}개월   Y=$y${unit.isEmpty ? '' : ' $unit'}'
          : 'Center  X=${x}mo   Y=$y${unit.isEmpty ? '' : ' $unit'}';
  static String get chartHeight => isKo ? '키' : 'Height';
  static String get chartWeight => isKo ? '몸무게' : 'Weight';
  static String get chartBmi => isKo ? '체질량(BMI)' : 'BMI';
  static String get unitCm => 'cm';
  static String get unitKg => 'kg';
  static String get selectLabel => isKo ? '선택' : 'Select';
  static String get moveZoom => isKo ? '이동/확대' : 'Pan/Zoom';
  static String chartTooltip(int months, String y, String unit) =>
      isKo
          ? '${months}개월\n$y${unit.isEmpty ? '' : ' $unit'}'
          : '${months}mo\n$y${unit.isEmpty ? '' : ' $unit'}';

  // ── PageStandardGrowthChart ───────────────────────────
  static String get stdChartTitle =>
      isKo ? '표준성장도표 (2017)' : 'Standard Growth Chart (WHO)';
  static String get stdChartBoy => isKo ? '남아' : 'Boy';
  static String get stdChartGirl => isKo ? '여아' : 'Girl';
  static String get stdChartHeight => isKo ? '신장' : 'Height';
  static String get stdChartWeight => isKo ? '체중' : 'Weight';
  static String get stdChartBmi => 'BMI';
  static String get stdChartUnitCm => 'cm';
  static String get stdChartUnitKg => 'kg';
  static String get stdChartUnitBmi => 'kg/m²';
  static String get stdChartXLabel =>
      isKo ? '연령(년)  ※ X축은 개월 기반' : 'Age (years)  ※ X-axis in months';
  static String get stdChartSource =>
      isKo
          ? '출처: 2017 소아청소년 성장도표(대한소아청소년과학회·질병관리본부)'
          : 'Source: WHO Child Growth Standards (2006/2007)';
  static String stdChartSexMetric(String sex, String metric, String unit) =>
      '$sex · $metric ($unit)';
  static String stdChartTooltip(
          int months, String years, String metricLabel, String val, String unit) =>
      isKo
          ? '개월: $months (≈ ${years}년)\n$metricLabel: $val $unit'
          : 'Months: $months (≈ $years yr)\n$metricLabel: $val $unit';
  static String get stdChartLoadError =>
      isKo
          ? '표준 성장 데이터 로드 실패\npubspec.yaml assets 등록/경로를 확인하세요.\n오류: '
          : 'Failed to load standard growth data.\nCheck pubspec.yaml assets path.\nError: ';
  static String get stdChartReload => isKo ? '다시 로드' : 'Reload';

  // ── BackupManager ─────────────────────────────────────
  static String get backupSubject =>
      isKo ? '우리아이 성장 그래프 백업 (' : 'Child Growth Tracker Backup (';
  static String get backupShareText =>
      isKo
          ? '백업 파일입니다. Drive/다운로드 등에 저장해 두세요.'
          : 'Backup file. Please save to Drive or Downloads.';
  static String get backupRestored =>
      isKo ? '복원이 완료되었습니다.' : 'Restore complete.';
  static String get backupInvalidJson =>
      isKo
          ? '백업 파일이 올바른 JSON 형식이 아닙니다. 파일이 손상되었을 수 있습니다.'
          : 'Invalid JSON format. The file may be corrupted.';
  static String get backupInvalidFormat =>
      isKo
          ? '백업 파일 형식이 올바르지 않습니다(최상위가 JSON 객체가 아님).'
          : 'Invalid backup format (root is not a JSON object).';
  static String backupUnsupportedSchema(dynamic schema) =>
      isKo ? '지원하지 않는 백업 스키마입니다: $schema' : 'Unsupported backup schema: $schema';
  static String get backupNoProfiles =>
      isKo ? '백업 파일에 childProfiles가 없습니다.' : 'No childProfiles found in backup.';
  static String get backupNoGrowthData =>
      isKo
          ? '백업 파일에 growthByChildName이 없습니다.'
          : 'No growthByChildName found in backup.';

  // ── PageAppExplanation ────────────────────────────────
  static String get explanationTitle => isKo ? '사용 설명' : 'Help';
  static String versionTitle(String version) =>
      isKo ? '사용 설명  $version' : 'Help  $version';
  static String get expSec1Title => isKo ? '1. 앱 소개' : '1. About This App';
  static String get expSec1Body1 =>
      isKo
          ? '우리아이 성장 그래프는 아이의 키, 몸무게, BMI(체질량지수)를 국가 표준 성장곡선과 함께 비교하여 한눈에 확인할 수 있도록 만든 앱입니다.'
          : 'Child Growth Tracker lets you record your child\'s height, weight, and BMI, and compare them with standard growth curves at a glance.';
  static String get expSec1Body2 =>
      isKo
          ? '단순 기록이 아니라, 아이의 성장 흐름을 시간에 따라 시각적으로 확인하는 것이 목적입니다.'
          : 'The goal is not just recording data, but visually tracking your child\'s growth trend over time.';
  static String get expSec2Title => isKo ? '2. 기본 사용 방법' : '2. How to Use';
  static String get expSec2Body1 =>
      isKo
          ? '① 프로필 등록\n하단의 "프로필" 버튼을 눌러 아이의 이름, 성별, 생년월일을 등록합니다.'
          : '① Register Profile\nTap the "Profile" button at the bottom to register your child\'s name, gender, and birth date.';
  static String get expSec2Body2 =>
      isKo
          ? '② 성장 데이터 입력\n아이를 선택한 뒤 "성장 데이터 입력"을 누르면 해당 날짜의 키와 몸무게를 입력할 수 있습니다.\n\n키 또는 몸무게 중 하나만 입력해도 저장이 가능합니다.\nBMI는 키와 몸무게가 모두 있을 때 자동 계산됩니다.'
          : '② Add Growth Data\nSelect a child and tap "Add Growth Data" to enter height and weight for that date.\n\nYou can save with only height or weight.\nBMI is automatically calculated when both are entered.';
  static String get expSec2Body3 =>
      isKo
          ? '③ 그래프 보기\n"그래프 보기"를 누르면 표준 성장곡선과 아이의 데이터를 함께 확인할 수 있습니다.\n그래프를 터치하면 확대/이동이 가능하며, 중심 좌표도 확인할 수 있습니다.'
          : '③ View Chart\nTap "View Chart" to see standard growth curves alongside your child\'s data.\nTap the chart to enable zoom and pan, and check the center coordinates.';
  static String get expSec3Title =>
      isKo ? '3. 데이터 저장 방식 (중요 안내)' : '3. Data Storage (Important)';
  static String get expSec3Body1 =>
      isKo
          ? '이 앱은 기본적으로 사용자의 데이터를 외부 서버로 전송하지 않습니다.\n입력한 모든 성장 데이터는 사용자의 휴대폰 내부에 안전하게 저장됩니다.'
          : 'This app does not send your data to external servers.\nAll growth data is stored safely on your device.';
  static String get expSec3Body2 =>
      isKo
          ? '즉, 아이의 키·몸무게 정보는 외부로 공유되지 않으며, 오직 사용자의 기기 안에만 보관됩니다.'
          : 'Your child\'s height and weight data is never shared externally — it stays only on your device.';
  static String get expSec3Body3 =>
      isKo
          ? '앱을 삭제하면 기기 내부 데이터도 함께 삭제될 수 있으므로, 중요한 데이터는 반드시 "백업 내보내기" 기능을 이용해 파일로 저장해두시기 바랍니다.'
          : 'Uninstalling the app may delete your data. Please use "Export Backup" to save important data as a file.';
  static String get expSec4Title => isKo ? '4. 백업 / 복원 기능' : '4. Backup & Restore';
  static String get expSec4Body1 =>
      isKo
          ? '상단의 업로드(↑) 아이콘을 누르면 현재 데이터를 .json 파일로 저장할 수 있습니다.\n이 파일은 휴대폰 저장공간, 클라우드, 메신저 등을 통해 보관할 수 있습니다.'
          : 'Tap the upload (↑) icon at the top to save your data as a .json file.\nYou can store it in device storage, cloud, or messaging apps.';
  static String get expSec4Body2 =>
      isKo
          ? '다운로드(↓) 아이콘을 누르면 이전에 저장해둔 백업 파일을 다시 불러올 수 있습니다.\n카카오톡, 메일 등으로 전달받은 백업 파일은 먼저 휴대폰 내 파일 앱(또는 다운로드 폴더)에 저장한 뒤 불러오기를 진행하세요.\n기기를 바꾸더라도 백업 파일이 있다면 데이터를 복원할 수 있습니다.'
          : 'Tap the download (↓) icon to restore from a previously saved backup file.\nIf you received a backup file via KakaoTalk, email, or similar, save it to your phone\'s Files app (or Downloads folder) first, then proceed with the restore.\nYou can restore your data even after changing devices.';
  static String get expSec5Title => isKo ? '5. 광고 안내' : '5. Ads';
  static String get expSec5Body =>
      isKo
          ? '무료 버전에서는 배너 광고와 전면 광고가 표시될 수 있습니다. 전면 광고는 저장·백업·복원 직후가 아니라, 주요 화면으로 이동하는 자연스러운 전환 시점에만 제한적으로 표시됩니다.'
          : 'The free version may show banner and interstitial ads. Interstitial ads appear only at natural screen transitions, never immediately after saving, backup, or restore.';
  static String get expSec6Title =>
      isKo ? '6. 개인정보 및 안전성' : '6. Privacy & Safety';
  static String get expSec6Body1 =>
      isKo
          ? '이 앱은 아이의 건강 데이터를 소중하게 생각합니다.\n기본적으로 서버 전송 없이 로컬 저장을 원칙으로 합니다.'
          : 'This app values your child\'s health data.\nLocal storage only — no server transmission by default.';
  static String get expSec6Body2 =>
      isKo
          ? '사용자의 동의 없이 개인 데이터를 외부로 전송하지 않습니다.'
          : 'Personal data is never transmitted externally without your consent.';
}
