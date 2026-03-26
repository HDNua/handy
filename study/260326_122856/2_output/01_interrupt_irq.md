# 인터럽트(Interrupt)와 IRQ

> 대상: RTL 검증 엔지니어 (Verilog/SystemVerilog)

---

## 1. 인터럽트란

CPU가 현재 하던 일을 잠깐 멈추고, 더 급한 일을 먼저 처리하게 만드는 메커니즘.

### 폴링(Polling) vs 인터럽트

| 방식 | 동작 |
|---|---|
| 폴링 | CPU가 계속 "뭔가 생겼나?" 확인 |
| 인터럽트 | 이벤트가 생긴 쪽이 CPU를 불러세움 |

인터럽트의 장점:
- CPU 낭비 적음
- 이벤트에 즉각 반응 가능
- I/O 처리에 유리

### 처리 흐름

```
1. 이벤트 발생
2. 인터럽트 요청(IRQ) assert
3. CPU가 현재 상태 저장 (PC, 레지스터 등)
4. ISR(Interrupt Service Routine) 실행
5. ISR 종료 후 원래 코드로 복귀
```

### 인터럽트의 종류

- **하드웨어 인터럽트**: 키보드, 타이머, 네트워크 카드 등 외부 장치
- **소프트웨어 인터럽트**: 프로그램이 의도적으로 발생 (시스템콜 등)
- **예외(Exception/Trap)**: 0 나누기, 잘못된 메모리 접근 등 CPU 내부 원인

### 방향

- 보통은 **주변장치 → CPU** 방향
- CPU는 인터럽트를 **받는** 쪽

---

## 2. IRQ (Interrupt Request)

### 정의

IRQ = Interrupt Request. 주변장치가 CPU에게 "나 지금 처리 좀 해줘"라고 보내는 **요청 신호**.

- interrupt = 개념 전체
- IRQ = 인터럽트를 유발하는 요청 신호

### IRQ를 발생시키는 대표 peripheral

- Timer
- UART
- GPIO
- DMA
- Watchdog
- 네트워크 장치

### 기본 흐름 (UART 예시)

```
1. UART가 데이터 수신
2. UART가 IRQ assert
3. CPU가 IRQ 감지
4. CPU가 현재 상태 저장
5. UART ISR으로 점프
6. ISR이 데이터 레지스터 읽음
7. pending 비트 clear (W1C 등)
8. CPU 원래 코드 복귀
```

---

## 3. RTL 관점에서의 IRQ

### IRQ는 DUT의 output

블록 단품 검증 시, IRQ는 거의 항상 **DUT의 output signal**.

```systemverilog
module my_timer (
    input  logic clk,
    input  logic rst_n,
    input  logic timer_en,
    output logic irq       // ← 이게 IRQ output
);
```

### 인터럽트 레지스터 기본 구조

3종 세트: `pending`, `enable`, `mask`

| 비트 | 역할 |
|---|---|
| `intr_pending` | 이벤트 발생하면 set, SW가 clear할 때까지 유지 |
| `intr_enable` | 1이면 IRQ output 허용 |
| `mask` | (polarity는 문서마다 다름) 막는 비트 역할 |

```systemverilog
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        intr_pending <= 1'b0;
    else begin
        if (event_done)
            intr_pending <= 1'b1;
        else if (clr_intr)
            intr_pending <= 1'b0;
    end
end

assign irq = intr_pending & intr_enable;
```

#### 왜 pending 비트를 따로 두나

`event_done`은 1-cycle pulse일 수 있음. CPU나 interrupt controller가 그 순간을 놓칠 수 있으므로, pulse를 latched pending bit로 잡아둬야 이벤트 유실을 막을 수 있음.

### 여러 인터럽트 소스가 있는 경우

```systemverilog
logic [4:0] intr_pending;  // rx_done, tx_done, overflow, underflow, timeout
logic [4:0] intr_enable;

assign irq = |(intr_pending & intr_enable);  // 하나라도 살아있으면 assert
```

---

## 4. Level-triggered vs Edge-triggered

