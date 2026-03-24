# VP (Virtual Platform) Verification Environment

## 1. 개요 (Overview)
Modem 검증을 위해 도입된 **C++ 기반의 Virtual Platform(VP)** 검증 환경을 구축하고, 신뢰성을 확보하기 위한 **Cross-Check Framework**를 개발했습니다.
RTL(Register Transfer Level) 시뮬레이션 결과와 VP 시뮬레이션 결과를 정밀하게 비교/분석하여, VP 모델의 정확성을 검증하고 SW 조기 개발을 지원했습니다.

## 2. 주요 구성 요소 (Key Components)

### 2.1. Simulator Interoperability
*   **Pure C++ Implementation**: 외부 의존성(External Dependency)을 최소화하여 이식성을 높였습니다.
*   **Cross-Platform FileSystem Interface**:
    *   RHEL(Linux), Windows, WSL 등 다양한 OS 환경에서 동일한 코드로 동작하도록 **파일 I/O 추상화 계층(Bridge Pattern)**을 구현했습니다.
*   **Asset Updater**: RTL 시뮬레이션 결과를 VP 디렉토리 구조에 맞춰 자동으로 마이그레이션해주는 스크립트를 제공하여 사용자 편의성을 높였습니다.

### 2.2. Verification Checkers (RTL vs VP)
기존 RTL 검증 환경(Golden Reference)의 출력 로그와 신규 VP 환경의 로그를 비교하는 방식을 채택했습니다.

*   **RTL Sim Log Parser**: RTL 로그를 파싱하여 VP 시뮬레이션의 입력 벡터(Stimulus)로 변환하는 전처리 도구.
*   **Interrupt Checker**:
    *   **Count Checker**: 발생한 인터럽트의 총개수 비교.
    *   **Sequence Checker**: 인터럽트 발생 순서의 일치 여부 검증.
    *   **ISR Compare**: 단순 인터럽트 트리거뿐만 아니라, ISR(Interrupt Service Routine) 내의 레지스터 설정 값까지 비교 검증.
*   **DataMover Checker**: 대용량 데이터 전송(DataMover) 동작에 대해 RTL과 VP 간의 데이터 정합성을 바이트 단위로 검증.

## 3. 핵심 성과 (Key Achievements)

### 📊 시각화를 통한 디버깅 효율화 (Bitmap Waveform View)
*   **문제**: 텍스트 로그만으로는 수만 사이클에 걸친 트랜잭션과 인터럽트 타이밍을 직관적으로 파악하기 어려웠습니다.
*   **해결**: 로그 데이터를 분석하여 **BMP 이미지 형태의 파형(Waveform)**으로 시각화하는 도구를 자체 개발했습니다.
*   **성과**:
    *   복잡한 타이밍 이슈를 한눈에 파악 가능.
    *   실제로 이를 통해 **Latch Timing Bug** (미세한 타이밍 차이로 인한 데이터 오염)를 발견하고 수정하는 결정적인 성과를 거뒀습니다.

### 📈 업무 자동화 (Automation)
*   **Jira Report Automation**: 검증 결과 및 이슈를 Jira 티켓으로 생성할 때 필요한 데이터를 CSV 형태로 자동 추출하여, 리포팅 시간을 단축했습니다.
