# Level 1.2 — UART RX 계획 메모

작성일: 2026-03-29

---

## 1. 목적

`Level 1.1`에서 만든 `UART_Tx`에 대응되는 수신기 `UART_Rx`를 직접 구현한다.

이번 단계의 목표는 다음과 같다.

- 직렬 비트스트림에서 start bit를 감지한다.
- 1.5 baud 뒤 첫 data bit를 샘플링한다.
- 8비트를 다시 1바이트로 복원한다.
- stop bit를 확인하고 필요하면 framing error를 낸다.

즉, `tb monitor가 흉내 내던 RX 역할`을 실제 RTL DUT로 옮겨오는 단계다.

---

## 2. 추천 인터페이스

초기 버전은 단순하게 가는 것이 좋다.

```text
input  iClk
input  iRsn
input  iRxSerial
output oRxValid
output [7:0] oRxData
output oFramingError
```

필요하면 이후에 `oRxReady` 또는 FIFO 구조로 확장할 수 있다.

---

## 3. 핵심 학습 포인트

- idle high 상태 관찰
- start bit falling detect
- 1.5 bit wait 후 첫 샘플
- 1 bit 간격으로 총 8비트 수집
- stop bit 확인
- LSB first 복원

---

## 4. 검증 방향

1차 smoke test:

- testbench가 serial line을 직접 흔들어 `'H'` 한 프레임 입력
- `UART_Rx`가 `oRxData=8'h48`, `oRxValid=1` 출력

2차 확장:

- `"Hello"` 연속 프레임 수신
- stop bit 오류 입력 시 framing error 확인

---

## 5. 다음 연결점

이 단계가 끝나면 `Level 1.3 UART Integration`에서
`UART_Tx -> UART_Rx` loopback 검증으로 자연스럽게 이어진다.
