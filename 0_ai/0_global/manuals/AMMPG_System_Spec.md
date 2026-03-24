# AMMPG & Low Power Verification System

## 1. 개요 (Overview)
Modem의 소비전력을 최소화하기 위한 핵심 기술인 **Active Mode Memory Power Gating (AMMPG)** 및 **Quick-Sleep Low Power (QSLP)** 기술을 검증하기 위한 환경을 구축했습니다.
Power Domain 전체를 끄는 기존 방식(Coarse-grained)을 넘어, 동작 중(Active)인 상태에서도 사용하지 않는 각 Memory Block 단위로 미세하게 전원을 제어(Fine-grained)하여 Leakage Power를 절감하는 기술의 무결성을 검증합니다.

## 2. 주요 개념 및 기술 (Key Technologies)

### 2.1. AMMPG (Active Mode Memory Power Gating)
*   **정의**: Function Block이 동작 중(Power-on)인 상태에서도, 시나리오상 일시적으로 사용하지 않는 Memory를 감지하여 Power-down 상태로 전환하는 기술.
*   **진화**:
    *   **SW-driven**: 소프트웨어 제어 기반 (Project5 까지)
    *   **HW-driven**: 하드웨어 로직에 의한 자동 제어 (Project6 부터 도입)

### 2.2. HWMPG (Hardware Memory Power Gating)
*   **기능**: 블록의 미동작 구간을 HW가 실시간으로 판단하여 SRAM을 **PDN(Power Down)** 또는 **RET(Retention)** 상태로 자동 전환.
*   **목적**: CPU/SW 개입 없이 순수 HW 로직으로 빠른 응답속도와 Leakage Power 절감 달성.

### 2.3. QSLP (Quick-Sleep Low Power)
*   **기능**: **Quick-Sleep**(짧은 유휴 구간) 신호와 연동하여 Memory의 Power State를 제어.
*   **QSMPG**: Quick-sleep 구간에서 추가적인 Memory Leakage Power Reduction을 수행하는 기법.

## 3. 검증 환경 구축 (Verification Methodology)

### 3.1. Power State Checker 개발
AMMPG 동작 시 데이터 유실이나 오동작이 발생하지 않는지 검증하기 위해 전용 Checker를 개발했습니다.

*   **RAM Port Monitoring**:
    *   `RAMTOP`의 `RET`(Retention), `PDE`(Power Down Enable) 포트 상태를 사이클 단위로 모니터링.
*   **State Transition Check**:
    *   **Normal** <-> **Retention** <-> **Power Down** 간의 상태 전이가 프로토콜(Spec)에 맞게 안전하게 이루어지는지 검증.
*   **Scenario Coverage**:
    *   Idle 구간 진입 시 HWMPG가 정상적으로 Trigger 되는지 확인.
    *   Active 전환 시 Memory Wake-up Latency가 시스템 동작에 영향을 주지 않는지 확인.

## 4. 핵심 성과 (Key Achievements)
*   **저전력 설계 검증 고도화**: 단순 Power Off가 아닌, 복잡한 상태 천이(State Machine)를 가진 Advanced Power Gating 기술에 대한 검증 사각지대를 해소했습니다.
*   **HW-driven Conversion 지원**: 기존 SW 중심 제어에서 HW 중심 제어로 패러다임이 바뀔 때, 이에 맞는 새로운 검증 기준을 수립하고 Checker를 구현하여 **Project6의 성공적인 칩 설계**에 기여했습니다.
