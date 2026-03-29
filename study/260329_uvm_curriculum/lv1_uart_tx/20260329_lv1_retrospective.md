# Level 1 — UART TX UVM 실습 회고

작성일: 2026-03-29

---

## 1. 무엇을 만들었나

**DUT**: `uart_tx.sv` — UART 송신기 (50MHz 클럭, 115200 baud)

```
FSM: IDLE → START → DATA(×8, LSB first) → STOP → IDLE
레지스터: tx_data[7:0], tx_valid(입력), tx_ready(출력), tx_serial(출력)
```

**TB 구조**: UVM-inspired, iverilog 호환, 단일 `tb_top.sv`

```
[SEQ]  drv_q에 payload 적재
[DRV]  drv_q → tx_data/tx_valid 구동
[DUT]  UART TX FSM 직렬 변환
[MON]  tx_serial 비트스트림 샘플링 → 바이트 복원 → mon_q push + event trigger
[SB]   @(mon_data_ready) → mon_q pop → exp_q와 비교
```

**결과**: "Hello" (0x48 0x65 0x6c 0x6c 0x6f) — PASS 5 / FAIL 0

---

## 2. UVM 구조와의 대응

| 이번 구현 | UVM 대응 | 역할 |
|---|---|---|
| drv_q (queue) | `uvm_tlm_fifo` / mailbox | sequence → driver 채널 |
| mon_data_ready (event) | analysis port | monitor → scoreboard 채널 |
| `uart_driver` task | `uvm_driver::run_phase` | DUT 인터페이스 구동 |
| `uart_monitor` task | `uvm_monitor::run_phase` | DUT 출력 관찰/복원 |
| `uart_scoreboard` task | `uvm_scoreboard::run_phase` | expected vs actual |
| fork-join | phase mechanism | 병렬 실행 |

클래스/팩토리/매크로 없이 구조의 본질은 동일하게 구현됨.

---

## 3. iverilog 13에서 부딪힌 제약들

### 3.1 `mailbox #(type)` 미지원
- **증상**: `mailbox doesn't name a type` compile error
- **원인**: iverilog는 IEEE 1800 built-in 클래스(`mailbox`, `semaphore`) 미지원
- **해결**: `logic [7:0] queue[$]` + `event`로 대체

### 3.2 `automatic` task 내 edge event 미지원
- **증상**: `vvp_fun_anyedge_aa: recv_object not implemented` — runtime abort
- **원인**: iverilog VVP 런타임이 automatic task 내 비클럭 신호 edge 감지 미구현
- **해결**: `automatic` 제거, `@(negedge signal)` → clk 폴링으로 대체

### 3.3 `wait(queue.size() > 0)` 재평가 미동작
- **증상**: 첫 바이트만 처리 후 scoreboard hang
- **원인**: iverilog에서 dynamic queue 크기 변화가 `wait` 조건 재평가를 트리거하지 않음
- **해결**: monitor가 push 후 `->mon_data_ready` trigger, scoreboard는 `@(mon_data_ready)` 대기

### 3.4 initial 블록 내 변수 초기화 미지원
- **증상**: `Static variable initialization requires explicit lifetime` warning → compile 실패
- **원인**: iverilog는 initial 블록 내 선언+초기화를 static context로 처리
- **해결**: 모듈 레벨에서 선언 후 initial 블록에서 값 대입

### 3.5 package 내 class with task 미지원
- **증상**: class constructor 내부에서 parse error
- **원인**: iverilog의 package + class + task 조합 지원 불완전
- **해결**: class 구조 포기, 단일 module 내 task로 flatten

---

## 4. Monitor 타이밍 설계

UART 프레임 샘플링 핵심 타이밍:

```
tx_serial: 1 1 1 [0][d0][d1][d2][d3][d4][d5][d6][d7][1] 1 1
                  ^start                                 ^stop
                  |
                  negedge 감지 (→ clk 폴링으로 대체)
                  |← 1.5 × CLKS_PER_BIT →| bit[0] 샘플
                                          |← 1 × CLKS_PER_BIT →| bit[1] 샘플
                                                                  ...
```

- start bit 시작 감지 후 **1.5 baud** 대기 → bit[0] 중앙 샘플
- 이후 **1 baud** 간격으로 bit[1]~bit[7] 순차 샘플
- stop bit 위치에서 tx_serial == 1 확인

---

## 5. 파일 구조

```
lv1_uart_tx/
├── rtl/
│   └── UART_Tx.sv                         DUT
├── tb/
│   ├── if/
│   │   └── uart_if.sv                     초기 class 기반 시도
│   ├── pkg/
│   │   └── uart_pkg.sv                    초기 class 기반 시도
│   ├── test/
│   │   └── smoke_test.sv                  초기 class 기반 시도
│   └── top/
│       └── tb_top.sv                      최종 iverilog 호환 TB
├── sim/
│   ├── run.sh                             빌드 + 실행 스크립트
│   └── uart_tx.vcd                        파형 (gitignore 처리)
├── uart_tx_demo.html                      개념 시각화 HTML
├── 20260329_lv1_retrospective.md          실습 회고
├── 20260329_uart_register_strategy.md     레지스터 체험 확장 전략
├── 20260329_uart_tx_demo_edit_notes.md    HTML 수정 내역
└── 20260329_uart_concept_notes.md         UART 개념 정리 메모
```

---

## 6. 다음 레벨에서 개선할 점

- monitor의 start bit 감지를 idle→low 전환으로 더 견고하게
- scoreboard에 타임아웃 추가 (무한 대기 방지)
- coverage 추가 (전송 바이트 값 범위)
- Level 2 (I2C Master)에서는 양방향 신호(SDA) + ACK/NACK 처리 추가
