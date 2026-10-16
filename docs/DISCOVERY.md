# Quota 검색·AI 답변 노출 대응

조사일: 2026-10-16. 검색 순위·키워드 검색량·유입·매출을 측정한 보고서는 아니다.
GEO는 여기서 generative engine optimization, 즉 AI 검색·답변에서 제품 정보를
발견하고 인용하기 쉽도록 만드는 작업을 뜻한다.

## 현재 진단과 결정

공개 채널은 GitHub 저장소와 릴리스였다. 저장소 설명·9개 토픽은 이미 설정돼
있지만 홈페이지 URL이 없고 Pages도 비활성 상태였다. `Quota`라는 일반 명사만
내세우기보다 **Mac용 Claude·Codex 다중 계정 구독 한도 위젯**을 설명해야 한다.
`"gridi-ai/quota" Claude Codex` 브랜드 한정 질의에서는 검색 도구가 실제 저장소를
반환했다. 이는 일반 질의의 Google 순위·검색량이나 새 사이트 색인을 뜻하지 않는다.

첫 검색 의도는 `Claude Codex usage tracker Mac`, `multiple accounts quota Mac`,
`Claude usage limit reset widget`, `Mac Claude Codex 사용량`, `클로드 코덱스
여러 계정 한도 확인`이다. 검색량이 확인된 키워드나 순위 예측이 아니라 제품과
일치하는 질의 가설이다. API 비용 계산과 구독 한도는 다른 질문으로 구분한다.

`site/`에 영어·한국어 정적 HTML을 만들었다. JS 실행 없이 핵심 설명·설치·실제
제약·FAQ를 읽을 수 있다. title/description, canonical, 상호 hreflang, OG/Twitter,
SoftwareApplication JSON-LD와 sitemap을 제공한다. 무료 가격·OS·버전은 실제
앱과 일치시키고 평점·리뷰·인기 수치는 만들지 않는다. JSON-LD가 있다고
Google 앱 rich result 자격이나 노출이 보장되는 것은 아니다.

