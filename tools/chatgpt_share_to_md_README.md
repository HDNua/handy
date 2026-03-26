# ChatGPT Share Link to Markdown

`chatgpt.com/share/...` 링크를 브라우저에서 연 뒤, 대화 내용을 Markdown 파일로 저장하는 간단한 방법입니다.

## How to use

1. 공유 링크를 브라우저에서 엽니다.
2. 개발자 도구를 열고 Console 탭으로 이동합니다.
3. [`chatgpt_share_to_md_console.js`](/Users/handymac3/work/write/career/resume/tools/chatgpt_share_to_md_console.js) 파일 전체를 복사해서 Console에 붙여넣고 실행합니다.
4. 브라우저가 자동으로 `*.md` 파일을 다운로드합니다.

추가 동작:

- 같은 내용이 클립보드에도 복사되도록 시도합니다.
- 실행 결과는 `window.__chatgptShareExport` 에도 남겨둡니다.

## Output format

생성되는 Markdown은 아래 구조를 따릅니다.

```md
# Conversation title

Source: https://chatgpt.com/share/...
Exported: 2026-03-26T...

## User

...

## Assistant

...
```

## Notes

- OpenAI 공식 Shared Links FAQ에는 공유 링크 조회/관리와 데이터 내보내기 안내는 있지만, 공유 링크를 바로 Markdown으로 저장하는 내장 기능은 따로 보이지 않습니다.
- 페이지 DOM 구조가 바뀌면 선택자 조정이 필요할 수 있습니다.
- 코드 블록, 목록, 링크, 표는 최대한 Markdown으로 바꾸지만 100% 완벽한 원본 재현은 아닐 수 있습니다.
- Business/Enterprise 공유 링크는 권한이 없으면 페이지를 열 수 없으므로, 이 스크립트도 그 경우에는 동작하지 않습니다.
