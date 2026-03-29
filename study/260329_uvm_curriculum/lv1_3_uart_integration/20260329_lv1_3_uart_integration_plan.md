# Level 1.3 — UART Integration 계획 메모

작성일: 2026-03-29

---

## 1. 목적

`Level 1.1 UART_Tx`와 `Level 1.2 UART_Rx`를 연결해
end-to-end UART loopback 검증을 수행한다.

이번 단계의 목표는 다음과 같다.

- TX가 만든 serial bitstream을 RX가 제대로 복원하는지 확인
- DUT끼리만 보는 것이 아니라 scoreboard로 end-to-end 확인
- monitor와 실제 RX DUT의 역할 차이를 분명히 유지

---

## 2. 추천 구조

```text
[SEQ/CPU stimulus] -> [UART_Tx] -> serial line -> [UART_Rx] -> scoreboard
```

보조 검증 블록:

- monitor: serial line 관찰용 checker
- scoreboard: expected byte vs RX output 비교

즉, `UART_Rx`가 생겨도 monitor는 제거하지 않는 것이 좋다.

---

## 3. 핵심 학습 포인트

- DUT to DUT 연결
- serial line 공유
- end-to-end smoke test 설계
- monitor 기반 observer와 RTL RX DUT의 역할 구분

---

## 4. 추천 smoke test

1차:

- `'H'` 1바이트 loopback

2차:

- `"Hello"` 5바이트 loopback

3차 확장:

- TX/RX baud mismatch 시나리오
- framing error injection

---

## 5. 완료 기준

- `UART_Tx`와 `UART_Rx`가 하나의 top에서 연결된다.
- loopback 결과가 scoreboard 기준 PASS다.
- test log에서 end-to-end 흐름이 읽힌다.
- monitor와 RX DUT의 역할을 문서로도 구분해 설명할 수 있다.
