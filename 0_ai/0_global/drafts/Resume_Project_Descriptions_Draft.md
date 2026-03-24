# Career Description Draft (Engineering Focus)

## 1. Virtual Platform Verification (C++ Based Modem Model)
**Role**: Verification Environment Developer (C++ / Python)
**Period**: 2024.03 - 2024.12
**Key Achievements**:
*   **Cross-Platform Verification Environment**:
    *   OS 의존성을 제거한 **FileSystem Abstraction Layer**를 설계하여, RHEL(Linux) 및 Windows(WSL) 환경에서 동일하게 동작하는 Seamless Test Environment 구축.
    *   RTL 시뮬레이션 로그를 VP 입력 포맷으로 자동 변환하는 **Log Parser** 개발로 이종 플랫폼 간 교차 검증(Cross-Check) 수행.
*   **Debugging Visualization Tool**:
    *   텍스트 로그 기반 디버깅의 한계를 극복하고자, 트랜잭션 데이터를 **BMP Waveform으로 변환하는 시각화 도구** 자체 개발.
    *   이를 통해 수만 사이클에 걸친 미세한 **Latch Timing Mismatch 및 Interrupt Sequence 오류**를 직관적으로 분석하여 수정 기여.

## 2. Register Functional Coverage (Pre-Simulation Analysis)
**Role**: Verification Tool Developer (Python)
**Period**: 2024.10 - 2025.06
**Key Achievements**:
*   **Blind Spot Elimination**:
    *   무한에 가까운 조합으로 인해 RTL 시뮬레이션에서 전수 검증이 불가능했던 **Register Cross-bin Combination** 문제를 해결하기 위해, Vector 생성 단계에서의 정적 분석(Static Analysis) 방법론 도입.
*   **Python Automation Tooling**:
    *   `itertools`를 활용한 고속 연산 스크립트를 개발하여, 시뮬레이션 수행 없이도 **Register 설정의 완전성(Completeness)**을 검증.
    *   반복되는 패턴 입력을 단순화한 **Symbolic Iterator** 기능을 도입하여, 설계자가 커버리지 항목을 쉽게 정의할 수 있도록 사용성 개선.

## 3. Automated LLS Transfer System (ALT)
**Role**: Automation Tool Developer (C# / Selenium)
**Period**: 2018.04 - 2025.07
**Key Achievements**:
*   **Workflow Automation (RPA)**:
    *   SharePoint 업로드 -> Local 다운로드 -> Linux 서버 전송 -> 컴파일로 이어지는 다단계 수동 프로세스를 **One-Click Solution**으로 자동화.
    *   `Selenium` 및 `Windows API`를 활용하여 사용자 부재 시에도 24/7 지속적인 Regression Test가 가능한 **무인 자동화 파이프라인** 구축.
*   **Business Continuity & Architectural Agility**:
    *   초기부터 저장소(Source)와 전송 로직을 분리한 **Repository-Agnostic Design**을 적용.
    *   갑작스러운 **SharePoint 서비스 중단(Deprecation) 사태** 발생 시, 별도의 코드 수정 없이 즉시 **Git Repository 기반**으로 전환하여 팀 전체의 업무 중단(Downtime)을 0으로 방어.
    *   단순 편의 도구(Nice-to-have)에서 검증 인프라의 핵심(Mission-Critical)으로 격상.
*   **Legacy Compatibility**:
    *   최신 프로젝트뿐만 아니라 3G 등 레거시 구조까지 지원하는 **범용 전송 모듈**을 설계하여 팀 내 표준 툴로 정착.

## 4. Active Mode Memory Power Gating (AMMPG) Verification
**Role**: Verification Engineer (SystemVerilog / UVM)
**Period**: 2024.01 - 2025.07
**Key Achievements**:
*   **Low Power Logic Verification**:
    *   **Fine-grained Power Gating** 검증을 위해, 동작 중(Active)인 블록 내 미사용 메모리의 상태 전이(Normal <-> Retention <-> PowerDown)를 모니터링하는 **State Checker** 개발.
*   **Project Migration Support**:
    *   SW 방식의 제어에서 HW 기반(HW-driven) 제어로 전환되는 **QSLP(Quick-Sleep Low Power)** 아키텍처 변경에 맞춰, 새로운 프로토콜 검증 기준을 수립하고 Checker에 반영.

## 5. AI-Driven Legacy Code Modernization
**Role**: Infrastructure Developer (Python / AI Ops)
**Period**: 2024.01 - 2024.11
**Key Achievements**:
*   **Offline AI Environment Construction**:
    *   외부망 접속이 차단된 사내 보안 환경(Intranet) 내에서, **Ollama 및 LLM 모델을 수동으로 배포 및 최적화**하여 독립적인 AI 코딩 어시스턴트 환경 구축.
*   **Batch Inference Pipeline**:
    *   서버 리소스 제약으로 인한 낮은 추론 속도(Low Inference Speed) 문제를 해결하기 위해, 대화형(Chat) 방식 대신 **Questions Queue 기반의 일괄 처리(Batch Processing) 스크립트**를 개발.
    *   마치 Regression Test를 돌리듯, 밤새 수백 개의 레거시 코드 변환 작업을 수행시켜 **Perl to Python 마이그레이션 효율을 극대화**.

## 6. DataMover Verification Environment
**Role**: Verification Lead (Python / SystemVerilog)
**Period**: 2018.04 - 2025.07 (Continuous)
**Key Achievements**:
*   **Robust Verification Logic**:
    *   Flow/Non-Flow Control이 혼재된 복잡한 트랜잭션을 분석하는 **Transaction Reassembly Logic** 구현.
    *   파편화된 AXI 로그를 재조합하여 Reference 모델과 1:1 비교하는 **Scoreboard** 구축으로 데이터 무결성 검증.
*   **Performance Optimization**:
    *   Checker 내부의 Linear Search 로직을 **Hash Map(Address Router) 구조**로 리팩토링하여 검증 속도 개선.
    *   반복적인 File I/O 오버헤드를 줄이기 위한 **Caching Layer** 도입.
