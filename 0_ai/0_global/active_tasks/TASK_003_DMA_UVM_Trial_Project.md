# TASK_003_DMA_UVM_Trial_Project

## 상태
- Active

## 생성일
- 2026-03-29

## 목표
- RTL 설계 + UVM-inspired TB 작성을 단계별로 실습
- UVM 구조(seq_item / sequence / driver / monitor / scoreboard / coverage / agent / env / test)를 직접 손으로 구현하며 체득
- 면접 준비 문서(TASK_002)에서 도출된 UVM 학습 계획(block sim 전환) 실행
- iverilog 기반 무료 환경에서 각 레벨 smoke test 통과까지 완성
- 메인 검증 커리큘럼과 register/SW interaction 확장 주제를 분리해 학습 초점을 유지

## 배경
- 기존 경력에서 UVM 환경은 운영/회귀 위주였고, UVM 컴포넌트를 제로에서 설계한 경험이 약함
- 면접에서 "UVM TB 직접 짠 경험" 질문 대비용 실전 실습
- 참고 자료: `study/260326_122856/2_output_claude/02_dma.md`

---

## 커리큘럼 구조

### Main Track — Protocol + UVM-inspired Verification

핵심 목표:

- 프로토콜 이해
- monitor/scoreboard 중심 검증 구조 체득
- DUT 복잡도를 단계적으로 높이며 인터뷰용 스토리라인 확보

이 트랙이 `TASK_003`의 본선이다.

### Main Level 1 — UART Family

Level 1은 UART를 송신기/수신기/통합의 세 단계로 쪼개서 진행한다.
이렇게 하면 TX만 단독으로 이해하고 끝나는 것이 아니라,
RX 복원 로직과 end-to-end loopback까지 자연스럽게 이어갈 수 있다.

#### Level 1.1 — UART TX (직렬화 + 기본 검증 구조)

```
CPU cfg → [UART TX DUT] → serial bitstream → monitor 복원 → scoreboard
```

- **응용**: PC와 보드가 시리얼 케이블로 통신
- **핵심 학습**: seq_item / driver / monitor / scoreboard 기본 구조
- **RTL 복잡도**: baud rate divider + shift register FSM, 단순

#### Level 1.2 — UART RX (샘플링 + 바이트 복원)

```text
serial bitstream -> [UART RX DUT] -> rx_data/rx_valid -> scoreboard
```

- **응용**: 외부 장치가 보낸 UART 프레임을 수신하여 바이트 복원
- **핵심 학습**: start bit detect, 1.5 baud sample, stop bit/framing error
- **RTL 복잡도**: 단순~중간

#### Level 1.3 — UART Integration (TX -> RX loopback)

```text
[UART TX] -> serial line -> [UART RX] -> scoreboard
```

- **응용**: 송신기/수신기 end-to-end loopback
- **핵심 학습**: 두 DUT 연결, end-to-end 검증, monitor와 DUT 역할 구분
- **RTL 복잡도**: Level 1.1 + Level 1.2 재사용

### Main Level 2 — I2C Master (프로토콜 handshake + monitor 복잡도 UP)

```
CPU cfg → [I2C Master DUT] → SCL/SDA → monitor 프레임 복원 → slave stub ACK/NACK
```

- **응용**: 스마트폰 내부 온도/가속도/배터리 센서 읽기
- **핵심 학습**: 프로토콜 monitor (비트스트림 → 프레임 복원), ACK/NACK handshake
- **RTL 복잡도**: 중간 (clock stretching, start/stop 조건 포함)

### Main Level 3 — CRC32 Engine + DMA (스트리밍 + DMA 연동)

```
[MEM] → DMA → [CRC32 Engine] → result reg + IRQ → scoreboard
```

- **응용**: NAND flash / 이더넷 데이터 무결성 검사 (SK하이닉스 직접 연관)
- **핵심 학습**: DMA 스트리밍 연동, scoreboard = SW CRC vs HW CRC
- **RTL 복잡도**: LFSR 기반 CRC32, 중간

### Main Level 4 — DMA + UART TX (시스템 통합)

```
[MEM] → DMA → [UART TX] → serial out → monitor
```

- **응용**: 메모리에 있는 문자열을 DMA로 UART에 흘려 PC로 전송
- **핵심 학습**: 두 DUT + 두 agent 통합 env, 시스템 레벨 시나리오
- **RTL 복잡도**: Level 1 + Level 3 재활용

### Companion Track — Peripheral Register + SW Interaction

메인 검증 트랙과 별도로,
`SW가 레지스터를 설정하고 peripheral을 사용하는 감각`은 companion track으로 분리한다.

분리 이유:

- `lv1_1_uart_tx`의 초점을 UART 프로토콜 + monitor/scoreboard 구조에 유지
- MMIO/register map 학습이 본선 커리큘럼을 흐리지 않게 관리
- 필요할 때만 register wrapper, polling, TXDATA write 흐름을 별도 실습으로 확장

### Companion Level 1B — UART Registers + CPU-style Access

```text
CPU write/read -> [UART Register Wrapper] -> [UART TX] -> serial bitstream
```

- **응용**: MCU/SoC가 UART peripheral register를 설정하고 문자 전송
- **핵심 학습**: CTRL / STATUS / TXDATA / BAUD_DIV, polling, MMIO 감각
- **위치**: `study/260329_uvm_curriculum/lv1b_uart_registers/`

---

## 산출물 위치

