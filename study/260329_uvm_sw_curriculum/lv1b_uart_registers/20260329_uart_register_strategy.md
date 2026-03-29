# UART 레지스터 세팅 체험 전략 문서

작성일: 2026-03-29

---

## 1. 이 문서의 위치

이 문서는 `lv1_uart_tx` 본선 실습에서 분리된
companion track `lv1b_uart_registers`의 전략 문서다.

분리 이유:

- `lv1_uart_tx`는 UART 프로토콜과 UVM-inspired 검증 구조에 집중
- register/MMIO/SW interaction은 별도 학습축으로 관리
- 본선 커리큘럼이 옆길로 새지 않도록 구조를 분리

즉, 이 문서는 `lv1_uart_tx`의 부록이 아니라
`lv1b_uart_registers`의 시작 문서로 취급한다.

---

## 2. 목적

현재 `lv1_uart_tx` 실습은 CPU가 `iTxData`, `iTxValid`, `oTxReady` 신호를 직접 다루는 구조다.
즉, RTL 블록 입장에서는 송신기 동작을 잘 보여주지만,
실제 임베디드 개발에서 흔히 겪는 `SW가 UART 레지스터를 설정하고 사용하는 경험`은 아직 담겨 있지 않다.

이번 전략 문서의 목표는 다음과 같다.

- 기존 UART TX 코어를 최대한 유지한다.
- 바깥에 `register wrapper`를 추가한다.
- Testbench에서 `CPU task`가 레지스터 write/read를 수행하게 만든다.
- 사용자가 `baud 설정 -> enable -> status polling -> TXDATA write` 흐름을 눈으로 체험할 수 있게 한다.

즉, 이 작업은 UART 코어 자체를 새로 만드는 것이 아니라,
`직접 신호 구동형 UART TX`를 `SW 친화적 register-mapped UART`로 한 단계 확장하는 것이다.

---

## 3. 현재 상태 요약

현재 구현은 다음과 같다.

- UART TX 코어: `../lv1_uart_tx/rtl/UART_Tx.sv`
- 현재 TB 기준점: `../lv1_uart_tx/tb/top/tb_top.sv`
- CPU 역할: testbench driver task가 직접 `tx_data`, `tx_valid`를 구동
- baud 설정: 파라미터 `BAUD_RATE`
- 검증: monitor가 직렬 출력을 복원하고 scoreboard가 비교

현재 방식의 장점:

- UART TX FSM을 직접 이해하기 쉽다.
- start/data/stop 흐름에 집중할 수 있다.
- smoke test가 단순하고 재현성이 좋다.

현재 방식의 한계:

- SW가 레지스터를 쓰는 감각이 없다.
- `baud`, `enable`, `status` 같은 레지스터 개념이 없다.
- 실제 MCU/SoC peripheral 사용 느낌이 약하다.

---

## 4. 이번 단계에서 얻고 싶은 체험

최종적으로는 사용자가 아래 흐름을 경험할 수 있어야 한다.

```text
CPU(SW)
  -> BAUD_DIV write
  -> CTRL write (TX enable)
  -> STATUS polling (TX ready 확인)
  -> TXDATA write ('H')
  -> UART TX가 직렬 전송
  -> monitor/scoreboard가 수신 결과 확인
```

즉, 단순히 “바이트를 전송했다”가 아니라,
`왜 UART를 레지스터로 제어한다고 말하는지`를 실습 안에서 확인하는 것이 핵심이다.

---

## 5. 구현 방향

### 5.1 권장 방향

권장 방향은 `기존 UART_Tx 코어는 그대로 두고`, 그 바깥에 레지스터 래퍼를 추가하는 것이다.

추천 구조:

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

이 방향의 장점:

- 기존 `UART_Tx.sv` 검증 자산을 최대한 재사용 가능
- UART 코어 로직과 레지스터 인터페이스 로직을 분리 가능
- 실무적인 구조와 더 가까워짐
- 나중에 APB/AHB-lite 같은 bus wrapper로 확장하기 쉬움

### 5.2 비권장 방향

`UART_Tx.sv` 내부에 레지스터 개념까지 한 번에 우겨 넣는 방식은 이번 단계에서 비권장이다.

이유:

- 코어 역할과 제어 인터페이스 역할이 섞임
- 학습 포인트가 흐려짐
- 디버깅이 어려워짐

---

## 6. 제안 아키텍처

### 6.1 코어

기존 `UART_Tx.sv`는 그대로 유지한다.

역할:

- `iTxData`, `iTxValid`, `oTxReady` 인터페이스 유지
- 실제 직렬화(FSM, baud timing, shift register) 담당

