# 우리아이 성장 그래프 — Claude 작업 지침

## 중요 규칙 (반드시 준수)

**수정 작업 전에 반드시 아래 순서를 따를 것:**

1. 수정할 내용을 사용자에게 먼저 자세하게 설명한다
2. 사용자가 "수정해라" 또는 승인 지시를 하면 그때 수정을 진행한다
3. 사용자의 승인 없이 먼저 코드를 수정하지 않는다

---

## 프로젝트 개요

- **앱 이름:** 우리아이 성장 그래프
- **패키지:** com.tnbsoft.growth_tracking_graph
- **플랫폼:** Flutter (Android 주력)
- **현재 버전:** pubspec.yaml의 version 참고

## 주요 화면 구조

- `lib/page_main.dart` — 메인 화면 (자녀 목록, 바텀시트 메뉴)
- `lib/child_growth_chart.dart` — 성장 그래프 화면
- `lib/child_growth_list.dart` — 성장 데이터 목록/수정
- `lib/child_growth_input.dart` — 데이터 입력
- `lib/page_standard_growth_chart.dart` — 표준 성장 도표
- `lib/ad_service.dart` — 광고 통합 서비스

## 광고 구조

- **AdMob** (Google): 배너 + 전면광고
- **Kakao AdFit**: 배너 + 전면광고 (AdFitPopupAdDialogFragment 방식)
- **Meta (Facebook)**: 배너 + 전면광고
- 우선순위 순서: admob → kakao → meta (서버 설정으로 변경 가능)
- 전면광고는 자연스러운 화면 전환 시점에만 표시, 90초 쿨다운, 2회마다 1회 표시

## Android 빌드 주의사항

### gradle.afterProject 패치 (`android/build.gradle.kts`)
facebook_audience_network 플러그인(v1.0.1)이 낮은 compileSdk를 사용하여
Meta SDK 신버전의 `lStar`(API 31) 리소스를 찾지 못하는 문제를 해결하기 위해
모든 라이브러리 서브프로젝트에 `compileSdk = 36`을 강제 적용하고 있다.
- `plugins.withId` 방식은 서브프로젝트 자체 설정에 덮어씌워져 동작 안 함
- `subprojects { afterEvaluate }` 방식은 "already evaluated" 오류 발생
- `gradle.afterProject` 방식이 유일하게 올바르게 동작함 → 변경하지 말 것

### Meta SDK 버전
`implementation("com.facebook.android:audience-network-sdk:6.+")` — 와일드카드로
Meta가 SDK를 업데이트하면 자동으로 새 버전을 가져옴. 위 compileSdk 패치로 대응 중.

## 과거 주요 버그 수정 이력

### context shadowing 버그 (page_main.dart)
`_showActionSheet`의 `builder: (context) =>` 파라미터가 PageMain의 context를 shadowing하여
전면광고 후 Navigator.push가 폐기된 바텀시트 context를 사용하게 되는 버그.
`builder: (_) =>` 로 수정하여 해결. 광고 없는 메뉴(데이터 입력)는 async 갭이 없어 무관.

### 전면광고 후 화면이동 순서 정립 (page_main.dart, 2026-05-05)

**증상:** 그래프 보기 / 보기·수정 탭 시 전면광고가 표시된 후 메인화면으로 돌아가는 문제.

**원인:** 광고를 먼저 보여준 뒤 Navigator.push를 호출해야 하는데,
Navigator.push → 광고 순서로 되어 있어 AdMob Activity가 스택 위에서 종료된 후
Flutter가 resume되는 동안 몇 초간 메인화면이 보였고, 그 후에야 그래프로 이동했다.

**최종 정립된 흐름:**
```
탭 → 바텀시트 닫기 → 전면광고(있을 때) → Flutter resume(몇 초) → 그래프/데이터 화면
```

**코드 (page_main.dart `_showActionSheet` 내부):**
```dart
// 보기·수정 / 그래프 보기 공통 패턴
onTap: () async {
  Navigator.pop(context);                                         // 바텀시트 닫기
  await AdService.instance.tryShowInterstitialOnNaturalTransition(); // 광고 먼저
  if (!mounted) return;                                           // 광고 후 context 확인
  Navigator.push(context, MaterialPageRoute(builder: (_) => ...)); // 그 다음 이동
},
```

**AdMob 정책 준수 여부:**
AdMob 정책은 "사용자 행동 → 광고 → 결과" 흐름을 권장한다.
탭(행동) → 광고 → 화면이동(결과) 순서이므로 정책에 부합한다.

**불가피한 현상 — Flutter resume 지연:**
AdMob 전면광고는 별도 Android Activity로 실행된다.
광고 종료 후 Flutter Activity가 onResume되기까지 하드웨어/OS 특성상 1~3초가 소요된다.
이 시간 동안 메인화면이 잠깐 보이는 것은 Flutter 코드로 해결 불가능하며 정상 동작이다.
→ 이 현상을 없애려고 Navigator.push를 광고 앞으로 옮기면 AdMob 정책 위반 소지가 생기므로 옮기지 말 것.

**주의 — 데이터 입력 메뉴는 광고 없음:**
데이터 입력(ChildGrowthInput) 탭은 전면광고를 호출하지 않으므로 async 갭이 없다.
별도 처리 불필요.
