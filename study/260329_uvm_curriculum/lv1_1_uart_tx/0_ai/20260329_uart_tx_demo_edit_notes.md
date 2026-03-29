# UART TX Demo HTML 수정 내역

작성일: 2026-03-29

---

## 1. 문서 목적

`uart_tx_demo.html`을 UART TX 학습용 시각 자료로 사용하던 중,
용어와 그림 구조 때문에 개념 오해가 생길 수 있는 부분을 정리하고 수정했다.

이번 수정의 핵심 목표는 다음과 같다.

- `monitor`가 디스플레이 모니터처럼 읽히지 않도록 표현 수정
- CPU, UART TX, 수신측 장치의 관계를 그림에서 더 명확하게 표현
- Testbench의 `monitor`와 실제 시스템의 `UART RX`를 분리해서 설명
- 레이아웃 겹침 문제 해소

---

## 2. 수정 전 혼동 포인트

### 2.1 `Monitor PC` 표현의 혼동

초기 HTML에서는 오른쪽 수신측 박스를 `Monitor PC`라고 표기했다.
이 표현은 다음 두 가지 오해를 만들 수 있었다.

- 사용자가 보는 디스플레이 모니터를 뜻하는 것처럼 읽힘
- UVM/Testbench의 `monitor`와 실제 수신 장치를 같은 의미로 오해할 수 있음

### 2.2 CPU가 시스템 밖에 따로 있는 것처럼 보임

왼쪽에 `CPU` 박스만 따로 배치되어 있어,
CPU가 송신 시스템 내부 구성요소가 아니라 독립된 외부 장치처럼 읽힐 여지가 있었다.

### 2.3 수신측 장치와 UART RX가 한 덩어리로 표현됨

오른쪽은 장치 전체와 UART 수신부가 구분되지 않은 상태였다.
그래서 아래처럼 이해되어야 할 구조가 그림에서는 분해되어 보이지 않았다.

```text
[ CPU ]
    v
[ UART TX ] -> serial line -> [ UART RX ] -> [ Receiver Device 내부 처리 ]
```

또는 더 단순하게는:

```text
[ CPU ] -> [ UART TX ] -> [ UART RX inside Receiver Device ]
```

---

## 3. 실제로 반영한 수정 내용

### 3.1 상단 설명 문구 수정

헤더 설명에서 기존 `Receiver PC` 중심 문구를 정리하고,
오른쪽은 `Receiver Device`, 그 안에는 `UART RX`가 있다는 구조로 설명을 바꿨다.

핵심 메시지:

- 오른쪽은 화면 모니터가 아니라 수신 장치임
- 실제로 직렬 비트를 받아 다시 조립하는 주체는 `UART RX`임

### 3.2 버튼 문구 수정

좌측 단계 버튼의 3단계 문구를 다음처럼 수정했다.

- 수정 전: `다시 조립하기 (Receiver/TB Monitor)`
- 수정 후: `다시 조립하기 (UART RX/TB Monitor)`

이 수정으로 실제 시스템의 수신기 역할과 Testbench의 monitor 역할을 구분하도록 했다.

### 3.3 수신측 박스 명칭 변경

오른쪽 박스 제목을 다음처럼 변경했다.

- 수정 전: `Receiver PC`
- 수정 후: `Receiver Device`

이 변경 이유는 다음과 같다.

- `PC`라고 쓰면 왼쪽 CPU도 하나의 PC처럼 읽힐 수 있음
- UART는 꼭 PC 대 PC 통신이 아니라 장치 대 장치 통신일 수도 있음
- `Receiver Device`가 보다 일반적이고 덜 헷갈림

### 3.4 `UART RX` 내부 블록 추가

오른쪽 수신측 박스 내부에 별도 `UART RX` 블록을 추가했다.

이를 통해 그림이 아래 구조로 읽히게 만들었다.

```text
송신측 시스템:
CPU -> UART TX

수신측 시스템:
Receiver Device 내부에 UART RX 존재
```

즉, 데이터 흐름은 다음과 같다.

```text
CPU -> UART TX -> TX_SERIAL(1bit 선) -> UART RX -> 1바이트 복원
```