현재 공개 주소는 [영어](https://gridi-ai.github.io/quota/)와
[한국어](https://gridi-ai.github.io/quota/ko/)다. 사용자의 커밋·푸시·공개 승인을
받아 Pages를 활성화하고 `5221051`을 게시했다. 두 경로의 HTTPS/200, 데스크톱·모바일
실제 렌더링, 공개 파일과 검증한 빌드의 byte 일치를 확인했다.
`site.yml`의 push/PR 실행은 검증과 artifact 생성만 하며,
main에서 수동 실행하고 `publish=true`를 명시한 경우에만 배포한다.
README와 저장소 homepage도 실제 공개 주소에 연결한다.

## 근거

- [Google AI features](https://developers.google.com/search/docs/appearance/ai-features):
  AI Overviews/AI Mode에도 기본 SEO가 적용된다. 색인과 snippet 자격이 필요하며
  추가 AI 전용 기술 요건은 없다. 유용한 텍스트, 내부 링크, 접근 가능한 페이지가 우선이다.
- [OpenAI crawlers](https://developers.openai.com/api/docs/bots):
  OAI-SearchBot은 ChatGPT 검색, GPTBot은 학습 용도 제어이며 독립적이다.
  검색 수집 허용을 위해 학습 수집까지 허용할 필요는 없다. 허용은 노출 보장이 아니다.
- [Google software app markup](https://developers.google.com/search/docs/appearance/structured-data/software-app):
  구조화 데이터는 눈에 보이는 사실과 맞아야 한다. 없는 리뷰를 채워 넣지 않는다.
- [GitHub Pages 주소](https://docs.github.com/en/pages/getting-started-with-github-pages/what-is-github-pages):
  프로젝트 사이트는 `/quota/` 아래에 있다.
- [robots.txt 위치](https://developers.google.com/search/docs/crawling-indexing/robots/create-robots-txt):
  robots는 호스트 루트의 `/robots.txt`에 있어야 한다. `/quota/robots.txt`를
  추가해 크롤러를 제어했다고 주장하지 않는다. 이 작업은 다른 조직 사이트의
  root robots를 수정하지 않는다. 게시 후 실제 root 정책과 응답을 확인해야 한다.
- [IndexNow](https://www.indexnow.org/documentation): URL 변경 알림 프로토콜이며
  수신 성공은 색인 성공이 아니다. 소유권 키가 필요하므로 가짜 키를 배포하지 않는다.
- [llms.txt 제안](https://llmstxt.org/): 보조 문서 지도 제안이지 Google·AI 검색
  노출 요건이나 순위 상승 보장이 아니다. 현재 두 페이지 규모에서는 별도 파일
  양산 대신 실제 본문·FAQ·출처를 우선했다.

Anthropic crawler 정책의 공식 현재 문서는 이번 조회에서 유효한 원문을 확보하지
못했다. Claude-SearchBot/ClaudeBot의 현재 제어 동작을 확인했다고 주장하지 않는다.
제품 OAuth 제한과 검색 크롤러 정책도 서로 다른 사안이다.

## 경쟁 제품에서 관측한 것

| 표면 | 실제 관측 | Quota에 적용할 판단 |
| --- | --- | --- |
| [CodexBar](https://codexbar.app/) | 자체 소개 페이지, 무료·OS 정보, 설치·릴리스·제공자별 문서 링크 | 제품 설명에서 설치와 상세 답변으로 연결 |
| [ClaudeBar](https://github.com/tddworks/ClaudeBar) | README 제품 정의, 스크린샷, Homebrew·릴리스, 제공자·트러블슈팅 문서 | 짧은 정의와 설치 진입점, 실제 문제에 답하는 문서 |

관측은 검색 노출량이나 해당 기능의 SEO 효과를 입증하지 않는다. 경쟁 앱의 넓은
제공자 수를 따라가기보다 Quota의 작은 상시 창·기존 CLI 로그인 불변·두 언어에 집중한다.

## 실행 우선순위

1. **게시·측정 기반:** Pages 게시 승인 → HTTPS와 두 경로 확인 → README와
   저장소 홈페이지에 실제 주소 연결 → Search Console/Bing 소유권 확인.
2. **신뢰·전환:** 공개 전 일반 사용자 실험에서는 기존 Claude 연동 허용/전환,
   Developer ID 공증 문제를 먼저 해결한다. 미공증·실험적 연동을 숨겨 다운로드만
   늘리면 설치 이탈과 지원 부담이 늘 수 있다.
3. **질문별 실용 콘텐츠:** 실제 문의가 생기는 순서대로 한도 초기화, 다중
   Codex 프로필, Mac 설치 차단, 구독 quota와 API 비용 차이를 검증된 예제로 보강한다.
   현재 소개의 FAQ가 첫 답변이며 비슷한 문서를 키워드만 바꿔 양산하지 않는다.
4. **관련 커뮤니티:** macOS 개발자·Claude/Codex 사용자 채널에 실제 사용 사례와
   제약을 함께 소개한다. Product Hunt/Show HN/관련 커뮤니티는 적합성을 확인한 뒤
   사용자가 게시한다. 이 작업에서 글·댓글·디렉터리 제출을 자동 발송하지 않는다.
5. **편의 유통:** 서명·공증과 안정적 업데이트를 준비한 뒤 Homebrew 등을 검토한다.
   아직 존재하지 않는 cask 설치 명령이나 App Store 배지를 붙이지 않는다.

## 게시 절차와 권한 경계

```sh
bash scripts/build-site.sh
python3 scripts/check-site.py .build/site
```

배포 artifact는 `.build/site`만 사용한다. 저장소 전체나 `docs/`를 Pages로
공개하지 않아 세션·검증 이미지·내부 초안·계정 파일이 섞이지 않는다.
현재 사이트의 도메인·소스·외부 링크를 검토한 뒤 사용자의 명시적 승인으로
GitHub Pages를 이 저장소에 활성화하고 이 artifact를 배포했다. 도메인을 바꾸면 두 페이지의
canonical/hreflang/OG/schema와 sitemap, 검증기의 BASE를 함께 바꾸고 다시 검증한다.

Pages는 GitHub Actions 배포 모드이며, 승인된 게시 때 다음 수동 실행을 사용한다:

```sh
gh workflow run site.yml --ref main -f publish=true
```

초기 공개 커밋은 `5221051`이고 [배포 실행 38920931991](https://github.com/gridi-ai/quota/actions/runs/38920931991)이
성공했다. 앱 검증·사이트 검증도 통과했다. 공개 HTML/CSS/아이콘/sitemap을
다운로드해 검사했고 빌드와 정확히 일치했다. [공식 workflow 문서](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages)의
artifact·needs·environment·최소 배포 권한 구조를 따른다.

사이트 게시와 검색 등록은 별개다. Search Console/Bing 소유권 확인·sitemap 제출,
IndexNow 요청은 실행하지 않았으며 검색 색인·AI 답변 인용을 확인했다고 주장하지 않는다.

소유자가 할 실제 검색 등록:

- Search Console에서 **URL-prefix** `https://gridi-ai.github.io/quota/` 속성을
  확인한다. 공유 `github.io` 도메인 전체의 DNS 소유권을 요구하지 않는다.
- 소유권 확인 뒤 `/quota/sitemap.xml` 제출과 두 canonical URL Inspection을 수행한다.
- Bing Webmaster Tools에서 소유권·sitemap을 확인한다. IndexNow는 필요성이
  생기고 소유권을 증명할 수 있을 때만 사용한다.
- 게시 후 origin-root robots, HTTP 상태·canonical·두 언어 링크·다운로드를 재검증한다.
- 정확한 게시일과 검증한 canonical을 남긴다. 현재 사이트가 검색에 색인됐다고
  이 문서나 구현만으로 판단하지 않는다.

## 4주 측정 계획

| 시점 | 확인할 것 | 판단 |
| --- | --- | --- |
| 게시 직후 | HTTPS/200, 크롤링 허용, canonical, sitemap 접수·URL 검사 | 기술 실패 먼저 수정 |
| 1주 | 두 언어 색인 상태, 노출 질의, 설치 문의 | 잘못된 비용 계산 질의 유입과 실제 quota 수요 구분 |
| 2주 | Search Console/Bing 실제 노출·클릭·CTR, 유용한 질문 | 순위보다 적합한 방문과 첫 연결 성공을 확인 |
| 4주 | 다운로드 후 첫 연결·14일 유지·선택 후원 | 기존 20명/14일 실험과 연결, 시간·지원 비용 평가 |

AI 인용은 날짜·제품·언어·질문·인용 URL을 같은 조건으로 수동 기록한다.
답변에 안 나오는 것과 크롤링 실패는 다르며 검색 개인화·변동성도 기록한다.
Search Console의 Web 합계를 AI 인용 전용 지표라고 부르지 않는다.
GitHub 다운로드 수는 중복을 포함하고 고유 사용자나 설치 완료를 뜻하지 않는다.
GitHub Pages에 서버 로그 분석이 있다고 가정하지 않는다. 웹·앱 telemetry나 쿠키는
추가하지 않았으므로 자동 유입→설치 attribution은 현재 측정하지 못한다.

## 로컬 검증 기록

- 실제 Chrome에 Playwright로 CDP 연결 후 Lighthouse Node API로 측정했다.
  영어·한국어 각각 mobile/desktop 3회, 총 12회에서 네 범주의 중앙값은 모두
  Performance/Accessibility/Best Practices/SEO **100/100/100/100**이었다.
  배포 URL이나 검색 순위의 점수가 아니라 로컬 production artifact 측정값이다.
- 두 언어 × 390px(DPR 3)/1440px/1920px × light/dark의 12조합에서 가로
  overflow가 없었다. 상단·펼친 FAQ·문서 끝과 모바일 보완 캡처를 저장했다.
- 다운로드 버튼·FAQ의 실제 포인터 hover/pressed와 Space 키 펼침을 두 테마에서
  확인했다. standalone 링크는 가로·세로 44px 이상이며 한국어 질문 끝이 홀로
  남지 않도록 줄였다. 200% 확대 대응은 1440×900 물리 화면을 720×450 CSS px·DPR 2로
  재현해 전체 문서 reflow를 확인했다. 브라우저 toolbar 확대 단축키를 실행한 결과나
  viewport가 달라지지 않는 CSS `zoom:2` 결과라고 부르지 않는다.
- metadata/canonical/hreflang/schema/버전·가격/이미지·로컬 링크·anchor/sitemap 및
  공개 허용 파일 6개를 검사한다. 다른 파일이 섞인 artifact는 배포 전에 거부한다.
- ShellCheck·shell 문법과 workflow YAML 구문 검사를 수행했다.
  이 환경에는 HTML/CSS/Python/YAML language server가 없어 LSP 진단은 실행하지
  못했다. 브라우저·실제 검사 도구의 결과를 그 대신 LSP 결과라고 부르지 않는다.
- 최종 독립 검토 두 건이 기능·접근성과 시각·한국어 항목에서 모두 PASS했다.
  각 검토자가 최종 PNG 60개를 모두 열어 확인했다. 이 판정도 로컬 사이트에
  한정되며 배포 승인·색인·실제 검색 성과를 대신하지 않는다.
- Swift 앱 소스·인증·계정 저장·설치 버전은 변경하지 않았으므로 이 작업에서
  새 앱 바이너리를 만들거나 앱 테스트를 다시 실행하지 않았다.
