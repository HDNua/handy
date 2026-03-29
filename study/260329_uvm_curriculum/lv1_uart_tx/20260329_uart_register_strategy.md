# UART 레지스터 세팅 체험 전략 문서

작성일: 2026-03-29

---

## 1. 목적

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

## 2. 현재 상태 요약

현재 구현은 다음과 같다.

- DUT: `rtl/UART_Tx.sv`
- TB: `tb/top/tb_top.sv`
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

## 3. 이번 단계에서 얻고 싶은 체험

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

## 4. 구현 방향

### 4.1 권장 방향

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

### 4.2 비권장 방향

`UART_Tx.sv` 내부에 레지스터 개념까지 한 번에 우겨 넣는 방식은 이번 단계에서 비권장이다.

이유:

- 코어 역할과 제어 인터페이스 역할이 섞임
- 학습 포인트가 흐려짐
- 디버깅이 어려워짐

---

## 5. 제안 아키텍처

### 5.1 코어

기존 `UART_Tx.sv`는 그대로 유지한다.

역할:

- `iTxData`, `iTxValid`, `oTxReady` 인터페이스 유지
- 실제 직렬화(FSM, baud timing, shift register) 담당

### 5.2 래퍼

새 모듈 예시 이름:

- `UART_Tx_RegWrapper.sv`
- 또는 `UART_Tx_MMIO.sv`

역할:

- CPU 스타일 read/write 인터페이스 제공
- 내부 레지스터 보관
- `TXDATA write`를 `iTxValid pulse`로 변환
- `STATUS`와 `READY/BUSY`를 소프트웨어가 읽을 수 있게 제공

### 5.3 TB CPU task

Testbench에 `cpu_write()`, `cpu_read()` task를 만든다.

역할:

- MMIO처럼 주소/데이터를 써봄
- SW 시퀀스를 눈으로 확인
- 나중에 실제 펌웨어 흐름 설명 자료로 사용 가능

---

## 6. 레지스터 맵 제안

이번 단계는 교육 목적이므로 단순한 맵을 추천한다.

### 6.1 최소 레지스터 맵

```text
0x00  CTRL
0x04  BAUD_DIV
0x08  STATUS
0x0C  TXDATA
```

### 6.2 각 레지스터 의미

#### CTRL (0x00)

- bit[0] : `TX_EN`
- bit[1] : `SOFT_RST` (선택)

기본 역할:

- UART TX 사용 여부 제어
- 필요하면 소프트 리셋 실험 가능

#### BAUD_DIV (0x04)

- UART 비트 길이를 결정하는 분주값
- 예: 50MHz 기준 `434`

주의:

- 현재 코어는 `BAUD_RATE` 파라미터 기반이라,
  wrapper 단계에서 `BAUD_DIV`를 직접 코어에 연결하려면 코어 수정이 필요함
- 이번 1차 전략에서는 `읽고/쓰는 경험` 우선인지, `실제 분주 반영`까지 포함할지 결정해야 함

권장:

- 1차: `BAUD_DIV` 레지스터를 만들고 로그/가시성 확보
- 2차: 코어를 `CLKS_PER_BIT input` 또는 유사 구조로 바꿔 실제 동작 반영

#### STATUS (0x08)

- bit[0] : `TX_READY`
- bit[1] : `TX_BUSY`

역할:

- 소프트웨어가 `polling`으로 전송 가능 여부 확인

#### TXDATA (0x0C)

- write-only 8bit data
- write 순간 내부에서 `iTxValid` pulse 생성

역할:

- SW가 “문자 1개 전송”하는 핵심 체험 포인트

---

## 7. 단계별 구현 권장안

### Phase 1. Wrapper만 추가하고 baud는 고정 유지

목표:

- SW가 레지스터를 write/read하는 체험 확보
- 기존 코어 변경 최소화

구현:

- `CTRL`, `STATUS`, `TXDATA` 추가
- `BAUD_DIV`는 일단 저장만 하고 실제 timing에는 미반영 가능
- `TXDATA write` 시 `tx_ready && tx_en` 조건에서 코어로 전달

장점:

- 구현이 빠름
- 현재 smoke test 구조를 크게 안 깨뜨림

단점:

- “BAUD_DIV를 SW가 진짜 바꿨다”는 하드웨어 감각은 반쪽짜리

### Phase 2. BAUD_DIV를 실제 코어 timing에 반영

목표:

- 레지스터 설정이 실제 전송 속도에 영향을 주도록 확장

구현 후보:

