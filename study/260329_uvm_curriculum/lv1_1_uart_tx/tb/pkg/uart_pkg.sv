// =============================================================================
// uart_pkg.sv
// UVM-inspired TB package for uart_tx  (iverilog 13 compatible)
//
// iverilog 제약으로 인한 단순화:
//   - mailbox #(type)  → plain mailbox  (get 후 $cast 사용)
//   - virtual if param → 제거 (uart_if 파라미터 hardcode)
//   - string ops       → $sformatf 최소화
// =============================================================================

package uart_pkg;

    parameter int CLK_FREQ     = 50_000_000;
    parameter int BAUD_RATE    = 115_200;
    parameter int CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;

    // =========================================================================
    // uart_seq_item
    // =========================================================================
    class uart_seq_item;
        logic [7:0] data;

        function new(logic [7:0] d = 8'h00);
            this.data = d;
        endfunction
    endclass


    // =========================================================================
    // uart_sequence
    // =========================================================================
    class uart_sequence;
        mailbox mbx;
        logic [7:0] payload [];

        function new(mailbox m, logic [7:0] data[]);
            this.mbx     = m;
            this.payload = data;
        endfunction

        task run();
            foreach (payload[i]) begin
                uart_seq_item item = new(payload[i]);
                mbx.put(item);
                $display("[SEQ] queued: data=0x%02h", payload[i]);
            end
        endtask
    endclass


    // =========================================================================
    // uart_driver
    // =========================================================================
    class uart_driver;
        mailbox      mbx;
        virtual uart_if vif;

        function new(mailbox m, virtual uart_if v);
            this.mbx = m;
            this.vif = v;
        endfunction

        task run(int num_items);
            repeat (num_items) begin
                uart_seq_item item;
                $cast(item, mbx.get());
                $display("[DRV] driving: data=0x%02h", item.data);

                // tx_ready 대기
                @(posedge vif.clk);
                while (!vif.tx_ready) @(posedge vif.clk);

                // tx_data + tx_valid 1사이클 pulse
                @(posedge vif.clk);
                vif.tx_data  <= item.data;
                vif.tx_valid <= 1'b1;
                @(posedge vif.clk);
                vif.tx_valid <= 1'b0;

                // 전송 완료 대기
                @(posedge vif.clk);
                while (!vif.tx_ready) @(posedge vif.clk);
            end
        endtask
    endclass


    // =========================================================================
    // uart_monitor
    // tx_serial 비트스트림 샘플링 → 바이트 복원
    // =========================================================================
    class uart_monitor;
        mailbox      mbx;
        virtual uart_if vif;

        function new(mailbox m, virtual uart_if v);
            this.mbx = m;
            this.vif = v;
        endfunction

        task run(int num_bytes);
            logic [7:0] captured;
            repeat (num_bytes) begin
                // start bit 감지 (1→0)
                @(negedge vif.tx_serial);

                // start bit 중앙 이동 후 첫 data bit 중앙까지
                // start 시작 → 1.5 * CLKS_PER_BIT 후 = bit[0] 중앙
                repeat (CLKS_PER_BIT + CLKS_PER_BIT / 2) @(posedge vif.clk);

                // 8 data bit 샘플링 (LSB first)
                for (int i = 0; i < 8; i++) begin
                    captured[i] = vif.tx_serial;
                    if (i < 7) repeat (CLKS_PER_BIT) @(posedge vif.clk);
                end

                // stop bit 확인
                repeat (CLKS_PER_BIT) @(posedge vif.clk);
                if (vif.tx_serial !== 1'b1)
                    $display("[MON] WARNING: framing error (stop bit not high)");

                $display("[MON] captured: 0x%02h", captured);
                mbx.put(captured);
            end
        endtask
    endclass


    // =========================================================================
    // uart_scoreboard
    // =========================================================================
    class uart_scoreboard;
        mailbox      mbx;
        logic [7:0]  expected_q [$];
        int          pass_cnt;
        int          fail_cnt;

        function new(mailbox m);
            this.mbx      = m;
            this.pass_cnt = 0;
            this.fail_cnt = 0;
        endfunction

        function void push_expected(logic [7:0] data);
            expected_q.push_back(data);
        endfunction

        task run(int num_bytes);
            logic [7:0] actual;
            logic [7:0] exp;
            repeat (num_bytes) begin
                $cast(actual, mbx.get());
                if (expected_q.size() == 0) begin
                    $display("[SB]  ERROR: expected queue empty");
                    fail_cnt++;
                end else begin
                    exp = expected_q.pop_front();
                    if (actual === exp) begin
                        $display("[SB]  PASS: expected=0x%02h actual=0x%02h", exp, actual);
                        pass_cnt++;
                    end else begin
                        $display("[SB]  FAIL: expected=0x%02h actual=0x%02h", exp, actual);
                        fail_cnt++;
                    end
                end
            end
        endtask

        function void report();
            $display("[SB]  ===== SCOREBOARD REPORT =====");
            $display("[SB]  PASS: %0d  FAIL: %0d", pass_cnt, fail_cnt);
            if (fail_cnt == 0)
                $display("[SB]  *** ALL TESTS PASSED ***");
            else
                $display("[SB]  *** %0d TEST(S) FAILED ***", fail_cnt);
        endfunction
    endclass


    // =========================================================================
    // uart_coverage
    // =========================================================================
    class uart_coverage;
        logic [7:0] sampled_byte;

        covergroup cg_uart_tx;
            cp_byte_range: coverpoint sampled_byte {
                bins null_byte = {8'h00};
                bins lower     = {[8'h01 : 8'h1f]};
                bins printable = {[8'h20 : 8'h7e]};
                bins upper     = {[8'h7f : 8'hfe]};
                bins all_ones  = {8'hff};
            }
        endgroup

        function new();
            cg_uart_tx = new();
        endfunction

        function void sample(logic [7:0] data);
            sampled_byte = data;
            cg_uart_tx.sample();
        endfunction

        function void report();
            $display("[COV] uart_tx byte coverage: %.1f%%", cg_uart_tx.get_coverage());
        endfunction
    endclass


    // =========================================================================
    // uart_agent
    // =========================================================================
    class uart_agent;
        uart_driver  driver;
        uart_monitor monitor;
        mailbox      drv_mbx;

        function new(virtual uart_if vif, mailbox sb_mbx);
            drv_mbx = new();
            driver  = new(drv_mbx, vif);
            monitor = new(sb_mbx, vif);
        endfunction

        function mailbox get_seq_mbx();
            return drv_mbx;
        endfunction
    endclass


    // =========================================================================
    // uart_env
    // =========================================================================
    class uart_env;
        uart_agent      agent;
        uart_scoreboard scoreboard;
        uart_coverage   coverage;
        mailbox         sb_mbx;

        function new(virtual uart_if vif);
            sb_mbx     = new();
            scoreboard = new(sb_mbx);
            coverage   = new();
            agent      = new(vif, sb_mbx);
        endfunction
    endclass

endpackage
