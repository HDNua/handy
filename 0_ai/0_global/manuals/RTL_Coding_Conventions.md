# RTL 코딩 컨벤션

공용 규칙서 — Claude, Codex, Antigravity 등 모든 AI 도구에 공통 적용

---

## 1. 포트 네이밍

| 종류 | 접두사 | 예시 |
|---|---|---|
| clock | `iClk` | `iClk` |
| reset (active low) | `iRsn` | `iRsn` |
| input | `i` | `iTxData`, `iTxValid` |
| output | `o` | `oTxReady`, `oTxSerial` |

## 2. 내부 신호 네이밍

| 종류 | 접두사 | 예시 |
|---|---|---|
| reg (FF 구동) | `r` | `rState`, `rBaudCnt`, `rShiftReg` |
| wire (조합 논리) | `w` | `wNextState`, `wSum` |

## 3. 모듈 및 인스턴스 네이밍

| 종류 | 규칙 | 예시 |
|---|---|---|
| 모듈 이름 | 파스칼 케이스 + 언더스코어 구분 | `UART_Tx`, `I2C_Master` |
| 인스턴스 이름 | `A_` 접두사 | `A_UART_Tx`, `A_I2C_Master` |

## 4. 주석

- 기본적으로 **한국어**로 작성