- `UART_Tx.sv`를 `BAUD_RATE` 대신 `iClksPerBit` 입력 기반으로 리팩터링
- 또는 wrapper 내부에 baud tick generator를 두고 코어 FSM을 분리

장점:

- 교육 효과가 훨씬 큼
- “SW 설정 -> HW 동작 변화”가 직접 연결됨

단점:

- 기존 코어 구조 변경 필요
- Level 1 범위를 조금 넘길 수 있음

### Phase 3. CPU 시퀀스/로그 정리

목표:

- 사람이 읽기 쉬운 사용 흐름 확보

예:

```text
[CPU] write CTRL      = 0x0000_0001
[CPU] write BAUD_DIV  = 434
[CPU] read  STATUS    -> TX_READY=1
[CPU] write TXDATA    = 0x48 ('H')
```

장점:

- 실제 펌웨어 드라이버 감각을 많이 줌
- 문서/면접 설명 자료로 좋음

---

## 8. Testbench 변경 전략

### 8.1 현재 구조 재사용

현재 monitor와 scoreboard는 그대로 재사용한다.

즉, 바뀌는 부분은 송신 입력 경로뿐이다.

기존:

```text
drv_q -> driver -> tx_data/tx_valid
```

변경 후:

```text
cpu_sequence -> cpu_write/cpu_read task -> reg wrapper -> UART_Tx
```

### 8.2 추천 test 시나리오

가장 먼저 구현할 smoke test:

1. reset release
2. `CTRL.TX_EN = 1`
3. `BAUD_DIV = 434` write
4. `STATUS.TX_READY` polling
5. `TXDATA = 'H'` write
6. monitor가 `'H'` 복원
7. scoreboard PASS

그 다음 확장:

- `"Hello"` 연속 전송
- busy 중 write 시도 시 무시/에러 처리 확인
- TX enable off 상태 write 동작 정의 확인

---

## 9. 권장 인터페이스 복잡도

이번 레벨에서는 APB 같은 표준 bus를 바로 붙이지 않는 것을 권장한다.

이유:

- 지금 목표는 `UART peripheral register` 감각 체험
- APB 자체 학습이 본론을 흐릴 수 있음
- 주소/쓰기/읽기만 있는 단순 MMIO 스타일이면 충분함

즉, 이번 전략의 핵심은:

`표준 bus 학습`이 아니라 `레지스터 기반 peripheral 사용 경험`이다.

---

## 10. 예상 파일 추가/변경 범위

### 추가 후보

- `rtl/UART_Tx_RegWrapper.sv`
- `tb/top/tb_top_reg.sv` 또는 기존 `tb_top.sv` 확장
- `20260329_uart_register_strategy.md` (현재 문서)

### 수정 후보

- `sim/run.sh`
- `20260329_lv1_retrospective.md`
- `uart_tx_demo.html` (선택: register 설정 시각화 추가)

---

## 11. 완료 기준

이번 전략의 1차 완료 기준은 아래와 같다.

- SW 스타일 `cpu_write/cpu_read` task가 존재한다.
- UART wrapper가 `CTRL / STATUS / TXDATA`를 제공한다.
- `TXDATA write`가 실제 UART 전송으로 이어진다.
- monitor/scoreboard가 기존과 동일하게 PASS를 낸다.
- 시뮬레이션 로그에서 레지스터 write/read 흐름이 보인다.

2차 완료 기준:

- `BAUD_DIV` 설정이 실제 전송 timing 변화로 반영된다.

---

## 12. 추천 구현 순서

가장 추천하는 진행 순서는 다음과 같다.

1. 기존 `UART_Tx.sv`는 유지
2. `UART_Tx_RegWrapper.sv` 추가
3. TB에 `cpu_write/cpu_read` task 추가
4. `'H'` 1바이트 smoke test 먼저 통과
5. `"Hello"` 확장
6. 필요하면 `BAUD_DIV` 실반영 리팩터링

이 순서의 장점은:

- 빠르게 첫 성공을 볼 수 있고
- 기존 검증 자산을 버리지 않으며
- 필요할 때만 complexity를 추가할 수 있다는 점이다.

---

## 13. 최종 권고

이번 단계의 최적 전략은 아래 한 문장으로 요약된다.

`기존 UART_Tx 코어는 그대로 두고, 바깥에 register wrapper와 CPU read/write task를 얹어서 소프트웨어 레지스터 설정 경험을 먼저 확보한다.`

즉, 지금 당장 가장 좋은 다음 수순은:

- UART core 재작성
가 아니라
- UART peripheral wrapper 추가

이다.
