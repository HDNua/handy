// =============================================================================
// uart_tx.sv — UART 송신기
//
// 파라미터:
//   CLK_FREQ  : 시스템 클럭 주파수 (Hz, 기본 50MHz)
//   BAUD_RATE : 전송 속도 (기본 115200)
//
// 네이밍 규칙:
//   iClk/iRsn : 클럭/리셋
//   i*        : 입력 포트
//   o*        : 출력 포트
//   r*        : 내부 레지스터 (FF 구동)
//
// 프레임 포맷: start(0) + 데이터 8비트(LSB first) + stop(1)
// =============================================================================

module UART_Tx #(
    parameter int CLK_FREQ  = 50_000_000,
    parameter int BAUD_RATE = 115_200
) (
    input  logic       iClk,
    input  logic       iRsn,

    // CPU 인터페이스
    input  logic [7:0] iTxData,
    input  logic       iTxValid,
    output logic       oTxReady,

    // 직렬 출력
    output logic       oTxSerial
);

    // -------------------------------------------------------------------------
    // Baud rate 분주
    // -------------------------------------------------------------------------
    localparam int CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;

    // -------------------------------------------------------------------------
    // FSM 상태 정의
    // -------------------------------------------------------------------------
    typedef enum logic [2:0] {
        IDLE  = 3'd0,
        START = 3'd1,
        DATA  = 3'd2,
        STOP  = 3'd3
    } state_t;

    // -------------------------------------------------------------------------
    // 내부 레지스터
    // -------------------------------------------------------------------------
    state_t                            rState;
    logic [$clog2(CLKS_PER_BIT)-1:0]  rBaudCnt;   // Baud 클럭 카운터
    logic [2:0]                        rBitIdx;    // 현재 전송 중인 비트 인덱스 (0~7)
    logic [7:0]                        rShiftReg;  // TX 시프트 레지스터

    // -------------------------------------------------------------------------
    // FSM + 데이터패스
    // -------------------------------------------------------------------------
    always_ff @(posedge iClk or negedge iRsn) begin
        if (!iRsn) begin
            rState    <= IDLE;
            rBaudCnt  <= '0;
            rBitIdx   <= '0;
            rShiftReg <= '0;
            oTxSerial <= 1'b1;   // idle: 선을 high로 유지
            oTxReady  <= 1'b1;
        end else begin
            case (rState)

                IDLE: begin
                    oTxSerial <= 1'b1;
                    oTxReady  <= 1'b1;
                    rBaudCnt  <= '0;
                    rBitIdx   <= '0;
                    if (iTxValid) begin
                        rShiftReg <= iTxData;
                        oTxReady  <= 1'b0;
                        rState    <= START;
                    end
                end

                START: begin
                    oTxSerial <= 1'b0;   // start bit
                    if (rBaudCnt == CLKS_PER_BIT - 1) begin
                        rBaudCnt <= '0;
                        rState   <= DATA;
                    end else begin
                        rBaudCnt <= rBaudCnt + 1;
                    end
                end

                DATA: begin
                    oTxSerial <= rShiftReg[rBitIdx];   // LSB first 직렬 출력
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

                STOP: begin
                    oTxSerial <= 1'b1;   // stop bit
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
