`timescale 1ns/1ps

module tb_top;

    localparam int CLK_FREQ     = 50_000_000;
    localparam int BAUD_RATE    = 115_200;
    localparam int CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;

    // -------------------------------------------------------------------------
    // Clock & Reset
    // -------------------------------------------------------------------------
    logic clk  = 0;
    logic rst_n;
    always #10 clk = ~clk;   // 50 MHz

    // -------------------------------------------------------------------------
    // DUT signals
    // -------------------------------------------------------------------------
    logic [7:0] tx_data;
    logic       tx_valid;
    logic       tx_ready;
    logic       tx_serial;

    // -------------------------------------------------------------------------
    // DUT
    // -------------------------------------------------------------------------
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

    // -------------------------------------------------------------------------
    // VCD dump
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("uart_tx.vcd");
        $dumpvars(0, tb_top);
    end

    // -------------------------------------------------------------------------
    // Test
    // -------------------------------------------------------------------------
    logic [7:0] captured;

    initial begin
        // reset
        rst_n   = 0;
        tx_valid = 0;
        tx_data  = 0;
        repeat (5) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        // --- 전송 요청 ---
        tx_data  = 8'h48;   // 'H'
        tx_valid = 1'b1;
        @(posedge clk);
        tx_valid = 1'b0;

        // --- 수신 (inline 모니터링) ---
        // start bit 감지
        while (tx_serial !== 1'b0) @(posedge clk);

        // 1.5 baud 후 → D0 중앙
        repeat (CLKS_PER_BIT + CLKS_PER_BIT / 2) @(posedge clk);

        // 8비트 샘플링
        for (int i = 0; i < 8; i++) begin
            captured[i] = tx_serial;
            if (i < 7) repeat (CLKS_PER_BIT) @(posedge clk);
        end

        // --- 결과 확인 ---
        if (captured === 8'h48)
            $display("PASS: captured=0x%02h", captured);
        else
            $display("FAIL: expected=0x48  captured=0x%02h", captured);

        $finish;
    end

endmodule
