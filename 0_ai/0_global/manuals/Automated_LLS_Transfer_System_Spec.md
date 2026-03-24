# ALT (Automated LLS Transfer) System

## 1. 개요 (Overview)
**ALT(Automated LLS Transfer)**는 기존에 검증 엔지니어가 수동으로 수행하던 'LLS(Low Level Simulation) 벡터 배포 및 실행 프로세스'를 **완전 자동화**하기 위해 개발된 시스템입니다.
웹 저장소(SharePoint)에서 Linux 서버(VWP)까지의 복잡한 파일 전송 및 후처리 과정을 원클릭 솔루션으로 대체하여 업무 효율성을 극대화했습니다.

## 2. 배경 및 문제점 (Problem Statement)
*   **복잡한 수동 프로세스**:
    1.  LLS 담당자가 SharePoint에 zip 파일 업로드.
    2.  검증 담당자가 이를 다운로드.
    3.  SmartFTP 등을 통해 Linux 서버로 전송.
    4.  압축 해제 및 컴파일 수행.
    5.  벡터 생성.
*   **비효율성**: 단순 반복 작업에 많은 시간이 소요되며, 담당자 부재 시 업무가 지연되는 병목 현상(Bottleneck)이 발생했습니다.

## 3. 해결 방안 (Technical Solution)

### 3.1. Architecture
*   **2-Step Transfer Mechanism**:
    *   `SharePoint -> Local PC` (Windows)
    *   `Local PC -> VWP` (Linux Server)
    *   두 단계로 분리하여 구현함으로써, 소스 저장소(Source Repository)의 종류(SharePoint, Git 등)에 구애받지 않는 유연한 구조를 확보했습니다.

### 3.2. Technology Stack
*   **Language & Framework**: `C#`, `Windows API`
*   **Web Automation**: `Selenium` (웹로그인 및 파일 다운로드 자동화)
*   **Server Interaction**: Linux 서버와 통신하여 전송 후 자동으로 컴파일 스크립트를 트리거하도록 구현.

## 4. 핵심 기능 (Key Features)
*   **Auto-Compile Trigger**: LLS 전송 즉시 서버에서 컴파일(Compile) 및 벡터 생성을 시작하도록 연동하여, 대기 시간을 제거했습니다.
*   **Multi-Channel Synchronization**: LLS 소스뿐만 아니라, 관련 TC(Test Case) 파일, Progress Excel 시트 등을 병렬 스레드로 동기화하여 다운로드합니다.
*   **Legacy Support**: 최신 프로젝트뿐만 아니라 3G 등 레거시 영역의 프로젝트 구조에도 대응 가능한 **일반화된 솔루션(Generalized Solution)**을 제공했습니다.

## 5. 성과 (Impact)
*   **Zero Human Intervention**: 검증 담당자가 자리에 없어도(부재중) 자동으로 최신 LLS를 받아 시뮬레이션을 돌려놓을 수 있는 환경을 구축했습니다.
*   **업무 효율성 증대**: 단순 파일 이동 시간을 0으로 수렴시켜, 엔지니어들이 검증 분석(Analysis) 등 고부가가치 업무에 집중할 수 있게 했습니다.
