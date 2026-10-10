# 무료 설치 + 커피 후원 실험

## 결정

**일반 사용자의 첫 경로는 GUI 다운로드, 개발자의 보조 경로는 설치 스크립트로
잡는다. 무료 직접 배포를 먼저 검증하고, App Store는 별도 sandbox 검증 뒤
진행한다. 구독·기능 잠금·계정 수 제한은 도입하지 않는다.**

개발자 App Store 계정은 이미 있고 제출 가능하다는 사용자 조건을 반영했다.
가입·등록비는 장애물이 아니다. 현재 코드의 외부 CLI·인증 방식과 배포 서명은
별개의 검증 대상이다. 이 Mac에서 확인한 Developer ID/Application Distribution
서명 identity는 0개다. 서명 인증서와 notarytool Keychain profile이 준비되면
직접 배포 공증 스크립트를 실행할 수 있다. 실제 심사 제출은 아직 하지 않았다.

## 1. 누구에게 무엇을 검증할까

대상은 매주 Codex/Claude를 쓰고 개인·업무 등 두 개 이상의 구독 계정을
구분해야 하는 Mac 사용자다. “AI 개발자 전부”를 대상으로 하지 않는다.

첫 실험의 모집 목표는 **20명, 한국어 10명·영어 10명, 14일**이다.
이는 확보한 고객 수나 시장 수요가 아니라 실험 설계다. 모집 글·이메일은
사용자가 선택한 채널에서 직접 게시하며, 이 작업에서 자동 발송하지 않았다.

가설:

1. 기존 CLI 로그인을 바꾸지 않는 작은 상시 패널 때문에 무료 경쟁 앱 대신
   Quota를 계속 켜둔다.
2. 개발 도구 없는 무료 설치와 한국어/영어 UI가 첫 연결 성공률을 높인다.
3. 모든 기능이 무료여도 일부 사용자는 선택적으로 커피값을 지불한다.

## 2. 실험 순서와 측정

| 기간 | 실행 | 수집할 증거 |
| --- | --- | --- |
| 준비 | Claude 연동 허용/공식 출력 경로 결정, 서명·공증, 깨끗한 Mac 설치 확인 | 앱 자체 설치·로그인 성공, 다른 CLI 로그인 불변 |
| Day 0 | 무료 다운로드, 첫 실행, 언어 선택, 두 계정 연결 | 성공/실패와 걸린 시간, 중단 단계 |
| Day 3 | 사용자가 실제 작업 중 작은 패널을 쓰는지 확인 | 켜둔 일수, 대체 앱, 가장 큰 마찰 |
| Day 7 | 유지 사용자에게 선택적 커피 후원을 안내 | 후원 버튼을 본 사람 수·실제 결제·질문 |
| Day 14 | 계속 사용할 앱을 선택하고 간단한 인터뷰 | 유지, 순수령액, 지원·개발 시간, 삭제 이유 |

앱에는 자동 telemetry를 넣지 않는다. 사용자 동의를 받아 짧은 인터뷰·수동
체크리스트·후원 플랫폼 집계로 측정한다. 이메일·계정 파일·토큰·인증 코드를
증거로 받지 않는다. GitHub 다운로드 수는 중복 설치를 포함하므로 사람 수로
계산하지 않는다. GitHub stars나 구매 의향도 실제 지불로 계산하지 않는다.

기록할 숫자:

- 시작한 사람 / 설치 성공 / 첫 연결 성공 / 두 계정 성공.
- 설치부터 첫 정상 사용량까지 시간과 실패 단계.
- Day 7·14에 여전히 사용하는 사람 수.
- 후원 안내를 실제 본 사람 수, 후원 건수, 환불 제외 순수령액.
- 지원 문의 수, 대응 시간, 제공자 API 변경 대응 시간.

**작은 표본의 의사결정 기준**: 20명 중 16명 이상이 별도 도움 없이 설치·첫 연결,
10명 이상이 Day 14에도 사용하고, 실제 후원 3건 이상이 발생하면 다음 실험으로
진행한다. 목표를 못 채우면 원인별로 설치·연결·패널 가치를 먼저 개선한다.
통계적 유의성이나 예상 매출을 주장하는 기준이 아니다.
순수령액에서 실제 현금 비용과 지원 시간의 가치를 빼고 커피값 목표에 도달하는지
판단한다. 표본을 늘리기 전에 사용자가 무료 대안보다 계속 선택하는지가 우선이다.

## 3. 후원 UX

README와 설정에 같은 **무료 설치**·**개발자에게 커피 사주기** 경로를 둔다.
후원은 자발적이며 기능·계정 수·갱신 주기·우선 지원을 구매하는 것이 아니다.
첫 실행이나 매번 조회할 때 후원 팝업을 띄우지 않는다.

