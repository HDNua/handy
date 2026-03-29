// =============================================================================
// UART_Tx.sv — UART 송신기 (Transmitter)
//
// -----------------------------------------------------------------------------
// UART (Universal Asynchronous Receiver Transmitter) 개요
// -----------------------------------------------------------------------------
//
// UART는 두 장치가 클럭 선 없이 미리 약속한 속도(baud rate)로
// 1비트씩 직렬로 데이터를 주고받는 비동기 통신 방식이다.
//
// "비동기(Asynchronous)"의 의미:
//   - SPI/I2C처럼 클럭 선을 공유하지 않는다.
//   - 대신 송신측과 수신측이 동일한 baud rate를 사전에 약속한다.
//   - 수신측은 start bit의 하강 엣지를 감지한 뒤, 약속된 간격으로 비트를 샘플링한다.
//
// -----------------------------------------------------------------------------
// 프레임 구조
// -----------------------------------------------------------------------------
//
//  idle  START  D0  D1  D2  D3  D4  D5  D6  D7  STOP  idle
//   1  [  0  ][ LSB                        MSB][  1  ]  1
//
//  - idle  : 전송 없을 때 선은 HIGH(1)를 유지
//  - START : 1비트, 항상 LOW(0). "데이터 전송 시작" 신호
//  - DATA  : 8비트, LSB(D0)부터 MSB(D7) 순서로 전송
//  - STOP  : 1비트, 항상 HIGH(1). "전송 완료" 신호, 선을 idle 상태로 복귀
//
// 수신측 샘플링 타이밍:
//   START 하강 엣지 감지 → 1.5 baud 후 D0 샘플 → 이후 1 baud 간격으로 D1~D7 샘플
//
// -----------------------------------------------------------------------------
// Baud Rate 와 CLKS_PER_BIT
// -----------------------------------------------------------------------------
//
//  baud rate    = 초당 전송 비트 수
//  CLKS_PER_BIT = 시스템 클럭 주파수 / baud rate
//
//  예) CLK_FREQ=50MHz, BAUD_RATE=115200
//      CLKS_PER_BIT = 50_000_000 / 115_200 = 434 사이클
//      → 1비트를 434 클럭 사이클 동안 유지
//
// -----------------------------------------------------------------------------
// FSM 동작 흐름
// -----------------------------------------------------------------------------
//
//  IDLE ──(iTxValid=1)──▶ START ──(baud 완료)──▶ DATA ──(8비트 완료)──▶ STOP ──▶ IDLE
//
//  - IDLE  : oTxSerial=1, oTxReady=1. iTxValid 감지 시 iTxData를 rShiftReg에 래치
//  - START : oTxSerial=0 (start bit). CLKS_PER_BIT 카운트 후 DATA 로 전이
//  - DATA  : rShiftReg[rBitIdx] 를 oTxSerial 에 출력 (LSB first).
//            CLKS_PER_BIT 마다 rBitIdx 증가. 7 완료 시 STOP 으로 전이
//  - STOP  : oTxSerial=1 (stop bit). CLKS_PER_BIT 카운트 후 IDLE 복귀, oTxReady=1
//
// -----------------------------------------------------------------------------
// 파라미터
// -----------------------------------------------------------------------------
//   CLK_FREQ  : 시스템 클럭 주파수 (Hz, 기본 50MHz)
//   BAUD_RATE : 전송 속도 (기본 115200)
//
// -----------------------------------------------------------------------------
// 네이밍 규칙 (0_ai/0_global/manuals/RTL_Coding_Conventions.md 참조)
// -----------------------------------------------------------------------------
//   iClk/iRsn : 클럭 / 리셋 (active low)
//   i*        : 입력 포트
//   o*        : 출력 포트
//   r*        : 내부 레지스터 (FF 구동)
// =============================================================================

