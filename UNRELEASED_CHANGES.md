# 미출시 변경사항 (로컬 수정, 아직 프로덕션 미반영)

> 기준 커밋: `9708f4b` — "Default Ad 순서 변경" (현재 프로덕션 버전)
> 현재 pubspec 버전: 1.1.3+23
> 기록일: 2026-05-05

---

## 1. `lib/page_main.dart` — 버그 수정 2건

### 1-1. context shadowing 버그 수정

**변경 위치:** `_showActionSheet` 내 `showModalBottomSheet` 호출부 (line ~168)

```dart
// 수정 전
builder: (context) => SafeArea(...)

// 수정 후
builder: (_) => SafeArea(...)
```

**문제:** `builder: (context) =>` 파라미터가 외부 `_MainPageState`의 `context`를 shadowing하고 있었음.
전면광고(별도 Android Activity)가 종료된 후 Flutter가 resume되는 시점에 `Navigator.push`가 이미 폐기된 바텀시트 context를 참조하게 되어 오동작 발생.

**해결:** `builder: (_) =>` 로 변경해 바텀시트 builder context를 무시하고,
외부 `_MainPageState.context`(mounted 여부 검증된 context)를 사용하도록 수정.

---

### 1-2. 불필요한 `await Navigator.push` 제거 (3곳)

`Navigator.push`의 반환값(`Future<T?>`)을 사용하지 않으므로 `await` 불필요.
데이터 입력 탭은 `async` 자체도 제거.

| 위치 | 수정 전 | 수정 후 |
|---|---|---|
| 데이터 입력 탭 (`ChildGrowthInput`) | `onTap: () async { ... await Navigator.push(...) }` | `onTap: () { ... Navigator.push(...) }` |
| 보기·수정 탭 (`ChildGrowthList`) | `await Navigator.push(...)` | `Navigator.push(...)` |
| 그래프 보기 탭 (`ChildGrowthChart`) | `await Navigator.push(...)` | `Navigator.push(...)` |

**주의:** 보기·수정 / 그래프 보기 탭은 `tryShowInterstitialOnNaturalTransition()`은 여전히 `await` 유지.
전면광고 완료 후 화면 이동해야 하므로 광고 호출 자체는 await 필수.

---

## 2. `android/build.gradle.kts` — 빌드 설정 개선

### `gradle.afterProject` 방식으로 compileSdk 강제 패치

**문제:** `facebook_audience_network` 플러그인(v1.0.1)이 낮은 `compileSdk`를 사용하여
Meta SDK 신버전의 `lStar` 리소스(API 31 이상 필요)를 찾지 못하는 빌드 오류 발생.

**변경 전:** `subprojects { plugins.withId("com.android.library") { ... } }` 방식
- namespace 누락 패치만 있었고 `compileSdk` 강제 적용이 없었음
- `plugins.withId` 방식은 서브프로젝트 자체 설정에 덮어씌워져 compileSdk 적용 안 됨

**변경 후:** `gradle.afterProject { ... lib.compileSdk = 36 }` 방식

```kotlin
// 수정 후 전체 블록
gradle.afterProject {
    extensions.findByType(com.android.build.gradle.LibraryExtension::class)?.let { lib ->
        if (lib.namespace == null) {
            lib.namespace = group.toString()
        }
        lib.compileSdk = 36
    }
}
```

**방식 선택 근거:**
- `plugins.withId` 방식 → 서브프로젝트 자체 설정에 덮어씌워져 동작 안 함 (탈락)
- `subprojects { afterEvaluate }` 방식 → "already evaluated" 오류 발생 (탈락)
- `gradle.afterProject` 방식 → 각 프로젝트 설정 완료 후 실행되므로 안전하게 오버라이드 가능 (채택)

**효과:** 모든 라이브러리 서브프로젝트(facebook_audience_network 포함)에 `compileSdk = 36` 강제 적용되어 Meta SDK 최신 버전과 호환됨.

---

## 출시 시 체크리스트

- [ ] pubspec.yaml `version` 번호 올리기 (현재 1.1.3+23)
- [ ] `UNRELEASED_CHANGES.md` 내용을 릴리즈 노트/커밋 메시지에 반영
- [ ] Android 빌드 확인 (Meta SDK compileSdk 패치 적용 여부)
- [ ] 전면광고 후 화면 이동 흐름 최종 테스트
