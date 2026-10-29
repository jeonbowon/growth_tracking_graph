# 테마 추가 및 유지보수

## 구조

- `lib/app_themes.dart`: 고정 ID, 이름, 분류, 공통 색상, 배경·효과 정의와 테마 목록.
- `lib/theme_controller.dart`: 자동/직접 선택, 저장·이전, 자정과 앱 복귀 시 날짜 갱신. 계절 판단의 단일 소스.
- `lib/seasonal_background.dart`: 날짜를 판단하지 않는 범용 `ThemeBackground`. 풍경과 효과를 조합해 그리며 화면 가림·백그라운드·접근성 설정에 따라 재생 정지.
- `lib/background_settings_sheet.dart`: 등록된 목록으로 정적 미리보기와 선택 UI 생성.
- `lib/main.dart`: 앱 전체에 ThemeData와 ThemeScope 전달. 테마 변경은 Navigator나 열린 화면을 초기화하지 않는다.

## 새로운 테마

`AppThemes.all`에 `AppThemeDefinition`을 추가한다. 예를 들어 숲 테마는 다음과 같이 등록할 수 있다. 이 예시는 실제 출시 목록에는 포함되어 있지 않다.

```dart
AppThemeDefinition(
  id: 'forest', nameKo: '숲', nameEn: 'Forest', group: 'nature',
  accent: Color(0xFF386344), chrome: Color(0xFFF0F6EF),
  tonal: Color(0xFFE0ECDD),
  ink: Color(0xFF304034), page: Color(0xFFF8FBF6),
  background: BackgroundDesign(
    sky: Color(0xFFEAF3E7), ground: Color(0xFFCCDDBF),
    effect: BackgroundEffect.none,
  ),
)
```

기존 `original / hills / snowyHills / image` 풍경과 `none / petals / clouds / leaves / snow` 효과를 조합한다. `speed`, `density`, 입자색을 지정할 수 있다. 새 물결이나 별똥별 같은 동작은 효과 구현과 테스트를 추가해야 한다.

이미지는 `scene: BackgroundScene.image, imageAsset: 'assets/themes/forest.webp'`로 지정하고 pubspec.yaml에 등록한다. 이미지 로딩 실패 시 기본 그라데이션이 남는다. 이미지는 표시 영역에 맞춰 잘릴 수 있으므로 중앙 정보 영역과 다양한 화면 비율을 검증한다. 외부 서버나 별도 권한은 필요하지 않다.

## 저장과 호환

- `app_theme_v1`: automatic, themeId, motion을 하나의 JSON으로 저장한다.
- 기존 `seasonal_background_v1`은 새 키가 없을 때만 이전한다. 원래 키와 성장 데이터는 삭제하지 않는다.
- ID를 이름·순서로 대체하거나 기존 ID를 다른 테마에 재사용하지 않는다. 제거된 수동 ID는 기본 테마로 대체한다.
- 미리보기는 정적이다. 새 테마 등록만으로 목록과 미리보기에 반영된다.
- 현재 테마 설정은 기기 설정이다. 기존 성장 데이터 백업 파일 형식에는 포함하지 않는다.

## 색상과 검증

공통 UI는 Theme.of(context)의 ColorScheme을 사용한다. 성별 표시, 오류, 차트 데이터 계열은 의미가 고정된 별도 색이다. 차트 본문은 판독성을 위해 밝은 표면을 유지한다.

현재 제공하는 테마는 모두 밝은 테마다. 어두운 테마를 출시하려면 brightness만 변경하지 말고 차트의 밝은 표면·축·툴팁과 보조 글자, 시스템 바까지 별도로 검증한다.

추가 후 `flutter test`, `flutter analyze`, Android 빌드를 실행한다. 작은 화면·큰 글자, 직접 선택 후 재실행, 자동 전환, 설정창 열린 상태의 색 전환, 애니메이션 끄기, 광고 후 이동 순서를 검증한다. 새 테마도 버튼의 일반 텍스트 대비 검사에 자동 포함된다.
