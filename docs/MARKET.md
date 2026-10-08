# Quota: 경쟁과 비구독 수익성 검토

조사 기준: 2026-10-08. 가격은 조사 당시 미국 스토어 또는 제작자 페이지의
표시 가격이다. 경쟁 앱을 직접 실행하거나 매출을 확인한 결과는 아니다.

## 결론

**커피값을 벌 수 있는 작은 제품으로 실험할 가치는 있다. 다만 “Claude·Codex
사용량 표시”만으로는 무료 경쟁 앱보다 구매할 이유가 부족하다.**

가장 좁고 설득력 있는 대상은 개인·업무 등 여러 계정을 쓰면서, 터미널의 로그인
계정을 바꾸지 않고 작은 패널을 계속 띄워두고 싶은 Mac 사용자다.
추천 포지셔닝은 다음과 같다.

> 터미널 로그인을 바꾸지 않고, 개인·업무용 Codex와 Claude 계정의 남은 한도를
> 한곳에 띄워두는 Mac 앱.

현재 공개판은 무료 MIT 소스와 설치 가능한 Apple Silicon 앱이다. 유료 구독은
도입하지 않는다. 우선 무료 베타와 선택적 소액 후원을 검증하고, 설치·인증 경험이
검증된 뒤 일회 구매를 판단하는 편이 낫다.

## 실제 경쟁 제품

