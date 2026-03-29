# UART TX Testbench 구조 학습 정리

작성일: 2026-03-29

---

## 1. Testbench 단계별 구조

`lv1_1_uart_tx` 는 동일한 DUT(`UART_Tx.sv`)를 대상으로 testbench 구조를 단계적으로 발전시킨다.

```
1_pure          — initial 하나, 순차, inline 수신
2_task          — task 분리, 순차 호출
3_fork          — fork/join 병렬 실행
4_uvm_inspired  — queue + scoreboard 분리 (UVM-inspired)
9_real_uvm      — 진짜 UVM 라이브러리 (예약)
```

각 단계는 이전 단계의 한계를 느끼고 다음 단계의 필요성을 이해하기 위한 구조다.

---

## 2. UART 비동기 통신과 fork 의 관계

UART 는 서로 다른 장치 간 비동기 직렬 통신이다.
TX 장치와 RX 장치는 물리적으로 동시에 동작한다.
TX 가 비트를 쏘는 동안 RX 는 그 선을 듣고 있어야 한다.

testbench 에서 이를 모델링하려면 driver 와 monitor 가 동시에 실행되어야 한다.
순차 실행으로는 driver 가 블로킹되는 동안 monitor 가 동작할 수 없다.

`fork` 는 단순한 편의 기능이 아니라,
"동시에 동작하는 두 장치" 를 시뮬레이션하기 위한 필수 구조다.

---

## 3. fork/join 동작 방식

`fork...join` 안의 `begin...end` 블록은 각각 독립 스레드로 동시에 시작한다.

```systemverilog
fork
    begin // 스레드 1
        foreach (payload[i]) send_byte(payload[i]);
    end
    begin // 스레드 2
        foreach (payload[i]) recv_and_check(payload[i]);
    end
join
```

- 스레드 1과 스레드 2는 병렬로 실행된다.
- 스레드 내부의 task 호출은 순차 블로킹이다.
- `join` 은 모든 스레드가 끝날 때까지 대기한다.

### join 종류

| | |
|---|---|
| `join` | 모든 스레드가 끝날 때까지 대기 |
| `join_any` | 하나라도 끝나면 진행 |
| `join_none` | 기다리지 않고 바로 진행 |

### timeout watchdog 패턴

스레드가 무한 대기할 가능성이 있을 때는 watchdog 스레드를 추가한다:

```systemverilog
fork
    begin ... end   // driver
    begin ... end   // monitor
    begin           // watchdog
        #(timeout_limit);
        $display("TIMEOUT");
        $finish;
    end
join_any
```

---

## 4. task 호출은 블로킹

SystemVerilog 에서 task 호출은 기본적으로 블로킹이다.
`endtask` 에 도달해야 다음 줄로 넘어간다.

```systemverilog
foreach (payload[i]) send_byte(payload[i]);
// send_byte(payload[0]) 완료 → send_byte(payload[1]) 시작
```

이는 실제 UART 동작과도 맞다.
TX 는 한 번에 한 바이트씩 직렬로 보내야 하므로,
이전 바이트 완료 후 다음 바이트를 보내는 순차 구조가 올바른 모델링이다.

비블로킹으로 쓰려면 `fork...join_none` 안에 넣어야 한다.

---

## 5. ready/valid 인터페이스 위치

UART 시스템에서 ready/valid 는 직렬 선이 아니라 병렬 인터페이스 쪽에 있다.

```
CPU ──[iTxValid / oTxReady]──▶ UART_Tx ──[TxSerial]──▶ UART_Rx ──[oRxValid / oRxData]──▶ Peri
```

- `oTxReady` : UART_Tx 가 CPU 에게 "나 지금 전송 중이니 새 데이터 주지 마" 를 알려주는 신호
- 직렬 선(`TxSerial`) 구간에는 ready/valid 가 없다. TX 가 쏘면 RX 는 그냥 듣는다.

따라서 `send_byte` 는 CPU 가 UART_Tx 에 데이터를 내리는 동작을 모사한 것이고,
`recv_and_check` 는 UART_Rx 가 직렬 비트스트림을 수신해서 바이트를 복원하는 동작을 모사한 것이다.

---

## 6. while + @(posedge clk) vs @(negedge)

### while + @(posedge clk)

```systemverilog
while (!tx_ready) @(posedge clk);
```

클럭 동기 신호를 폴링할 때 적합하다.
`tx_ready` 는 RTL 의 `always_ff` 가 클럭 엣지에서 업데이트하는 동기 신호이므로,
클럭 엣지마다 체크하는 것이 정확하다.

SW 의 busy-wait 처럼 보이지만, `@(posedge clk)` 가 시뮬레이션 시간을 진행시키는
yield 포인트이므로 클럭마다 한 번씩 체크하고 대기한다.

### @(negedge tx_serial)

```systemverilog
@(negedge tx_serial);
```

UART start bit 감지에 적합하다.
UART 수신측은 "선이 LOW 로 떨어지는 순간" 을 포착하는 방식으로 동작한다.
이것이 비동기 통신의 핵심이며, `@(negedge)` 가 그 개념을 그대로 표현한다.

---

## 7. 1.5 baud 샘플링

start bit 하강 엣지 감지 후 D0 를 샘플링하려면 D0 의 중앙에서 읽어야 한다.

```
      ↓ negedge                ↓ 여기서 샘플
 ___  |          ___________
    |____________|           |___
    [   START   ][     D0     ]
    |<-- 1 baud->|<- 0.5 baud->|
```

- start bit 1개 통과: `CLKS_PER_BIT`
- D0 중앙까지 절반: `CLKS_PER_BIT / 2`
- 합계: `CLKS_PER_BIT + CLKS_PER_BIT / 2` (1.5 baud)

이후 D1~D7 은 1 baud(`CLKS_PER_BIT`) 간격으로 순차 샘플링한다.
LSB first 로 `captured[0]` 부터 채우면 바이트가 자동으로 복원된다.
