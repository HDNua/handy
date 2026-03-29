`timescale 1ns/1ps

// =============================================================================
// 4_scoreboard : scoreboard task 분리
//
// 3_fork 대비 변화:
//   - recv_and_check 를 recv_byte(monitor) 와 scoreboard 로 분리
//   - monitor 는 수신만, scoreboard 는 비교만 담당
//   - 데이터 전달은 공유 변수 + event 로 직접 연결
//
// 한계 (이 단계는 이해를 위한 코드이며 실제 구현 방식이 아님):
//   - 공유 변수가 1개라서 monitor 가 다음 바이트를 쓰기 전에
//     scoreboard 가 읽어야 한다. 타이밍 의존성이 생긴다.
//   - 바이트 수가 늘거나 속도가 달라지면 덮어쓰기 위험이 있다.
//     → 공유 변수 대신 queue 가 필요한 이유.
//   - scoreboard 가 payload 를 직접 참조해서 expected 를 만든다.
//     scoreboard 는 비교만 해야 하며, expected 는 sequence 가 분배해줘야 한다.
//     → sequence 가 drv_q / exp_q 로 분배하는 구조가 필요한 이유.
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
    // monitor → scoreboard 공유 변수 + event
    // -------------------------------------------------------------------------
    logic [7:0] mon_data;       // monitor 가 수신한 바이트
    event       mon_data_ready; // monitor 가 데이터를 쓴 뒤 scoreboard 를 깨움

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
    // 수신만 담당 — 공유 변수에 쓰고 event 트리거
    // -------------------------------------------------------------------------
    task recv_byte();
        logic [7:0] captured;
        @(negedge tx_serial);
        repeat (CLKS_PER_BIT + CLKS_PER_BIT / 2) @(posedge clk);
        for (int i = 0; i < 8; i++) begin
            captured[i] = tx_serial;
            if (i < 7) repeat (CLKS_PER_BIT) @(posedge clk);
        end
        mon_data = captured;
        ->mon_data_ready;
    endtask

    // -------------------------------------------------------------------------
    // task: scoreboard
    // 비교만 담당 — event 로 깨어나서 공유 변수 읽기
    // 주의: expected 를 payload 에서 직접 만드는 것은 올바른 구조가 아님.
    //       실제로는 sequence 가 expected 를 scoreboard 에 전달해야 한다.
    // -------------------------------------------------------------------------
    task uart_scoreboard(int num_bytes);
        logic [7:0] expected_q [$];
        logic [7:0] actual;
        logic [7:0] expected;

        // expected 미리 적재
        foreach (payload[i]) expected_q.push_back(payload[i]);

        repeat (num_bytes) begin
            @(mon_data_ready);
            actual   = mon_data;
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