| 제품 | 확인한 기능 | 가격·라이선스 | 배포 |
| --- | --- | --- | --- |
| [CodexBar](https://github.com/steipete/CodexBar) | 여러 제공자, 메뉴 바, 리셋·기록·알림·WidgetKit, 관리 계정 | 무료, MIT | macOS 14+, Homebrew, GitHub Releases, 서명·공증 파이프라인 |
| [ClaudeBar / tddworks](https://github.com/tddworks/ClaudeBar) | Claude·Codex 각각 다중 로그인, 독립 갱신·오류, 계정별 메뉴 바 고정 | 무료, Apache 2.0; 일부 구성요소 별도 라이선스 | macOS 15+, Homebrew, 서명·공증 DMG라고 안내 |
| [ClaudeBar / vinnysaj](https://github.com/vinnysaj/ClaudeBar) | Claude 다중 계정, 기본 브라우저, 자체 Keychain, 선택적 자동 전환 | GitHub 배포; 읽은 README에서 가격·라이선스 미확인 | 공증 앱·Sparkle이라고 안내; 활성 CLI 인증정보를 교체하는 흐름 |
| [CUStats](https://apps.apple.com/us/app/custats-ai-usage-tracker/id6756333957?mt=12) | Claude·Codex 등, 메뉴 바, 주간 페이스·리셋·알림 | $9.99 일회 구매 | Mac App Store, macOS 13+ |
| [Code Meter](https://apps.apple.com/us/app/code-meter-claude-codex-usage/id6760511858?mt=12) | 여러 제공자, 메뉴 바, 소진 속도·알림 | 무료 다운로드, Lifetime IAP $1.99 / $3.99; 기능 경계 미확인 | Mac App Store, macOS 26+ |
| [TokenUsageMonitor](https://apps.apple.com/us/app/tokenusagemonitor/id6761013095?mt=12) | Claude·Codex·Copilot, 메뉴 바·데스크톱 위젯 | $0.99 | Mac App Store, macOS 13+ |
| [Brim](https://getbrim.tech/) | Claude·Codex, SwiftUI 메뉴 바, 로컬 기록·페이스 | $2 / ₹179 일회 구매라고 안내 | 직접 ZIP 배포, Intel/Apple Silicon, ad-hoc 서명·미공증 |

위 표의 서명·공증 정보는 프로젝트 문서의 설명이며 경쟁 배포 바이너리 자체를
검사하지 않았다. 판매 페이지가 있다는 것은 매출 규모를 입증하지 않는다.

### 아직 출시 상품으로 계산하면 안 되는 후보

[CapMeter](https://capmeter.app/)는 다중 Claude·Codex 계정, Keychain, 서버 없음,
항상 위·Space 간 패널, 기록·알림·소진 예측을 제시한다. 14일 체험과 $9.99
일회 출시가, 이후 $14.99를 안내하지만 구매 영역에는 “Coming soon to the
Mac App Store”가 표시되어 있다. 실제 출시·판매 증거로 취급하지 않는다.
다만 Quota의 패널 포지셔닝과 상당히 겹치는 경쟁 후보다.

## Quota의 강점과 약점

### 강점

- **한 화면의 작은 상시 패널:** 편집기 옆에서 계정별 독립 한도를 비교한다.
  메뉴를 열어야 하는 제품과 다른 사용 경험이다. 유일한 기능이라는 주장은 아니다.
- **기존 CLI 로그인 불변:** Codex는 별도 프로필, Claude는 새 OAuth grant와
  앱 소유 Keychain 항목을 사용한다. 다른 CLI 토큰을 가져오거나 바꾸지 않는다.
- **두 제공자에 집중:** 과금 추정·모델 호출 없이 실제 반환된 구독 한도만 표시한다.
  계정·기간의 퍼센트를 평균내지 않고 실패한 계정만 오래된 값으로 표시한다.
- **서버 없는 네이티브 앱:** SwiftUI/AppKit, 패키지 의존성 없음, 로컬 상태.
- **macOS 14 지원:** 더 최신 OS만 지원하는 일부 경쟁 상품보다 범위가 넓다.

다중 계정, 브라우저 로그인, Keychain, 서버 없음, 구독 없음은 이미 경쟁 제품에도
있다. 단독으로 독창성이나 높은 가격을 정당화하지 않는다.

### 약점

- 무료 CodexBar·ClaudeBar가 기능·배포 성숙도에서 강하다.
- 현재 UI가 한국어이며 배포 바이너리는 Apple Silicon만 지원한다.
- ad-hoc 서명·미공증이라 첫 설치에서 신뢰와 Gatekeeper 마찰이 생길 수 있다.
- Codex CLI가 필요하고, Claude는 인증 코드를 직접 복사해 돌아와야 한다.
- 자동 업데이트, 알림, 사용 기록·페이스 예측은 현재 제공하지 않는다.
- 실제 검증은 Codex 두 계정과 Claude 한 계정까지다. 두 번째 Claude,
  실제 sleep/wake, 전체 live token-expiry 회전은 추가 검증 영역이다.
- Anthropic의 문서화된 공용 구독 usage API가 아니다. 조회 경로 또는 인증 정책이
  바뀌면 무료판·유료판 모두 유지보수 비용을 부담한다.

## 인증과 상용 배포의 제약

[Codex app-server](https://developers.openai.com/codex/app-server)의
`account/rateLimits/read`는 문서화되어 있지만 CLI 버전 의존성이 있다.

Claude OAuth usage 경로는 [CodexBar 통합 문서](https://github.com/steipete/CodexBar/blob/main/docs/claude.md)
등 제3자 구현에서 확인된다. Quota는 Claude Code의 public client ID를 이용한다.
client ID 자체는 credential이 아니지만 **secret이 없다는 사실과 제3자 앱 사용이
공식 승인되었다는 주장은 다르다.** 상용 앱에 대한 공식 승인·장기 호환성은
확인되지 않았다.

[Anthropic 개발자 안내](https://support.claude.com/en/articles/13189465-log-in-to-your-claude-account)는
제3자 제품에 API-key 인증을 안내한다. API 사용량은 Pro/Max 구독 한도와 다르다.
조회 전용 트래커가 금지됐다고 단정할 근거로 삼지는 않되, 유료 판매 전에
정식 연동 가능 범위를 확인해야 하는 구체적 제약이다.

[공식 Claude status-line rate_limits](https://code.claude.com/docs/en/statusline#rate-limit-usage)
를 읽는 [AI Usage Tracker](https://github.com/athiriot/ai-usage-tracker) 같은 대안도
있다. 인증 토큰이나 비공개 API를 읽지 않는 대신, 응답 후 받은 마지막 값이므로
다른 기기에서 쓰거나 비활성 계정을 독립 갱신하는 용도에는 불리하다.

기본 브라우저 사용은 [Google의 embedded user-agent 정책](https://developers.google.com/identity/protocols/oauth2/policies)
과도 맞는다. Google 로그인 성공만으로 Quota의 Claude OAuth 연동이 공식
지원된다고 해석하지 않는다.

## 일회 판매·후원 모델

**추천 시작점: 무료 베타 + 선택적 $5 후원.** 이는 가격 실험이지 예상 수익이
아니다. 현재 결제 계정·후원 링크는 생성하지 않았다.

후원으로 실제 지불과 사용 유지가 확인되고 설치·연결 문제가 줄면,
서명·공증된 편의 배포판을 **$4.99 일회 구매**로 실험할 수 있다.
MIT 소스는 누구나 무료로 빌드·재배포할 수 있으므로, 결제 대상은 독점 코드가
아니라 검증된 설치·업데이트·지원 경험이어야 한다. 자동 업데이트는 아직 없다.

[Apple Developer Program](https://developer.apple.com/programs/)은 연 $99다.
$4.99 판매 20건이면 총액 $99.80이지만, 결제 수수료·환불·세금·지원 시간 전
금액이다. “20건이면 순이익”이라는 계산은 틀리다. 비용을 빼고 남는 돈이
목표 커피값을 넘는지 실제 결제로 확인해야 한다.

App Store 경쟁 상품이 존재한다고 해서 Quota의 외부 CLI·OAuth 흐름이 그대로
심사를 통과한다는 뜻은 아니다. 초기에는 직접 다운로드 배포를 검증하고,
App Store는 별도 검토 대상으로 두는 편이 현실적이다.
[Sequoia 이후 Apple 설치 안내](https://developer.apple.com/news/?id=saqachfa)에 맞춰
미공증 판의 차단 해제는 Privacy & Security에서 안내한다. Homebrew나 설치
스크립트는 Developer ID·공증을 대체하지 않는다.

## 작은 검증 실험

다중 계정 사용자 10명에게 2주 베타를 제안하는 것을 첫 가설로 삼는다.
수치는 실험 설계이며 이미 확보한 고객이나 수요가 아니다.

1. CodexBar·ClaudeBar와 비교해 어느 앱을 계속 켜두는지 관찰한다.
2. 깨끗한 Mac에서 설치, 첫 연결, 계정 추가·재인증을 본다.
3. 두 번째 Claude 계정·토큰 회전·sleep/wake 검증을 마친다.
4. 브라우저 확인이나 CLI 로그인 전환이 실제로 줄었는지 묻는다.
5. 선택적 후원을 제안하고 실제 결제·환불·지원 시간을 기록한다.

GitHub stars·다운로드·설문상의 구매 의향을 매출로 환산하지 않는다.
사용자가 무료 대안보다 Quota의 패널과 격리를 계속 선택하고 실제 소액을
지불한다면 커피값 제품으로 진행한다. 그렇지 않으면 제공자를 더 늘리기보다
설치·로그인 마찰이나 패널의 실제 가치를 먼저 수정한다.