| 종류 | 동작 | 주의 |
|---|---|---|
| Level IRQ | 신호가 1인 동안 계속 요청 | ISR에서 clear 안 하면 무한 인터럽트 |
| Edge IRQ | 신호 변화 순간(rising/falling)을 잡음 | 너무 짧으면 놓칠 수 있음, 동기화 필요 |

RTL에서 이 차이는 매우 중요. 특히 clock domain crossing이 있으면 edge IRQ 동기화에 주의.

---

## 5. SW가 IRQ 원인을 파악하는 방식

IRQ는 단순히 "뭐 하나 발생했음"만 알림. 정확한 원인은 ISR에서 `intr_status` 레지스터를 읽어 판별.

```c
void isr(void) {
    if (uart_status & RX_PENDING) {
        handle_uart_rx();
    }
    if (timer_status & TIMEOUT_PENDING) {
        handle_timer();
    }
}
```

여러 장치가 IRQ를 공유하는 경우(shared IRQ), ISR에서 반드시 status register를 확인해야 함.

---

## 6. 검증 체크포인트 (RTL 검증 엔지니어 기준)

### (1) Set 조건
- 1-cycle pulse 이벤트도 놓치지 않는가
- back-to-back 이벤트에서도 정상인가

### (2) Enable/Mask
- enable=0이면 pending은 set되더라도 irq output은 안 뜨는가
- pending set 여부는 spec 확인 필요 (보통 pending은 set됨, irq만 막힘)

### (3) Clear behavior
- W1C (write-1-to-clear): 0 쓴 비트가 실수로 지워지면 안 됨
- read-to-clear
- auto-clear on handshake
- 동시 set/clear 충돌 시 우선순위가 spec과 맞는가

### (4) Multiple source aggregation
- 하나라도 pending이면 irq assert
- 마지막 pending clear 시 irq deassert

### (5) Reset behavior
- reset 후 pending/enable/irq 초기값이 spec과 일치

### (6) Level-like stuck
- clear 안 하면 irq 계속 유지되는 구조인가, pulse인가

---

## 7. 실무 함정 (자주 터지는 버그)

| 버그 | 원인 |
|---|---|
| pending clear 누락 | ISR에서 clear 안 해서 무한 인터럽트 |
| enable/mask polarity 오해 | 1이 enable인지 1이 mask인지 문서 혼동 |
| edge/level 혼동 | pulse IRQ 놓치거나 level IRQ clear 타이밍 꼬임 |
| clock domain crossing | peripheral irq → CPU domain 동기화 미흡, 메타스테빌리티 |
| shared IRQ 원인 판별 누락 | status 레지스터 미확인으로 핸들러 헛돎 |

---

## 8. Set/Clear 동시 충돌 처리

같은 cycle에 HW event로 `pending set`, SW write로 `pending clear`가 동시에 오는 경우:

```systemverilog
// set 우선 패턴 (이벤트 유실 방지)
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        intr_pending <= 1'b0;
    else begin
        if (clr_intr)
            intr_pending <= 1'b0;
        if (event_done)      // 나중에 써야 set이 우선
            intr_pending <= 1'b1;
    end
end
```

실무에서는 **set 우선**을 선호하는 경우가 많음 (이벤트 유실 방지).

---

## 9. SystemVerilog Assertion 예시

```systemverilog
// 이벤트 발생 다음 사이클에 pending set
property p_event_sets_pending;
    @(posedge clk) disable iff (!rst_n)
    event_done |=> intr_pending;
endproperty

// pending + enable → irq assert
property p_irq_assert;
    @(posedge clk) disable iff (!rst_n)
    (intr_pending && intr_enable) |-> irq;
endproperty

// pending 없으면 irq deassert
property p_irq_deassert;
    @(posedge clk) disable iff (!rst_n)
    !(intr_pending && intr_enable) |-> !irq;
endproperty
```

---

## 10. Interrupt Controller 계층

```
장치들 → interrupt controller → CPU
```

interrupt controller 역할:
- 여러 IRQ를 한데 모음
- 우선순위(priority) 결정
- mask/enable 처리
- CPU에게 "지금 누구 때문인지" 알림

블록 단품 검증이면 DUT의 irq output까지만 보면 됨. 서브시스템 검증이면 controller 통과 후 CPU visible status까지 확인.
