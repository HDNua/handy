# 버스(Bus)

> 대상: RTL 검증 엔지니어 (Verilog/SystemVerilog)

---

## Q. BUS는 IP야? IP가 아니야?

> BUS를 통해 통과시킨다는 말을 들으면, 마치 BUS라는 IP를 통과시킨다는 말처럼 들린다.
> 실제로는 BUS란 데이터 전송 인터페이스일 뿐인 것 같다.
> APB, AHB, AXI 등등은 addr, data, ready, valid, resp 같은 포트 정의를 해두는 것이고,
> 이들 자체로 Verilog/SystemVerilog에서 `module~endmodule`로 쓰지 않잖아?

**A. 맞다. AXI/AHB/APB 프로토콜 자체는 IP가 아니다.**

두 가지를 구분해야 한다:

| 용어 | 실체 | module? |
|---|---|---|
| AXI / AHB / APB **프로토콜** | 신호 포트 정의 (addr/data/valid/ready/resp 규약) | ❌ |
| **Interconnect** / Fabric | 주소 decode, arbitration, routing을 수행하는 RTL 블록 | ✅ |

즉, "버스를 통해 보낸다"는 말에는 두 가지가 섞여 있다:

1. **프로토콜** — 신호 이름, 핸드셰이크 규칙, 타이밍. SystemVerilog `interface`로 표현하는 것에 가까움. `module~endmodule` 없음.
2. **Interconnect IP** — 여러 master/slave를 연결해주는 실제 RTL 모듈. 주소를 보고 어느 slave로 보낼지 decode하고, master가 여럿이면 arbitration도 담당. 이건 진짜 `module~endmodule`이 있는 IP.

```
프로토콜 (AXI)   →  신호 규약. interface 선언에 가까움. IP 아님.
Interconnect     →  실제 RTL 모듈. 주소 decode + arbitration. IP 맞음.
```

간단한 시스템에서 interconnect는 아래처럼 몇 줄짜리 address decode 로직일 수도 있다:

```systemverilog
assign sel_mem = bus.valid && (bus.addr[31:28] == 4'h8);
assign sel_ip1 = bus.valid && (bus.addr[15:12] == 4'h1);
assign sel_ip2 = bus.valid && (bus.addr[15:12] == 4'h2);
```

복잡한 SoC에서는 ARM NIC-400 같은 전용 Interconnect IP가 들어간다.

**결론**: "버스를 통해 보낸다" = 정해진 프로토콜 신호(AXI 등)를 따르면서, Interconnect라는 실제 IP를 경유해서 다른 블록에 도달한다는 뜻.

---

## 1. 버스란 무엇인가

### 한 줄 정의

> **여러 블록이 공통 규칙으로 주소 기반 read/write access를 할 수 있게 만든 인터페이스**

더 줄이면: **주소 달린 공용 접근 인터페이스**

### RTL에서 버스는 어떻게 보이나

버스는 특별한 마법 객체가 아니라, 신호들의 집합:

```systemverilog
logic [31:0] addr;    // 어느 주소에 접근할지
logic [31:0] wdata;   // 쓸 데이터
logic [31:0] rdata;   // 읽어온 데이터
logic        write;   // read인지 write인지
logic        valid;   // 요청이 유효함
logic        ready;   // 상대가 받겠다는 뜻
```

이 6개가 있으면 이미 버스 냄새가 남. 핵심은:

- **주소 (addr)** — 어디에 접근할지
- **데이터 (data)** — 무엇을 읽고 쓸지
- **제어 (write/read)** — 방향
- **핸드셰이크 (valid/ready)** — 언제 전송이 성립하는지

---

## 2. 버스가 필요한 이유

### 버스 없는 구조: 전부 1:1 직결

```
CPU ──────────────────> DMA_REG
CPU ──────────────────> IP1_REG
CPU ──────────────────> IP2_REG
CPU ──────────────────> MEM_CTRL
DMA ──────────────────> MEM_CTRL
DMA ──────────────────> IP1
```

