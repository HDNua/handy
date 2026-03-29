# UART 레지스터 세팅 체험 전략 문서

작성일: 2026-03-29

---

## 1. 이 문서의 위치

이 문서는 `lv1_1_uart_tx` 본선 실습에서 분리된
companion track `lv1b_uart_registers`의 전략 문서다.

분리 이유:

- `lv1_1_uart_tx`는 UART 프로토콜과 UVM-inspired 검증 구조에 집중
- register/MMIO/SW interaction은 별도 학습축으로 관리
- 본선 커리큘럼이 옆길로 새지 않도록 구조를 분리

즉, 이 문서는 `lv1_1_uart_tx`의 부록이 아니라
`lv1b_uart_registers`의 시작 문서로 취급한다.

---

## 2. 목적

현재 `lv1_1_uart_tx` 실습은 CPU가 `iTxData`, `iTxValid`, `oTxReady` 신호를 직접 다루는 구조다.
즉, RTL 블록 입장에서는 송신기 동작을 잘 보여주지만,
실제 임베디드 개발에서 흔히 겪는 `SW가 UART 레지스터를 설정하고 사용하는 경험`은 아직 담겨 있지 않다.

이번 전략 문서의 목표는 다음과 같다.

- 기존 UART TX 코어를 최대한 유지한다.
- 바깥에 `register wrapper`를 추가한다.
- Testbench에서 `CPU task`가 레지스터 write/read를 수행하게 만든다.
- 사용자가 `baud 설정 -> enable -> status polling -> TXDATA write` 흐름을 눈으로 체험할 수 있게 한다.

---

## 3. 현재 상태 요약

- UART TX 코어: `../lv1_1_uart_tx/rtl/UART_Tx.sv`
- 현재 TB 기준점: `../lv1_1_uart_tx/tb/top/tb_top.sv`
- CPU 역할: testbench driver task가 직접 `tx_data`, `tx_valid`를 구동
- baud 설정: 파라미터 `BAUD_RATE`
- 검증: monitor가 직렬 출력을 복원하고 scoreboard가 비교

현재 방식의 한계:

- SW가 레지스터를 쓰는 감각이 없다.
- `baud`, `enable`, `status` 같은 레지스터 개념이 없다.
- 실제 MCU/SoC peripheral 사용 느낌이 약하다.

---

## 4. 추천 아키텍처

```text
CPU read/write task
        |
        v
[ UART register wrapper ]
        |
        v
[ UART_Tx core ]
        |
        v
     tx_serial
```

권장 방향은 `기존 UART_Tx 코어는 그대로 두고`, 그 바깥에 레지스터 래퍼를 추가하는 것이다.

---

## 5. 최소 레지스터 맵

```text
0x00  CTRL
0x04  BAUD_DIV
0x08  STATUS
0x0C  TXDATA
```

핵심 체험 포인트:

- `CTRL.TX_EN`
- `STATUS.TX_READY`
- `TXDATA write`
- 필요 시 `BAUD_DIV` 로그 확인

---

## 6. 구현 순서

1. `UART_Tx_RegWrapper.sv` 추가
2. TB에 `cpu_write()`, `cpu_read()` task 추가
3. `'H'` 1바이트 smoke test
4. `"Hello"` 연속 전송
5. 필요하면 `BAUD_DIV`를 실제 timing에 반영

---

## 7. 완료 기준

- SW 스타일 `cpu_write/cpu_read` task 존재
- UART wrapper가 `CTRL / STATUS / TXDATA`를 제공
- `TXDATA write`가 실제 UART 전송으로 이어짐
- monitor/scoreboard 기준 PASS
- 로그에서 레지스터 write/read 흐름 확인 가능
