`timescale 1ns/1ps

// =============================================================================
// 3_fork : fork/join 병렬 실행
//
// 2_task 대비 변화:
//   - send_byte 가 전송 완료까지 대기한다 (tx_ready 복귀 확인)
//   - fork/join 으로 driver / monitor 병렬 실행
//   - "Hello" 5바이트로 확장
//
// 한계:
//   - driver 와 monitor 가 직접 변수를 공유한다.
//     바이트 수가 늘면 타이밍 관리가 복잡해진다.
//   - pass/fail 판정이 monitor 내부에 섞여 있다.
//     → 비교 로직을 분리한 scoreboard 가 필요한 이유.
// =============================================================================

module tb_top;

    localparam int CLK_FREQ     = 50_000_000;
    localparam int BAUD_RATE    = 115_200;
    localparam int CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;

    logic clk  = 0;
    logic rst_n;
    always #10 clk = ~clk;

    logic [7:0] tx_data;
    logic       tx_valid;
    logic       tx_ready;
    logic       tx_serial;

    UART_Tx #(
        .CLK_FREQ  (CLK_FREQ),
        .BAUD_RATE (BAUD_RATE)
    ) A_UART_Tx (
        .iClk     (clk),
        .iRsn     (rst_n),
        .iTxData  (tx_data),
        .iTxValid (tx_valid),
        .oTxReady (tx_ready),
        .oTxSerial(tx_serial)
    );

    initial begin
        $dumpfile("uart_tx.vcd");
        $dumpvars(0, tb_top);
    end

    // -------------------------------------------------------------------------
    // task: send_byte
    // 전송 완료(tx_ready 복귀)까지 대기
    // -------------------------------------------------------------------------
    task send_byte(input logic [7:0] data);
        @(posedge clk);
        while (!tx_ready) @(posedge clk);
        tx_data  = data;
        tx_valid = 1'b1;
        @(posedge clk);
        tx_valid = 1'b0;
    endtask

    // -------------------------------------------------------------------------
    // task: recv_and_check
    // 수신 + pass/fail 판정 (scoreboard 역할이 monitor 에 섞인 상태)
    // -------------------------------------------------------------------------
    task recv_and_check(input logic [7:0] expected);
        logic [7:0] captured;
        @(negedge tx_serial);
        repeat (CLKS_PER_BIT + CLKS_PER_BIT / 2) @(posedge clk);
        for (int i = 0; i < 8; i++) begin
            captured[i] = tx_serial;
            if (i < 7) repeat (CLKS_PER_BIT) @(posedge clk);
        end
        if (captured === expected)
            $display("PASS: expected=0x%02h  captured=0x%02h", expected, captured);
        else
            $display("FAIL: expected=0x%02h  captured=0x%02h", expected, captured);
    endtask

    // -------------------------------------------------------------------------
    // Test payload
    // -------------------------------------------------------------------------
    logic [7:0] payload [0:4];
    localparam int N = 5;

    initial begin
        payload[0] = 8'h48;  // 'H'
        payload[1] = 8'h65;  // 'e'
        payload[2] = 8'h6c;  // 'l'
        payload[3] = 8'h6c;  // 'l'
        payload[4] = 8'h6f;  // 'o'
    end

    initial begin
        rst_n    = 0;
        tx_valid = 0;
        tx_data  = 0;
        repeat (5) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        // driver 와 monitor 를 병렬로 실행
        fork
            begin // driver
                foreach (payload[i]) send_byte(payload[i]);
            end
            begin // monitor
                foreach (payload[i]) recv_and_check(payload[i]);
            end
        join

        repeat (5 * CLKS_PER_BIT) @(posedge clk);
        $finish;
    end

endmodule
