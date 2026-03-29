`timescale 1ns/1ps

// =============================================================================
// 5_queue : queue 도입
//
// 4_scoreboard 대비 변화:
//   - 공유 변수 → queue 로 교체
//   - monitor 가 queue 에 push, scoreboard 가 queue 에서 pop
//   - 덮어쓰기 위험 없음. 바이트가 쌓여도 순서대로 처리됨
//
// 한계:
//   - driver 는 여전히 payload 를 직접 알고 있다.
//     sequence 가 payload 를 만들어 driver 에게 넘기는 구조가 아직 없다.
//   - scoreboard 의 expected 도 payload 를 직접 참조한다.
//     → sequence 가 payload 를 관리하고 driver/scoreboard 에 분배하는
//       구조가 필요한 이유. (4_uvm_inspired 의 drv_q / exp_q)
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
    // monitor → scoreboard queue + event
    // -------------------------------------------------------------------------
    logic [7:0] mon_q[$];       // monitor 가 push, scoreboard 가 pop
    event       mon_data_ready; // monitor 가 push 후 scoreboard 를 깨움

    int pass_cnt = 0;
    int fail_cnt = 0;

    // -------------------------------------------------------------------------
    // task: send_byte (driver)
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
    // task: recv_byte (monitor)
    // 수신 후 queue 에 push
    // -------------------------------------------------------------------------
    task recv_byte();
        logic [7:0] captured;
        @(negedge tx_serial);
        repeat (CLKS_PER_BIT + CLKS_PER_BIT / 2) @(posedge clk);
        for (int i = 0; i < 8; i++) begin
            captured[i] = tx_serial;
            if (i < 7) repeat (CLKS_PER_BIT) @(posedge clk);
        end
        mon_q.push_back(captured);
        ->mon_data_ready;
    endtask

    // -------------------------------------------------------------------------
    // task: scoreboard
    // queue 에서 pop 해서 비교
    // -------------------------------------------------------------------------
    task uart_scoreboard(int num_bytes);
        logic [7:0] expected_q [$];
        logic [7:0] actual;
        logic [7:0] expected;

        foreach (payload[i]) expected_q.push_back(payload[i]);

        repeat (num_bytes) begin
            @(mon_data_ready);
            actual   = mon_q.pop_front();
            expected = expected_q.pop_front();
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

        fork
            begin // driver
                foreach (payload[i]) send_byte(payload[i]);
            end
            begin // monitor
                repeat (N) recv_byte();
            end
            begin // scoreboard
                uart_scoreboard(N);
            end
        join

        $display("[SB]  ===== REPORT =====");
        $display("[SB]  PASS: %0d  FAIL: %0d", pass_cnt, fail_cnt);
        if (fail_cnt == 0) $display("[SB]  *** ALL TESTS PASSED ***");

        repeat (5 * CLKS_PER_BIT) @(posedge clk);
        $finish;
    end

endmodule
