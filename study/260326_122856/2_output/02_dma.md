# DMA (Direct Memory Access)

> 대상: RTL 검증 엔지니어 (Verilog/SystemVerilog)

---

## 1. DMA란

### 이름의 뜻

DMA = **Direct Memory Access**. 원래는 기능/방식의 이름.

CPU가 일일이 load/store 하지 않고, 하드웨어가 **메모리와 메모리, 또는 메모리와 주변장치** 사이 데이터를 직접 옮기는 방식.

### 실무에서의 의미

실제 SoC에서는 이 기능을 구현하는 **RTL 블록 자체를 DMA라고 부름**.

- DMA controller
- DMA engine
- AXI DMA
- central DMA / peripheral DMA

즉, DMA는 **개념 이름**이기도 하고, 그 개념을 구현한 **IP 이름**이기도 함.

비교: UART도 통신 방식 이름이지만, 실제 구현 IP를 UART라고 부르는 것과 같음.

---

## 2. DMA의 핵심 역할

**CPU 대신 버스를 타고 데이터를 옮기는 전용 전송 엔진**

```
CPU: DMA야, 4KB 복사해
DMA: 알겠음. 내가 함...
DMA: 끝났음 → IRQ assert
CPU: ISR 진입해서 완료 처리
```

### DMA가 지원하는 전송 방향

- memory → memory
- peripheral → memory
- memory → peripheral

peripheral의 register/FIFO도 버스 주소 공간에 매핑되어 있으므로, DMA 입장에서는 모두 **주소를 가진 대상**.

---

## 3. 왜 DMA를 쓰는가

### CPU가 직접 하면 생기는 문제

```
IP → CPU가 읽음 → CPU가 DRAM에 씀
```

- CPU가 load/store 명령을 수천 번 반복
- polling overhead 발생
- bus 접근 반복 → bus pressure
- 다른 일 할 시간 감소
- "SW적으로 MIPS가 안 나온다"

### RO Register 방식의 문제

DMA 없이 SW가 IP 데이터를 보려면, IP의 Read Only Register를 CPU가 반복해서 읽어야 함.

- HW: 큰 결과 버퍼를 register map으로 노출해야 → **HW area 증가**
- SW: register read를 수천 번 반복 → **CPU MIPS 낭비**

예) 8KB 결과 데이터를 RO register로 읽으면 32bit 기준 2048번 read.

### DMA 방식의 장점

```
IP → DMA가 읽음 → DMA가 DRAM에 씀 → irq → CPU가 결과 확인
```

- CPU는 src/dst/len/start 설정만 하고 빠짐
- DMA가 burst transaction으로 버스에 직접 전송
- CPU는 완료 interrupt만 받아 결과 확인
- 대용량 데이터에서 bus 효율 훨씬 좋음

### 핵심 컨셉

> CPU라는 비싼 범용 처리기가 단순 반복 데이터 이동에 시간을 낭비하지 않도록,
> DMA라는 전용 하드웨어가 그 노동을 대신하는 구조.

- **CPU = 감독 (설정 + 완료 확인)**
- **DMA = 지게차/택배기사 (실제 운반)**

---

## 4. DMA는 bus master IP

DMA는 RTL 구조적으로 두 얼굴을 가짐:

| 역할 | 설명 | bus 관점 |
|---|---|---|
| DMA register block | CPU가 설정하는 대상 | slave |
| DMA engine | 실제 데이터 이동 | master |

### DMA RTL 블록의 특성

- 레지스터 맵 보유 (src_addr, dst_addr, length, ctrl)
- AXI/AHB 버스에 master로 연결
- 전송 완료/에러 시 status set + irq assert
- CPU는 버스를 통해 DMA 레지스터를 slave로 접근

---

## 5. DMA가 발생시키는 IRQ 소스

DMA도 IRQ를 발생시키는 대표 peripheral.

| 이벤트 | 설명 |
|---|---|
| 전송 완료 (done) | 정상 전송 완료 |
| 반쪽 완료 (half done) | 더블 버퍼링 등에 활용 |
| 에러 발생 | bus error, address error 등 |
| descriptor 처리 완료 | scatter-gather DMA |
| 채널별 완료 | 다채널 DMA에서 채널 단위 |

---

## 6. DMA를 쓰는 게 유리한 상황

| 상황 | 이유 |
|---|---|
| 데이터 양이 큰 경우 | CPU polling/copy는 금방 병목 |
| 반복 전송이 많은 경우 | 주기적 전송에 최적 |
| 고속 처리가 필요한 경우 | CPU 점유율 절감 |
| IP를 재사용 가능하게 만들 때 | IP는 data source/sink만 담당 |

### DMA가 오히려 과한 경우