### 6.2 래퍼

새 모듈 예시 이름:

- `UART_Tx_RegWrapper.sv`
- 또는 `UART_Tx_MMIO.sv`

역할:

- CPU 스타일 read/write 인터페이스 제공
- 내부 레지스터 보관
- `TXDATA write`를 `iTxValid pulse`로 변환
- `STATUS`와 `READY/BUSY`를 소프트웨어가 읽을 수 있게 제공

### 6.3 TB CPU task

Testbench에 `cpu_write()`, `cpu_read()` task를 만든다.

역할:

- MMIO처럼 주소/데이터를 써봄
- SW 시퀀스를 눈으로 확인
- 나중에 실제 펌웨어 흐름 설명 자료로 사용 가능

---

## 7. 레지스터 맵 제안

이번 단계는 교육 목적이므로 단순한 맵을 추천한다.

### 7.1 최소 레지스터 맵

```text
0x00  CTRL
0x04  BAUD_DIV
0x08  STATUS
0x0C  TXDATA
```

### 7.2 각 레지스터 의미

#### CTRL (0x00)

- bit[0] : `TX_EN`
- bit[1] : `SOFT_RST` (선택)

#### BAUD_DIV (0x04)

- UART 비트 길이를 결정하는 분주값
- 예: 50MHz 기준 `434`

권장:

- 1차: `BAUD_DIV` 레지스터를 만들고 로그/가시성 확보
- 2차: 코어를 `CLKS_PER_BIT input` 또는 유사 구조로 바꿔 실제 동작 반영

#### STATUS (0x08)

- bit[0] : `TX_READY`
- bit[1] : `TX_BUSY`

#### TXDATA (0x0C)

- write-only 8bit data
- write 순간 내부에서 `iTxValid` pulse 생성

---

## 8. 단계별 구현 권장안

### Phase 1. Wrapper만 추가하고 baud는 고정 유지

- `CTRL`, `STATUS`, `TXDATA` 추가
- `BAUD_DIV`는 저장만 하고 실제 timing에는 미반영 가능
- `TXDATA write` 시 `tx_ready && tx_en` 조건에서 코어로 전달

### Phase 2. BAUD_DIV를 실제 코어 timing에 반영

- `UART_Tx.sv`를 `BAUD_RATE` 대신 `iClksPerBit` 입력 기반으로 리팩터링
- 또는 wrapper 내부에 baud tick generator를 두고 코어 FSM을 분리

### Phase 3. CPU 시퀀스/로그 정리

예:

```text
[CPU] write CTRL      = 0x0000_0001
[CPU] write BAUD_DIV  = 434
[CPU] read  STATUS    -> TX_READY=1
[CPU] write TXDATA    = 0x48 ('H')
```

---

## 9. Testbench 변경 전략

현재 monitor와 scoreboard는 그대로 재사용한다.

기존:

```text
drv_q -> driver -> tx_data/tx_valid
```

변경 후:

```text
cpu_sequence -> cpu_write/cpu_read task -> reg wrapper -> UART_Tx
```

추천 smoke test:

1. reset release
2. `CTRL.TX_EN = 1`
3. `BAUD_DIV = 434` write
4. `STATUS.TX_READY` polling
5. `TXDATA = 'H'` write
6. monitor가 `'H'` 복원
7. scoreboard PASS

---

## 10. 예상 파일 범위

추가 후보:

- `rtl/UART_Tx_RegWrapper.sv`
- `tb/top/tb_top_reg.sv` 또는 기존 `tb_top.sv` 확장
- `sim/run.sh`

참고 기준점:

- `../lv1_uart_tx/rtl/UART_Tx.sv`
- `../lv1_uart_tx/tb/top/tb_top.sv`

---

## 11. 완료 기준

1차 완료 기준:

- SW 스타일 `cpu_write/cpu_read` task 존재
- UART wrapper가 `CTRL / STATUS / TXDATA` 제공
- `TXDATA write`가 실제 UART 전송으로 이어짐
- monitor/scoreboard가 PASS
- 시뮬레이션 로그에서 레지스터 write/read 흐름 확인 가능

2차 완료 기준:

- `BAUD_DIV` 설정이 실제 전송 timing 변화로 반영됨

---

## 12. 최종 권고

이번 companion track의 최적 전략은 아래 한 문장으로 요약된다.

`기존 UART_Tx 코어는 그대로 두고, 바깥에 register wrapper와 CPU read/write task를 얹어서 소프트웨어 레지스터 설정 경험을 먼저 확보한다.`
