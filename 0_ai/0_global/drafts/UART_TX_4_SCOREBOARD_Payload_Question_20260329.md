# UART TX `4_scoreboard` Payload 구조 질문 정리

작성일: 2026-03-29

## 목적

`study/260329_uvm_curriculum/lv1_1_uart_tx/4_scoreboard/tb/tb_top_v4.sv` 를 읽다가
`payload` 처리 방식이 어색하게 느껴진 지점을 정리한다.

이 문서는 아래 목적을 가진다.

- 현재 코드가 왜 동작하는지 설명
- 왜 구조적으로 어색하게 느껴지는지 정리
- Claude에게 다시 물어볼 질문을 명확하게 정리

---

## 문제로 느껴진 코드

### 1. 모듈 스코프의 `payload`

```systemverilog
logic [7:0] payload [0:4];
localparam int N = 5;

initial begin
    payload[0] = 8'h48;  // 'H'
    payload[1] = 8'h65;  // 'e'
    payload[2] = 8'h6c;  // 'l'
    payload[3] = 8'h6c;  // 'l'
    payload[4] = 8'h6f;  // 'o'
end
```

### 2. scoreboard 내부에서 `payload`를 다시 queue로 복사

```systemverilog
task uart_scoreboard(int num_bytes);
    logic [7:0] expected_q [$];
    logic [7:0] actual;
    logic [7:0] expected;

    foreach (payload[i]) expected_q.push_back(payload[i]);

    repeat (num_bytes) begin
        @(mon_data_ready);
        actual   = mon_data;
        expected = expected_q.pop_front();
        ...
    end
endtask
```

---

## 지금 이해한 사실

### 1. 왜 scoreboard에서 `payload`가 보이는가

`payload`는 task 내부 지역변수가 아니라 `module tb_top` 스코프에 선언되어 있다.
그래서 같은 모듈 안에 있는 `initial`, `task`, `fork` 블록 어디서든 접근 가능하다.

즉, `uart_scoreboard()`가 `payload`를 직접 읽는 것은 문법적으로 전혀 이상한 일은 아니다.

### 2. 왜 초기화 타이밍 문제가 없는가

`payload`를 채우는 `initial` 블록은 시뮬레이션 시작 시점에 실행된다.
반면 test main 흐름은 reset 몇 클럭 이후에 `fork`를 시작한다.

따라서 scoreboard가 `payload`를 읽는 시점에는 이미 값이 채워져 있다고 볼 수 있다.

즉, 현재 코드는 타이밍상으로는 동작한다.

### 3. `expected_q` 자체는 이상하지 않다

이제 보니 핵심은 `expected_q`의 존재가 아니다.

scoreboard가 비교를 하려면 원칙적으로 아래 두 가지가 필요하다.

- monitor가 넘겨주는 `actual`
- 순서대로 꺼내 비교할 `expected`

따라서 `expected_q`를 미리 준비해 두고,
`pop_front()`로 하나씩 소비하는 방식 자체는 매우 자연스럽다.

즉, 아래 감각은 맞다.

> scoreboard는 expected stream을 내부에 준비해 두고,
> actual이 들어올 때마다 순서대로 비교한다.

### 4. 핵심 문제는 `expected_q`의 공급자다

현재 어색함의 핵심은
`expected_q`가 존재한다는 점이 아니라,
그 queue를 **누가 채우느냐**에 있다.

이상적으로는:

- `actual`은 monitor가 scoreboard에 전달
- `expected`는 sequence 또는 test가 scoreboard에 전달

이어야 한다.

그런데 현재 `4_scoreboard`에서는
scoreboard가 모듈 스코프 `payload`를 직접 읽어서
자기 내부 `expected_q`를 채우고 있다.

즉, scoreboard가 비교만 하는 것이 아니라
expected source까지 직접 소유하는 상태다.

---

## 그런데 왜 어색하게 느껴지는가

핵심은 아래 한 문장으로 정리된다.

> `expected_q`를 미리 준비하는 것 자체는 맞다.
> 문제는 scoreboard가 그 `expected_q`를 스스로 채우고 있다는 점이다.

이 때문에 다음과 같은 어색함이 생긴다.

### 1. `actual` 경로는 이미 분리되었다

현재 `actual` 쪽 데이터 흐름은 꽤 자연스럽다.

