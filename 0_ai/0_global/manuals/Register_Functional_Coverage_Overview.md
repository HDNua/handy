# Register Functional Coverage (Pre-Simulation Analysis)

## 1. 개요 (Overview)
기존 RTL 시뮬레이션 환경에서는 검증할 수 없었던 **레지스터 설정의 모든 조합(Cross-bin) 영역을 새롭게 검증**하기 위한 방법론을 구현했습니다.
무거운 시뮬레이션을 수행하지 않고 **Vector Generation (LLS) 단계의 데이터**를 직접 분석함으로써, 기존에는 접근 불가능했던 검증 사각지대(Blind Spot)를 해소하고 검증 완전성(Completeness)을 확보했습니다.

## 2. 배경 및 문제점 (Problem Statement)
*   **검증의 사각지대 (Blind Spot)**: 레지스터 설정의 조합(Cross-bin)은 경우의 수가 무한에 가까워, 기존의 RTL Simulation 방식으로는 현실적으로 전수 검사가 불가능했습니다. 이로 인해 **"검증되지 않은 영역"**이 존재할 수밖에 없었습니다.
*   **암묵적 합의의 위험성**: "주요 케이스는 다 돌렸으니 괜찮겠지" 하는 막연한 가정(Assumption)에 의존해야 했으며, 이는 잠재적인 **Hidden Bug**의 원인이 될 수 있었습니다.
*   **가시성 부재**: 실제 어떤 조합이 테스트되었고 어떤 조합이 누락되었는지 정량적으로 파악할 수 있는 지표가 없었습니다.

## 3. 해결 방안 (Technical Solution)

### 3.1. Pre-Simulation Coverage Measurement (New Capability)
*   **패러다임 전환**: RTL 시뮬레이션의 결과에 의존하는 것이 아니라, **입력 데이터(Vector) 자체를 분석**하여 커버리지를 측정하는 새로운 접근 방식을 도입했습니다.
*   **Coverage Expansion**: 기존에는 시간/자원 제약으로 시도조차 못했던 '전수 조사'에 준하는 **광범위한 커버리지 확보**가 가능해졌습니다.

### 3.2. Python 기반 자동화 도구 개발
*   **고속 연산**: `Python`의 `itertools` 등을 활용하여 대량의 Register 조합을 빠르게 순회하며 검사하도록 구현했습니다.
*   **사용자 편의성 개선 (Iterators)**:
    *   RTL 설계자가 Coverage Bin을 일일이 나열하는 번거로움을 줄이기 위해, **A/B 반복자(Symbolic Iterator)** 개념을 도입했습니다.
    *   숫자만 바뀌는 패턴이나 반복되는 필드 설정에 대해 반복자를 허용하여 입력 복잡도를 대폭 낮췄습니다.
*   **보고서 간소화**: Coverage Hole(미달성 항목)을 직관적으로 파악할 수 있는 요약된 리포트를 제공합니다.

### 3.3. 검증 플로우 (Workflow)
1.  **Input**: 설계자가 정의한 Coverage Bin (Target) & 생성된 Vector (Actual Data).
2.  **Process**: Script가 Vector 내의 Register Write 커맨드를 파싱하여 Cross-bin 매칭 수행. (No RTL Sim)
3.  **Output**: Coverage Report 생성 및 Missing Bin 리포팅.

## 4. 핵심 성과 (Key Achievements)

### 🚀 주도적 문제 해결 (Proactive Ownership)
*   **R&R 확장**: 본래 담당 업무가 아니었으나, 동료(설계자)의 지원 요청을 받고 필요성을 공감하여 **주도적으로 개발**을 담당했습니다.
*   **적극적 소통**: 개발 과정에서 피드백을 수용하여 기능을 개선했고, 이 과정을 Confluence와 메일로 상세히 기록하여 **히스토리 추적**이 용이하게 했습니다.

### 🔍 검증 완전성 확보 (Completeness)
*   **사각지대 해소**: 기존 RTL 검증으로는 불가능했던 **방대한 Register 조합에 대한 전수 검증**을 실현했습니다.
*   **Zero-Cost Verification**: 추가적인 시뮬레이션 리소스 투입 없이, 스크립트 실행만으로 즉각적인 정합성 검증이 가능합니다.

### 📚 문서화 및 자산화 (Documentation)
*   사용법 매뉴얼(User Manual)을 작성하고 메신저/구두 교육을 병행하여 툴의 **팀 내 정착**을 유도했습니다.