문제:
- 연결이 폭발적으로 증가
- 규칙이 각각 다를 수 있음
- 블록 추가할수록 지저분해짐

### 버스 있는 구조: 공통 규약 하나

```
CPU master ──┐
DMA master ──┤─> Interconnect ──> MEM slave
             │                ──> IP1 slave
             │                ──> IP2 slave
             └────────────────> DMA reg slave
```

- 모두 같은 방식으로 접근
- 주소 decode로 대상 선택
- master/slave 역할 명확

---

## 3. Master / Slave

| 구분 | 설명 | 예 |
|---|---|---|
| Master | 요청을 먼저 시작하는 쪽 | CPU, DMA |
| Slave | 요청을 받아주는 쪽 | register block, memory, peripheral |

### DMA의 두 얼굴

DMA 하나 안에서도 두 역할이 동시에 존재:

- **DMA register block**: CPU가 설정하는 slave
- **DMA engine**: 실제 데이터 이동을 시작하는 master

```
CPU(master) → DMA reg(slave)    ← CPU가 DMA를 설정
DMA(master) → DRAM(slave)       ← DMA가 데이터를 옮김
```

---

## 4. 버스 프로토콜: APB / AHB / AXI

버스는 추상적 개념이고, 이를 구체화한 규칙이 프로토콜.

| 프로토콜 | 특징 | 주 용도 |
|---|---|---|
| APB | 가장 단순 | 저속 register control |
| AHB | APB보다 강함 | 전통적 bus |
| AXI | 고성능, 복잡 | burst, outstanding, channel 분리 |

### 중요한 구분

> **AXI/AHB/APB 프로토콜 자체는 `module~endmodule`이 아니다.**

- 프로토콜 = **신호 포트 정의 (인터페이스 규약)**. SystemVerilog `interface`에 가까움.
- Interconnect/Fabric = 실제 라우팅·arbitration을 수행하는 **RTL 모듈 (IP)**

| 용어 | 실체 | module? |
|---|---|---|
| AXI protocol | 신호 규약 (addr/data/valid/ready/resp 포트) | ❌ |
| AXI Interconnect | routing + arbitration RTL IP | ✅ |

"버스를 통해 보낸다"는 말은 프로토콜 + interconnect 둘을 합쳐 부르는 표현.

---

## 5. "버스를 탄다"는 말의 의미

**버스 프로토콜 규칙대로 주소/데이터/제어 신호를 내보내서 다른 블록과 통신한다**는 뜻.

단순히 "데이터를 흘린다"(valid/ready 스트리밍)와 다른 점은 **주소 기반 접근**이 포함된다는 것.

| 표현 | 범위 |
|---|---|
| "데이터를 보낸다" | 포괄적. FIFO, 전용선, 버스 등 모두 포함 |
| "버스를 태워서 보낸다" | 주소/제어/핸드셰이크 포함한 transaction으로 공용 통로를 이용 |

---

## 6. Point-to-Point vs Bus

| 종류 | 주소 | 대상 | 예 |
|---|---|---|---|
| Point-to-point | 없음 | 1:1 전용 | valid/ready 스트리밍 |
| Bus | 있음 | 공용 다대다 | APB, AHB, AXI |

주소 decode 코드가 보이면 버스:

```systemverilog
if      (addr[15:12] == 4'h0) sel_dma_reg = 1;
else if (addr[15:12] == 4'h1) sel_ip1     = 1;
else if (addr[31:28] == 4'h8) sel_mem     = 1;
```

---

## 7. 버스 구조의 3층

| 계층 | 역할 | 예 |
|---|---|---|
| Bus master | 요청을 시작하고 주소/제어를 내보냄 | CPU, DMA |
| Bus slave | 주소를 decode해서 자기 reg/mem에 반응 | DMA reg, timer reg, memory ctrl |
| Interconnect | 주소 보고 적절한 slave로 라우팅, arbitration | decoder, crossbar |

---

## 8. 작은 예제: 버스의 축소판

### Master