### 3.5 `Testbench monitor`와 실제 `UART RX` 역할 분리 설명

상태 설명 문구에서 아래 기준을 분명히 했다.

- 실제 시스템에서는 `UART RX`가 start bit를 감지하고 비트를 샘플링함
- Testbench에서는 이 RX 동작을 `monitor`가 흉내 냄
- scoreboard는 복원 결과가 기대값과 맞는지 확인함

즉,

- 현실 세계 역할: `UART RX`
- 검증 환경 역할: `monitor`

로 분리해서 설명하도록 바꿨다.

### 3.6 송신측 시스템 묶음 추가

왼쪽에 `SENDER SIDE` 외곽 영역을 추가해서,
CPU와 UART TX가 같은 송신 시스템 내부에 있다는 점을 시각적으로 보강했다.

추가된 설명 문구:

- `CPU와 UART TX는 같은 시스템 안에 있습니다.`

### 3.7 레이아웃 겹침 수정

`SENDER SIDE` 라벨을 추가한 뒤,
상단 설명 텍스트와 CPU 박스가 겹쳐 보이는 문제가 발생했다.

이를 해결하기 위해:

- `SENDER SIDE` 제목/부제 위치 조정
- 배경 배지 추가
- CPU 박스 위치를 아래로 이동
- CPU에서 UART TX로 내려가는 병렬 버스 위치도 함께 조정

하여 겹침 현상을 완화했다.

---

## 4. 현재 그림이 전달하려는 최종 개념

현재 HTML은 아래 개념을 보여주도록 정리되었다.

### 4.1 송신측

- CPU가 `tx_data[7:0]` 형태로 1바이트를 UART TX에 전달
- UART TX는 이 8비트를 내부 레지스터에 적재

### 4.2 직렬 전송

- UART TX는 `start bit`
- 그 다음 `data 8bit`
- 마지막으로 `stop bit`

를 `TX_SERIAL` 한 줄로 차례대로 전송

### 4.3 수신측

- 수신 장치(`Receiver Device`) 내부의 `UART RX`가 선을 관찰
- start bit를 기준으로 타이밍을 맞춤
- 비트를 다시 샘플링하여 1바이트로 복원

### 4.4 Testbench 관점

- 실제 UART RX 대신 `monitor`가 그 동작을 흉내 냄
- 복원된 결과를 scoreboard가 expected 값과 비교

---

## 5. 현재 표현 기준 요약

앞으로 이 HTML에서 용어는 다음 기준으로 유지하는 것이 좋다.

- `CPU`: 송신측 제어기
- `UART TX`: 송신 직렬화 블록
- `Receiver Device`: 반대편 수신 장치
- `UART RX`: 수신 장치 내부에서 비트를 다시 1바이트로 조립하는 블록
- `monitor`: Testbench 안에서 RX 동작을 흉내 내는 검증용 관찰 블록

특히 아래 두 표현은 구분해서 써야 한다.

- 실제 시스템: `UART RX`
- 검증 환경: `monitor`

---

## 6. 남은 개선 아이디어

아직 더 다듬는다면 아래 항목을 고려할 수 있다.

- `UART RX`에서 `Receiver Device` 상위 로직으로 가는 화살표 추가
- `CPU -> UART TX -> UART RX -> Receiver Device 내부 처리` 흐름을 작은 보조 다이어그램으로 추가
- `LSB first`, `start bit`, `stop bit`를 선 위에 더 직접적으로 표시
- Testbench용 보조 모드에서 `monitor`와 `scoreboard`를 별도 미니 블록으로 시각화

---

## 7. 결론

이번 수정의 핵심은 단순한 문구 교정이 아니라,
UART 실제 동작과 Testbench 관찰 구조를 서로 헷갈리지 않게 분리하는 것이었다.

최종적으로는 다음 메시지가 그림에서 읽히는 상태를 목표로 했다.

```text
왼쪽: CPU + UART TX 가 있는 송신측 시스템
가운데: TX_SERIAL 한 줄
오른쪽: Receiver Device 내부의 UART RX
검증 환경에서는 monitor가 UART RX 역할을 흉내 냄
```
