# Quota — macOS Claude·Codex 사용량 확인 앱

[English](README.md) · **무료 설치 · 구독료 없음 · 한국어/영어 · macOS 14 이상**

개인·업무용 Claude와 Codex 구독 계정의 **남은 사용량**을 메모지처럼 작은 창과
메뉴 막대에 표시합니다. 핀으로 항상 위에 띄울 수 있고, 없는 한도를 100%라고
추정하거나 서로 다른 계정의 퍼센트를 평균내지 않습니다.

## 무료 설치

[공개 릴리스](https://github.com/gridi-ai/quota/releases)에서 Apple Silicon용 ZIP을
받아 압축을 풀고 `Quota.app`을 Applications에 넣습니다. 개발 도구는 필요 없습니다.
현재 공개 preview는 Apple 공증이 되지 않은 ad-hoc 서명 앱입니다.
차단되면 소스를 확인한 뒤 시스템 설정 → 개인정보 보호 및 보안 → 그래도 열기를
사용합니다. 설치 스크립트는 Gatekeeper를 끄거나 quarantine을 제거하지 않습니다.

v0.1.1 스크립트로 설치하려면:

```sh
curl -fL https://raw.githubusercontent.com/gridi-ai/quota/v0.1.1/scripts/install.sh -o /tmp/quota-install.sh
less /tmp/quota-install.sh
bash /tmp/quota-install.sh
open "$HOME/Applications/Quota.app"
```

스크립트는 SHA-256·번들 서명을 확인하고 `~/Applications`에 설치합니다.
sudo를 사용하지 않으며 계정 데이터는 바꾸지 않습니다.
기존 앱을 갱신하려면 Quota를 종료하고 `--replace`를 추가합니다.
Intel Mac은 아래 소스 빌드를 이용합니다.

## 계정 연결

앱에서 **계정 추가…**를 선택하고 제공자와 별칭을 입력합니다.

- **Codex**: [공식 Codex CLI](https://developers.openai.com/codex/cli/)를 설치하고
  실행 파일을 지정합니다. 새 계정마다 별도 프로필로 브라우저 로그인합니다.
  로그인 후 **연결 확인**을 누릅니다. 기존 프로필은 직접 폴더를 지정하며,
  계정마다 서로 다른 프로필을 사용합니다.
- **Claude**: 기본 브라우저에서 로그인한 뒤 표시되는 인증 코드 전체를 복사합니다.
  **인증 코드 입력… → 인증 코드로 연결**을 선택합니다.
  Cmd+V·Ctrl+V·붙여넣기 버튼·Enter를 지원합니다.
  Claude CLI나 브라우저를 계속 켜둘 필요는 없습니다.

현재 Claude 연동은 Claude Code public OAuth client와 문서화되지 않은 usage
경로를 사용합니다. 동의 화면에는 Claude Code로 표시됩니다. 이것이 Quota에
대한 공식 연동 허가를 의미하지는 않습니다. 공급자의 현재 인증 제한과 공식
status-line 전환안은 [실험·배포 검토](docs/EXPERIMENT.md)에 설명했습니다.

## 언어와 설정

`Cmd+,` 또는 메뉴 막대의 **설정…**에서 시스템 언어·한국어·English를 고릅니다.
UI·메뉴·오류·사용량 기간 표기를 바꿉니다. 사용자가 입력한 별칭이나 제공자가
반환한 계정 식별자는 번역하지 않습니다.
이미 표시된 상태 메시지는 다음 갱신까지 관측 당시 언어를 유지하며,
새로 발생하는 앱 오류는 선택한 언어를 사용합니다.

컴팩트/확장 보기, 시스템/페이퍼/다크 테마, 항상 위에 표시를 지원합니다.
닫기는 창만 숨기고 종료는 자동 갱신과 CLI helper를 끝냅니다.
메뉴 막대의 `*`는 오래되거나 실패한 마지막 관측값이고 `—`는 조회값이 없다는 뜻입니다.

## 무료 설치와 개발자에게 커피 사주기

**[Quota 무료 설치](https://github.com/gridi-ai/quota/releases)** ·
**[개발자에게 커피 사주기 — Ko-fi](https://ko-fi.com/gridi)**

후원은 선택 사항입니다. 후원 여부와 관계없이 모든 기능을 무료로 사용할 수
있으며 구독료·계정 수 제한·유료 기능 잠금·우선 지원 구매는 없습니다.
같은 링크를 앱 설정에서도 열 수 있습니다. Ko-fi를 여는 것만으로 결제되지는
않으며, 사이트에서 사용자가 직접 후원 여부를 선택합니다.

## 개인정보

Quota 서버나 분석 추적은 없습니다. 계정 별칭·확인된 식별자·마지막 사용량은
`~/Library/Application Support/Quota/accounts.json`에 저장됩니다.
Claude 토큰은 계정별 앱 소유 Keychain 항목, Codex 인증은 지정한 CLI 프로필에
저장됩니다. 앱은 기존 브라우저 쿠키나 Claude CLI 토큰을 가져오지 않습니다.

목록에서 제거해도 제공자 grant·Keychain·Codex 프로필을 삭제하지 않습니다.
완전히 연결 해제하려면 제공자 권한을 철회하고 해당 로컬 인증정보도 제거합니다.

## 소스에서 빌드

Swift 6 이상/Xcode Command Line Tools와 macOS 14 이상이 필요합니다.

```sh
git clone https://github.com/gridi-ai/quota.git
cd quota
bash scripts/build-app.sh
open dist/Quota.app
swift test --enable-code-coverage
```

`swift run Quota --demo`는 계정 저장·실제 조회 없이 예시 화면을 표시합니다.
MIT 라이선스입니다. [문제 신고](https://github.com/gridi-ai/quota/issues)에는
인증 코드·토큰·쿠키·계정 파일을 첨부하지 마세요.