사용자가 확정한 실제 후원 링크는 [Ko-fi / gridi](https://ko-fi.com/gridi)다.
앱과 두 README는 동일한 링크를 사용한다. 링크를 여는 것만으로 결제하지 않는다.
이 문서의 $3~$5는 실험 금액 가설이며 확정 가격이나 결제 상품이 아니다.

직접 배포판은 선택적 외부 후원 링크를 사용할 수 있다.
App Store판은 지역별 외부 결제 예외를 포괄적으로 가정하지 않고
**소비성 IAP 팁 또는 결제 없는 무료판**을 우선 검토한다.
소비성 상품은 한 번씩 자발적으로 구매하며 자동 갱신 구독이 아니다.

Apple [3.1.1](https://developer.apple.com/app-store/review/guidelines/#in-app-purchase)은
개발자 팁에 IAP를 사용할 수 있다고 안내한다.
[3.2.1(vii)](https://developer.apple.com/app-store/review/guidelines/#acceptable)는
디지털 콘텐츠·서비스와 연결된 선물에 IAP를 요구한다. “기능 해금이 없으면
모든 국가에서 외부 후원 링크가 허용된다”는 가정으로 제출하지 않는다.

## 4. 설치 스크립트만으로 충분할까

| 경로 | 장점 | 비용·제약 | Quota 판단 |
| --- | --- | --- | --- |
| 스크립트 | 버전·체크섬 검증, 개발자에게 빠름 | Terminal·다운로드 스크립트 실행의 신뢰 마찰 | 보조 경로 |
| 서명·공증 ZIP/DMG | GUI 설치, 기존 native 구조 유지 | Developer ID·Hardened Runtime·notarization 필요 | 첫 일반 사용자 경로 |
| Mac App Store | 검색·설치·업데이트 신뢰, 소비성 팁 | sandbox·번들 helper·권한·심사·공급자 허용 검증 | 별도 두 번째 실험 |

무료 [CodexBar](https://github.com/steipete/CodexBar)와
[ClaudeBar](https://github.com/tddworks/ClaudeBar)는 GitHub/Homebrew 직접 배포를
제공한다. CodexBar [packaging](https://github.com/steipete/CodexBar/blob/main/docs/packaging.md)
문서는 Developer ID·공증·Sparkle 경로를 설명하며, ClaudeBar README도 서명·공증
DMG를 안내한다. 스크립트만으로 배포하지 않는 비교 사례다.

[CUStats](https://apps.apple.com/us/app/custats-ai-usage-tracker/id6756333957?mt=12)는
미국 목록 $9.99 일회 구매, [Code Meter](https://apps.apple.com/us/app/code-meter-claude-codex-usage/id6760511858?mt=12)는
무료 다운로드와 lifetime IAP를 제공한다. 카테고리의 App Store 배포 가능성은
보이지만, 이 앱들이 Quota와 같은 외부 CLI·OAuth 설계를 승인받았다는 증거는 아니다.
경쟁사의 판매량과 후원액은 확인되지 않았다.

### App Store 준비에서 현재 필요한 차이

Apple [2.4.5](https://developer.apple.com/app-store/review/guidelines/#hardware-compatibility)는
Mac App Store sandbox와 독립 앱 번들·스토어 업데이트를 요구한다.
현재 임의의 외부 Codex 실행 파일과 문자열 경로의 `CODEX_HOME`을 그대로 쓰는
구조는 sandbox에서 검증되지 않았다.

- [번들 command-line helper](https://developer.apple.com/documentation/xcode/embedding-a-helper-tool-in-a-sandboxed-app)
  구조를 검토하고 부모 sandbox 상속·서명·종료를 테스트한다.
- 새 계정 프로필은 container 내부로 이동한다.
- 기존 폴더는 사용자의 파일 선택과 지속적인 security-scoped 접근을 검증한다.
  경로 문자열을 저장하는 것만으로 권한이 생기지 않는다.
- 개인정보처리방침과 데이터 삭제·권한 철회를 명시한다.
- [5.2.2](https://developer.apple.com/app-store/review/guidelines/#intellectual-property)에
  맞춰 제3자 서비스 연동 허용 근거를 확보한다.

따라서 지금 App Store 계정이 준비됐어도 **현재 번들을 바로 제출할 준비가
됐다는 결론은 아니다**. CLI가 전부 금지된 것도 아니다. 구현·권한 차이를
sandbox 실제 앱으로 확인한 뒤 무료판을 심사하는 것이 다음 단계다.

### 직접 배포 서명 절차

현재 빌드 스크립트는 재현 가능한 ad-hoc preview를 만든다.
Developer ID 인증서와 이미 설정한 notarytool Keychain profile을 준비한 뒤:

```sh
bash scripts/build-app.sh
export QUOTA_SIGNING_IDENTITY="your Developer ID Application identity"
export QUOTA_NOTARY_PROFILE="your existing Keychain profile"
bash scripts/notarize-app.sh
```

스크립트는 Hardened Runtime·timestamp로 서명하고 Apple notarization 결과를
기다린 뒤 ticket을 staple·검증하고 릴리스 ZIP을 만든다.
암호·키·인증서는 소스에 넣지 않는다.
공증은 [Apple 보안 검사](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)이지
App Review나 공급자 API 사용 허가는 아니다.

## 5. 비공개 Claude 조회 의존성이란

현재 Quota는:

1. Claude Code public client ID로 PKCE/state를 사용해 브라우저 인증한다.
2. `platform.claude.com/v1/oauth/token`에서 토큰 교환·갱신한다.
3. Bearer 토큰과 `anthropic-beta: oauth-2025-04-20`을 붙여
   `api.anthropic.com/api/oauth/profile`·`/api/oauth/usage`를 조회한다.
4. `five_hour`·`seven_day` 등의 응답을 읽어 구독 한도를 표시한다.

“비공개”는 API 키로 누구나 사용할 수 있는 문서화·지원된 제3자 **구독 한도 API
계약이 아니다**라는 뜻이다. 응답 필드·scope·beta header·조회 빈도·토큰 갱신
계약의 변경과 차단을 Quota가 직접 감당한다.

추가로 현재 [Anthropic 공식 인증 규정](https://code.claude.com/docs/en/legal-and-compliance#authentication-and-credential-use)은
제3자 개발자가 자체 앱에 Claude.ai 로그인을 제공하거나 credentials/session
tokens를 수집·저장·중개하는 것을 제한한다.
public client ID는 secret이 아니라는 뜻일 뿐, Quota가 승인된 클라이언트라는
뜻이 아니다. PKCE는 인증 코드 교환을 보호하지만 이 허용 문제를 해결하지 않는다.
사용자 동의·현재 조회 성공·경쟁 앱 존재·Apple 공증도 별도 허가의 증거가 아니다.

### 개선 선택지

| 선택 | 개선 | 포기하거나 확인할 것 |
| --- | --- | --- |
| 공식 Claude Code status-line snapshot | Quota가 Claude 토큰을 갖지 않고 공식 출력만 로컬 수신 | Claude Code 활동·세션에 의존; 종료된 비활성 계정의 독립 5분 갱신 불가 |
| 조회 전용 구독 API/클라이언트 명시적 허용 확보 | 현재 독립 갱신 UX 유지 가능성 | 지원 API와 해당 사용 사례의 공급자 허용을 실제로 받아야 함 |
| Claude를 수동 사용량 페이지 안내로 제한 | 토큰 저장·자동 비공개 조회 제거 | 자동 통합 한도 표시가 사라짐 |
| 공식 API Usage & Cost API로 교체 | 문서화된 API 사용량·비용 조회 | Pro/Max 구독 5시간·주간 quota와 다른 제품이므로 동일 기능 대체 아님 |

**추천 전환안은 공식 status-line 연동을 먼저 prototype하는 것**이다.
[공식 입력](https://code.claude.com/docs/en/statusline#rate-limit-usage)의
`rate_limits.five_hour.used_percentage`와 `seven_day.used_percentage`,
`resets_at`만 계정별 snapshot으로 전달한다. 전체 프롬프트·세션 내용·토큰은
저장하지 않는다. 기존 status-line 설정은 명시적으로 병합하고 자동 덮어쓰지 않는다.
앱은 계정 검증·관측 시각·“Claude Code 마지막 관측”을 표시하고 오래된 값을
현재 값처럼 취급하지 않는다.

status-line 스크립트의 refreshInterval은 공급자 quota를 새로 조회하는 보장이
아니다. 첫 응답 이후의 제공값, Claude Code가 실행 중인 계정, 계정별 설정과
snapshot 파일 접근을 검증해야 한다. 공식 연동의 안전성과 현재 요구한
독립 자동 갱신 UX 사이에 실제 기능 차이가 있다.

이번 작업에서는 기존 계정과 동작 중인 OAuth 연결을 임의로 삭제하거나
인증 방식을 바꾸지 않았다. 전환은 별도 구현 판단이며, 정식 유통 실험 전에
이 선택을 확정해야 한다.