module UART_Tx #(
    parameter int CLK_FREQ  = 50_000_000,
    parameter int BAUD_RATE = 115_200
) (
    input  logic       iClk,
    input  logic       iRsn,

    // CPU 인터페이스
    input  logic [7:0] iTxData,    // 전송할 1바이트 데이터
    input  logic       iTxValid,   // 1사이클 pulse: 전송 시작 요청
    output logic       oTxReady,   // HIGH: 새 데이터 수신 가능 (idle 상태)

    // 직렬 출력
    output logic       oTxSerial   // UART TX 직렬 출력 선 (idle=1)
);

    // -------------------------------------------------------------------------
    // Baud rate 분주: 1비트를 유지할 클럭 사이클 수
    // -------------------------------------------------------------------------
    localparam int CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;

    // -------------------------------------------------------------------------
    // FSM 상태 정의
    // -------------------------------------------------------------------------
    typedef enum logic [2:0] {
        IDLE  = 3'd0,   // 대기. 선 idle(1), 새 전송 요청 감시
        START = 3'd1,   // start bit 출력 (oTxSerial=0)
        DATA  = 3'd2,   // 데이터 8비트 직렬 출력 (LSB first)
        STOP  = 3'd3    // stop bit 출력 (oTxSerial=1), idle 복귀
    } state_t;

    // -------------------------------------------------------------------------
    // 내부 레지스터 (r*)
    // -------------------------------------------------------------------------
    state_t                            rState;      // 현재 FSM 상태
    logic [$clog2(CLKS_PER_BIT)-1:0]  rBaudCnt;   // baud 클럭 카운터 (0 ~ CLKS_PER_BIT-1)
    logic [2:0]                        rBitIdx;    // 현재 전송 중인 비트 인덱스 (0~7)
    logic [7:0]                        rShiftReg;  // TX 시프트 레지스터 (iTxData 래치)

    // -------------------------------------------------------------------------
    // FSM + 데이터패스
    // -------------------------------------------------------------------------
    always_ff @(posedge iClk or negedge iRsn) begin
        if (!iRsn) begin
            rState    <= IDLE;
            rBaudCnt  <= '0;
            rBitIdx   <= '0;
            rShiftReg <= '0;
            oTxSerial <= 1'b1;   // 리셋 시 idle 상태로
            oTxReady  <= 1'b1;
        end else begin
            case (rState)

                // -------------------------------------------------------------
                // IDLE: 전송 요청 대기
                // iTxValid pulse 감지 시 데이터 래치 후 START 로 전이
                // -------------------------------------------------------------
                IDLE: begin
                    oTxSerial <= 1'b1;
                    oTxReady  <= 1'b1;
                    rBaudCnt  <= '0;
                    rBitIdx   <= '0;
                    if (iTxValid) begin
                        rShiftReg <= iTxData;   // 전송 데이터 래치
                        oTxReady  <= 1'b0;      // 전송 중 → 새 요청 불가
                        rState    <= START;
                    end
                end

                // -------------------------------------------------------------
                // START: start bit (LOW) 출력
                // CLKS_PER_BIT 사이클 유지 후 DATA 로 전이
                // -------------------------------------------------------------
                START: begin
                    oTxSerial <= 1'b0;
                    if (rBaudCnt == CLKS_PER_BIT - 1) begin
                        rBaudCnt <= '0;
                        rState   <= DATA;
                    end else begin
                        rBaudCnt <= rBaudCnt + 1;
                    end
                end

                // -------------------------------------------------------------
                // DATA: 8비트 직렬 출력 (LSB first)
                // rBitIdx 0→7 순서로 rShiftReg 비트를 1비트씩 출력
                // 마지막 비트(7) 완료 후 STOP 으로 전이
                // -------------------------------------------------------------
                DATA: begin
                    oTxSerial <= rShiftReg[rBitIdx];
                    if (rBaudCnt == CLKS_PER_BIT - 1) begin
                        rBaudCnt <= '0;
                        if (rBitIdx == 3'd7) begin
                            rBitIdx <= '0;
                            rState  <= STOP;
                        end else begin
                            rBitIdx <= rBitIdx + 1;
                        end
                    end else begin
                        rBaudCnt <= rBaudCnt + 1;
                    end
                end

                // -------------------------------------------------------------
                // STOP: stop bit (HIGH) 출력
                // CLKS_PER_BIT 사이클 유지 후 IDLE 로 복귀, oTxReady=1
                // -------------------------------------------------------------
                STOP: begin
                    oTxSerial <= 1'b1;
                    if (rBaudCnt == CLKS_PER_BIT - 1) begin
                        rBaudCnt <= '0;
                        rState   <= IDLE;
                        oTxReady <= 1'b1;
                    end else begin
                        rBaudCnt <= rBaudCnt + 1;
                    end
                end

                default: rState <= IDLE;

            endcase
        end
    end

endmodule