- 소량/단순/일회성 데이터 → CPU가 직접 접근하는 편이 단순

---

## 7. RTL 설계자 관점: DMA를 쓰면 내 IP가 단순해진다

DMA를 쓰면 내 IP는 **bus master 로직 없이** 설계 가능:

| 내 IP가 직접 master | DMA 사용 |
|---|---|
| AXI/AHB master interface 필요 | 불필요 |
| burst 처리, outstanding 관리 | DMA가 담당 |
| backpressure 대응 | DMA가 담당 |
| 검증 범위가 커짐 | IP 단품 범위는 줄어듦 |

대신 DMA를 쓰면 새로운 고려사항 발생:
- FIFO interface / request-ack / descriptor handshake
- SW 드라이버 복잡도 증가
- cache coherency 이슈 가능
- end-to-end 디버깅 포인트 증가

---

## 8. MIPS (Millions of Instructions Per Second)

DMA 관련 논의에서 자주 등장하는 용어.

> "SW 적으로 MIPS가 안 나온다"

= **실제 소프트웨어를 돌려보면 기대한 instruction throughput이 안 나온다**

### MIPS가 안 나오는 원인

- branch 많음
- cache miss
- memory wait
- bus bottleneck / arbitration
- stall, pipeline hazard
- interrupt overhead 많음
- DMA / 다른 master와 버스 경쟁

### 감각용 식

```
MIPS ≈ 클럭(MHz) × IPC
```

CPU가 직접 데이터 운반을 하면 IPC가 낮아져서 MIPS가 안 나옴.
DMA로 오프로딩하면 CPU는 의미 있는 instruction을 더 많이 처리 가능.

---

## 9. DMA 검증 환경 구조

### 기본 구성 요소

```
[CPU BFM]
    |
    | cfg writes / status reads
    v
[DMA DUT] ──irq──> [IRQ monitor]
    |
    | master bus
    v
[Bus Fabric (단순 주소 decoder)]
    |
    +──> [MEM model]
    +──> [IP1 stub]
    +──> [IP2 stub]
```

### 각 블록 역할

| 블록 | 역할 |
|---|---|
| CPU BFM | DMA 레지스터 write/read task 집합 (실제 CPU 불필요) |
| DMA DUT | 검증 대상 |
| MEM model | byte addressable, 랜덤 delay, backpressure, log |
| IP1 stub | data producer (FIFO + read 응답) |
| IP2 stub | data consumer (FIFO + write 수신) |
| IRQ monitor | irq 관찰, assert/deassert 타이밍 확인 |

### 권장 구현 순서

```
1단계: CPU BFM + DMA + MEM  → memory-to-memory만 먼저 통과
2단계: IRQ monitor 추가      → done/clear 검증
3단계: IP1 source stub 추가  → IP1 → memory
4단계: IP2 sink stub 추가    → memory → IP2
5단계: delay/backpressure/random test 추가
```

### CPU BFM 예시 (task 집합이면 충분)

```systemverilog
cpu_write(DMA_SRC,  src_addr);
cpu_write(DMA_DST,  dst_addr);
cpu_write(DMA_LEN,  length);
cpu_write(DMA_CTRL, START);
wait(irq);
cpu_read(DMA_STATUS);
```

### 주소 decode 예시

```
0x0000_0000 ~ 0x0000_FFFF → MEM
0x1000_0000 ~ 0x1000_00FF → IP1
0x1000_0100 ~ 0x1000_01FF → IP2
```

---

## 10. DMA 검증 체크포인트

### 기본 동작

- start 후 완료 시 irq assert
- enable=0이면 pending만 서고 irq는 안 뜸
- clear 후 irq deassert
- 채널 여러 개면 source별 status 분리

### Length 코너케이스

- length = 1
- length = burst size - 1
- length = burst size
- length = burst size + 1
- unaligned src/dst
- zero length (spec 확인)

### 핸드셰이크

- memory read delay
- memory write backpressure
- IP1 data 늦게 나옴
- IP2 ready 늦게 올라옴

### 인터럽트

- done irq assert 조건
- error irq vs done irq 우선순위
- clear 전까지 irq 유지 여부
- same-cycle done + clear 충돌

### 리셋

- 전송 중 reset 시 DUT 상태
- reset 후 register 초기화
- outstanding transaction 처리 규칙

### Scoreboard 기본 구조

| 시나리오 | 비교 방법 |
|---|---|
| memory-to-memory | src 스냅샷 vs dst read-back |
| IP1 → memory | IP1 생성 시퀀스 vs memory dump |
| memory → IP2 | memory preload 패턴 vs IP2 수신 큐 |

결국 scoreboard는 **expected byte stream vs actual byte stream** 비교기.