- `recv_byte()`가 monitor 역할을 수행
- monitor가 `mon_data`를 채움
- `mon_data_ready` event로 scoreboard를 깨움
- scoreboard가 `actual`을 읽어 비교

즉,

```text
monitor(recv_byte) -> scoreboard
```

구조는 이미 잡혀 있다.

### 2. `expected` 경로는 아직 분리되지 않았다

반면 `expected` 쪽은 원래 아래처럼 되는 것이 더 자연스럽다.

```text
sequence/test -> scoreboard
```

하지만 현재는 sequence를 별도로 두지 않았고,
TB에 `payload`가 이미 정의되어 있으니
scoreboard가 그 값을 직접 가져다 `expected_q`를 채우고 있다.

즉, 구조적으로는 아래와 같다.

```text
scoreboard -> payload 직접 참조 -> expected_q 생성
```

이 부분이 역할 분리를 덜 끝낸 느낌을 만든다.

### 3. 그래서 `4_scoreboard`는 "반쯤 분리된 단계"다

현재 상태를 가장 정확하게 말하면 이렇다.

- `monitor ↔ scoreboard` 분리: 됨
- `sequence/test ↔ scoreboard` 분리: 아직 안 됨

즉, `4_scoreboard`는 틀린 코드가 아니라
역할 분리가 절반 정도 진행된 과도기 단계다.

이 코드는 아마 아래 흐름으로 이해하면 자연스럽다.

1. `3_fork`
   monitor 내부에 check가 섞여 있음
2. `4_scoreboard`
   actual path 분리 완료, expected source는 아직 payload 직참조
3. `5_queue`
   actual buffering 개선
4. `6_uvm_inspired`
   expected/actual 경로를 더 명시적으로 분리

---

## 현재 합의된 해석

현재 `4_scoreboard`는 아래처럼 이해하는 것이 가장 정확하다.

- 문법적으로는 문제없다
- 시뮬레이션 타이밍상으로도 문제없다
- `expected_q`를 미리 준비하는 발상 자체도 맞다
- 문제는 scoreboard가 `expected_q`의 소비자이면서 동시에 공급자 역할도 하고 있다는 점이다
- 따라서 이 단계는 `scoreboard 개념 소개용`으로는 좋지만, 구조적으로는 아직 덜 분리된 상태다

한 문장으로 줄이면:

> `4_scoreboard`는 actual path는 분리됐지만,
> expected path는 아직 분리되지 않은 과도기 단계다.

---

## Claude 답변 요약과 해석

Claude의 답변 핵심은 아래와 같았다.

- 이 코드는 잘못됐다기보다 불완전하다
- `monitor ↔ scoreboard` 분리는 됐다
- `sequence ↔ scoreboard` 분리는 아직 안 됐다
- 따라서 `4_scoreboard`의 한계로 보는 것이 맞다
- 코드를 굳이 지금 고치기보다, 주석으로 한계를 명시하고 다음 단계에서 해결해도 된다

이 답변은 현재 이해와 잘 맞는다.

- `expected_q`는 필요하다
- 다만 그 `expected_q`를 scoreboard가 직접 `payload`에서 채우는 것이 과도기적이다
- 즉, 문제는 queue가 아니라 ownership이다

---

## 메모용 짧은 요약

아래 문단은 나중에 다시 설명할 때 써먹을 수 있는 요약본이다.

```text
UART TX 4_scoreboard에서 expected_q를 미리 준비해 두는 것 자체는 맞다.
scoreboard는 actual과 expected를 순서대로 비교해야 하므로 expected stream이 필요하기 때문이다.
문제는 expected_q의 존재가 아니라 그 공급자다.
현재는 sequence/test가 expected를 넘겨주는 대신 scoreboard가 module-scope payload를 직접 읽어 expected_q를 채우고 있다.
즉 4_scoreboard는 actual path는 분리됐지만 expected path는 아직 분리되지 않은 과도기 단계다.
```

---

## 결론

내가 헷갈린 포인트는 이제 더 명확해졌다.

- `expected_q`를 준비하는 것 자체는 맞다
- `payload`가 module scope라서 scoreboard가 읽을 수 있는 것도 맞다
- 하지만 scoreboard가 expected source까지 직접 소유하는 것은 역할 분리가 덜 된 상태다

즉, 핵심은 문법이나 타이밍이 아니라
`payload ownership`과 `scoreboard responsibility`의 분리가 아직 완성되지 않았다는 점이다.