```systemverilog
module simple_master (
    input  logic        clk, rst_n, start,
    output logic [31:0] bus_addr,
    output logic [31:0] bus_wdata,
    output logic        bus_write,
    output logic        bus_valid,
    input  logic        bus_ready
);
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bus_valid <= 0;
        end else begin
            if (start) begin
                bus_addr  <= 32'h0000_0004;
                bus_wdata <= 32'h1234_5678;
                bus_write <= 1'b1;
                bus_valid <= 1'b1;
            end else if (bus_valid && bus_ready) begin
                bus_valid <= 1'b0;
            end
        end
    end
endmodule
```

### Slave (address decoder 포함)

```systemverilog
module simple_slave (
    input  logic        clk, rst_n,
    input  logic [31:0] bus_addr,
    input  logic [31:0] bus_wdata,
    input  logic        bus_write,
    input  logic        bus_valid,
    output logic        bus_ready,
    output logic [31:0] reg0, reg1
);
    assign bus_ready = 1'b1;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg0 <= 0; reg1 <= 0;
        end else if (bus_valid && bus_write && bus_ready) begin
            case (bus_addr)
                32'h0000_0000: reg0 <= bus_wdata;
                32'h0000_0004: reg1 <= bus_wdata;
            endcase
        end
    end
endmodule
```

이것만 봐도 이미 **버스 프로토콜의 축소판**. AXI가 갑자기 하늘에서 떨어지는 게 아니라, 이 구조가 더 정교해진 것.

---

## 9. SystemVerilog interface로 버스 표현

```systemverilog
interface simple_bus_if;
    logic [31:0] addr;
    logic [31:0] wdata;
    logic [31:0] rdata;
    logic        write;
    logic        valid;
    logic        ready;
endinterface

module cpu (
    input logic clk, rst_n,
    simple_bus_if bus
);

module dma_regs (
    input logic clk, rst_n,
    simple_bus_if bus
);
```

이렇게 하면 여러 블록이 하나의 공통 인터페이스를 공유하는 구조가 시각적으로 명확해짐.

---

## 10. DMA 문맥으로 다시 보는 버스

### 장면 A: CPU가 DMA를 설정한다

```
CPU(master) → [BUS] → DMA reg block(slave)
```

CPU가 `src_addr`, `dst_addr`, `len`, `start` 등을 bus transaction으로 write.

### 장면 B: DMA가 DRAM에 쓴다

```
DMA(master) → [BUS] → DRAM(slave)
```

DMA engine이 bus master로 burst write transaction을 발생.

### 핵심

**CPU도 DMA도 같은 버스를 사용. 차이는 누가 bus master로 transaction을 시작하느냐.**

| | CPU 직접 복사 | DMA 전송 |
|---|---|---|
| 버스 사용 여부 | ✅ 사용 | ✅ 사용 |
| Bus master | CPU | DMA |
| Transaction 발생 주체 | CPU 명령어마다 직접 | DMA 자율 (burst) |
| CPU 부담 | load/store 수천 번 | 설정 + IRQ 수신만 |

---

## 11. 버스를 알아보는 체크리스트

RTL 코드를 볼 때 아래 질문으로 확인:

| 질문 | 버스일 가능성 |
|---|---|
| 주소(`addr`) 신호가 있나? | 높음 |
| read/write 구분 신호가 있나? | 높음 |
| valid/ready 또는 req/ack가 있나? | 인터페이스 규약 있음 |
| 같은 인터페이스로 여러 대상을 선택하나? | 거의 확실 |
| register map / memory map이 정의되어 있나? | bus slave 가능성 높음 |
| master/slave라는 표현이 나오나? | 버스 구조 가능성 높음 |

---

## 12. 비유: API Gateway

웹 개발 관점으로 비유하면:

| 버스 개념 | 웹 비유 |
|---|---|
| 버스 주소 | URL / route |
| 데이터 | request body |
| write/read | POST / GET |
| 버스 decoder | 라우터 |
| bus master | 클라이언트 |
| bus slave | 각 서비스 엔드포인트 |

```
Client → API Gateway → /user
                     → /order
                     → /payment
```

= CPU/DMA → Interconnect → DMA_REG / MEM / IP1
