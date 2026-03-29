// =============================================================================
// tb_top.sv  —  UART TX UVM-inspired Testbench (iverilog compatible)
//
// UVM 구조 대응:
//   drv_q          → sequence에서 driver로 가는 mailbox
//   mon_q          → monitor에서 scoreboard로 가는 analysis port
//   exp_q          → expected value queue
//   task driver    → uvm_driver::run_phase
//   task monitor   → uvm_monitor::run_phase
//   task scoreboard→ uvm_scoreboard::run_phase
// =============================================================================

`timescale 1ns/1ps

module tb_top;

    // -------------------------------------------------------------------------
    // Parameters
    // -------------------------------------------------------------------------
    localparam int CLK_FREQ     = 50_000_000;
    localparam int BAUD_RATE    = 115_200;
    localparam int CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;

    // -------------------------------------------------------------------------
    // Clock & Reset
    // -------------------------------------------------------------------------
    logic clk;
    logic rst_n;

    initial clk = 0;
    always #10 clk = ~clk;   // 50 MHz

    initial begin
        rst_n = 0;
        repeat (5) @(posedge clk);
        rst_n = 1;
    end

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
    uart_tx #(
        .CLK_FREQ  (CLK_FREQ),
        .BAUD_RATE (BAUD_RATE)
    ) u_dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .tx_data   (tx_data),
        .tx_valid  (tx_valid),
        .tx_ready  (tx_ready),
        .tx_serial (tx_serial)
    );

    // -------------------------------------------------------------------------
    // VCD dump
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("uart_tx.vcd");
        $dumpvars(0, tb_top);
    end

    // -------------------------------------------------------------------------
    // Inter-task queues  (mailbox 역할)
    // -------------------------------------------------------------------------
    logic [7:0] drv_q[$];   // sequence → driver
    logic [7:0] mon_q[$];   // monitor  → scoreboard
    logic [7:0] exp_q[$];   // expected value

    int pass_cnt = 0;
    int fail_cnt = 0;

    // -------------------------------------------------------------------------
    // DRIVER  (uvm_driver::run_phase)
    // drv_q에서 바이트를 꺼내 DUT tx_data/tx_valid 구동
    // -------------------------------------------------------------------------
    task automatic uart_driver(int num_bytes);
        logic [7:0] data;
        repeat (num_bytes) begin
            // sequence가 item을 넣을 때까지 대기
            wait (drv_q.size() > 0);
            data = drv_q.pop_front();
            $display("[DRV] driving: 0x%02h", data);

            // tx_ready 대기
            @(posedge clk);
            while (!tx_ready) @(posedge clk);

            // 1사이클 pulse
            tx_data  <= data;
            tx_valid <= 1'b1;
            @(posedge clk);
            tx_valid <= 1'b0;

            // 전송 완료 대기
            @(posedge clk);
            while (!tx_ready) @(posedge clk);
        end
    endtask

    // -------------------------------------------------------------------------
    // MONITOR  (uvm_monitor::run_phase)
    // tx_serial 비트스트림 샘플링 → 바이트 복원 → mon_q push
    // -------------------------------------------------------------------------
    task automatic uart_monitor(int num_bytes);
        logic [7:0] captured;
        repeat (num_bytes) begin
            // start bit 감지 (1→0 edge)
            @(negedge tx_serial);

            // start bit 시작 → 1.5 baud 후 = bit[0] 중앙
            repeat (CLKS_PER_BIT + CLKS_PER_BIT / 2) @(posedge clk);

            // 8 data bit 샘플링 (LSB first)
            for (int i = 0; i < 8; i++) begin
                captured[i] = tx_serial;
                if (i < 7) repeat (CLKS_PER_BIT) @(posedge clk);
            end

            // stop bit 위치 확인
            repeat (CLKS_PER_BIT) @(posedge clk);
            if (tx_serial !== 1'b1)
                $display("[MON] WARNING: framing error");

            $display("[MON] captured: 0x%02h", captured);
            mon_q.push_back(captured);
        end
    endtask

    // -------------------------------------------------------------------------
    // SCOREBOARD  (uvm_scoreboard::run_phase)
    // mon_q actual vs exp_q expected 비교
    // -------------------------------------------------------------------------
    task automatic uart_scoreboard(int num_bytes);
        logic [7:0] actual;
        logic [7:0] expected;
        repeat (num_bytes) begin
            wait (mon_q.size() > 0);
            actual   = mon_q.pop_front();
            expected = exp_q.pop_front();
            if (actual === expected) begin
                $display("[SB]  PASS: expected=0x%02h  actual=0x%02h", expected, actual);
                pass_cnt++;
            end else begin
                $display("[SB]  FAIL: expected=0x%02h  actual=0x%02h", expected, actual);
                fail_cnt++;
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // TEST payload (모듈 레벨 선언 — iverilog는 initial 내부 초기화 미지원)
    // -------------------------------------------------------------------------
    logic [7:0] payload [0:4];
    localparam int N = 5;

    // -------------------------------------------------------------------------
    // TEST  (uvm_test::run_phase)
    // -------------------------------------------------------------------------
    initial begin
        // payload: "Hello"
        payload[0] = 8'h48;  // 'H'
        payload[1] = 8'h65;  // 'e'
        payload[2] = 8'h6c;  // 'l'
        payload[3] = 8'h6c;  // 'l'
        payload[4] = 8'h6f;  // 'o'

        tx_valid = 0;
        tx_data  = 0;

        // reset 완료 대기
        @(posedge rst_n);
        @(posedge clk);

        // sequence: payload → drv_q + exp_q 적재
        foreach (payload[i]) begin
            drv_q.push_back(payload[i]);
            exp_q.push_back(payload[i]);
            $display("[SEQ] queued: 0x%02h", payload[i]);
        end

        $display("[TEST] ============================");
        $display("[TEST] UART TX Smoke Test Start");
        $display("[TEST] Payload: Hello (%0d bytes)", N);
        $display("[TEST] BAUD_RATE=%0d  CLKS_PER_BIT=%0d", BAUD_RATE, CLKS_PER_BIT);
        $display("[TEST] ============================");

        // driver / monitor / scoreboard 병렬 실행
        fork
            uart_driver(N);
            uart_monitor(N);
            uart_scoreboard(N);
        join

        // 최종 리포트
        $display("[SB]  ===== SCOREBOARD REPORT =====");
        $display("[SB]  PASS: %0d  FAIL: %0d", pass_cnt, fail_cnt);
        if (fail_cnt == 0)
            $display("[SB]  *** ALL TESTS PASSED ***");
        else
            $display("[SB]  *** %0d TEST(S) FAILED ***", fail_cnt);

        $display("[TEST] ============================");
        $display("[TEST] Smoke Test Done");
        $display("[TEST] ============================");

        $finish;
    end

endmodule