```
study/260329_uvm_curriculum/
├── lv1_1_uart_tx/
│   ├── rtl/
│   │   └── UART_Tx.sv
│   ├── tb/
│   │   ├── pkg/uart_pkg.sv
│   │   ├── if/uart_if.sv
│   │   ├── top/tb_top.sv
│   │   └── test/smoke_test.sv
│   └── sim/run.sh
├── lv1_2_uart_rx/
│   ├── 20260329_lv1_2_uart_rx_plan.md
│   ├── rtl/
│   ├── tb/
│   └── sim/
├── lv1_3_uart_integration/
│   ├── 20260329_lv1_3_uart_integration_plan.md
│   ├── rtl/
│   ├── tb/
│   └── sim/
├── lv1b_uart_registers/
│   ├── 20260329_uart_register_strategy.md
│   ├── rtl/
│   ├── tb/
│   └── sim/
├── lv2_i2c_master/
│   ├── rtl/
│   │   └── i2c_master.sv
│   ├── tb/
│   │   ├── pkg/i2c_pkg.sv
│   │   ├── if/i2c_if.sv
│   │   ├── top/tb_top.sv
│   │   └── test/smoke_test.sv
│   └── sim/run.sh
├── lv3_crc32_dma/
│   ├── rtl/
│   │   ├── crc32_engine.sv
│   │   └── simple_dma.sv
│   ├── tb/
│   │   ├── pkg/crc_dma_pkg.sv
│   │   ├── if/
│   │   ├── top/tb_top.sv
│   │   └── test/smoke_test.sv
│   └── sim/run.sh
└── lv4_dma_uart/
    ├── rtl/                  ← lv1 + lv3 재활용
    ├── tb/
    └── sim/run.sh
```

---

## TB 클래스 구조 (UVM-inspired, iverilog 호환)

| 클래스 | 역할 |
|---|---|
| `xxx_seq_item` | transaction 데이터 정의 |
| `xxx_sequence` | seq_item 생성 → mailbox로 driver에 전달 |
| `xxx_driver` | seq_item 받아 DUT 인터페이스 구동 |
| `xxx_monitor` | DUT 출력 관찰 → scoreboard에 전달 |
| `xxx_scoreboard` | expected vs actual 비교 |
| `xxx_coverage` | covergroup 정의 |
| `xxx_agent` | driver + monitor 묶음 |
| `xxx_env` | agent + scoreboard + coverage 묶음 |
| `base_test` | env 생성 + run |
| `smoke_test` | 기본 동작 1개 PASS |

> Full UVM macro/factory 미사용 — SV OOP(class/mailbox/virtual interface)로 구조 직접 구현
> 이유: iverilog는 full UVM 라이브러리 미지원. 구조를 직접 짜야 UVM 내부 동작 이해에 더 효과적.

---

## iverilog 13 호환성 메모

실습 중 발견한 iverilog 제약 및 대안. 다음 레벨 작업 시 참고.

| 제약 | 증상 | 대안 |
|---|---|---|
| `mailbox #(type)` 미지원 | compile error: mailbox doesn't name a type | queue + event 조합으로 대체 |
| `automatic` task 내 edge event | runtime abort: vvp_fun_anyedge_aa | `automatic` 제거 |
| `@(negedge signal)` in task | 동일 runtime abort | clk 기반 폴링으로 대체 |
| `wait(queue.size() > 0)` | 조건 재평가 안 됨 → hang | `event` trigger + `@(event)` 대체 |
| initial 블록 내 변수 초기화 | static variable initialization warning | 모듈 레벨 선언으로 이동 |
| `package` 내 class with task | 미지원 | 단일 module 내 task로 flatten |

---

## 진행 현황

### Main Track

#### Level 1.1 — UART TX ✅ (2026-03-29 완료)
- [x] RTL 작성 (UART_Tx.sv) — IDLE→START→DATA→STOP FSM
- [x] tb_top.sv — clk/rst, DUT 연결, VCD dump
- [x] sequence (drv_q 적재)
- [x] driver (tx_data/tx_valid 구동)
- [x] monitor (tx_serial 비트스트림 → 바이트 복원)
- [x] scoreboard (event 기반 expected vs actual 비교)
- [x] smoke test PASS — "Hello" 5바이트 PASS 5 / FAIL 0
- [ ] coverage 추가 (선택)

#### Level 1.2 — UART RX
- [ ] RTL 작성 (`UART_Rx.sv`)
- [ ] start bit detect + 1.5 baud 샘플링 구현
- [ ] rx_data / rx_valid / framing error 정의
- [ ] smoke test PASS

#### Level 1.3 — UART Integration
- [ ] UART TX + UART RX loopback 연결
- [ ] end-to-end scoreboard 작성
- [ ] integration smoke test PASS

#### Level 2 — I2C Master
- [ ] RTL 작성
- [ ] tb_top (driver: START/ADDR/DATA/STOP, monitor: 프레임 복원)
- [ ] slave stub (ACK/NACK)
- [ ] smoke test PASS

#### Level 3 — CRC32 Engine + DMA
- [ ] RTL 작성 (crc32_engine.sv + simple_dma.sv)
- [ ] DMA 스트리밍 연동
- [ ] scoreboard (SW CRC vs HW CRC)
- [ ] smoke test PASS

#### Level 4 — DMA + UART TX
- [ ] 시스템 통합
- [ ] 두 DUT 연결
- [ ] 시스템 레벨 smoke test PASS

### Companion Track

#### Level 1B — UART Registers
- [x] 본선 커리큘럼과 분리 필요성 확인
- [x] companion track 방향 확정
- [x] 전략 문서 작성 (`lv1b_uart_registers/20260329_uart_register_strategy.md`)
- [ ] register wrapper RTL 작성
- [ ] CPU-style read/write task 작성
- [ ] TXDATA write 기반 smoke test PASS
