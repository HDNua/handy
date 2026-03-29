// =============================================================================
// smoke_test.sv — "Hello" 5바이트 전송 smoke test
// =============================================================================

import uart_pkg::*;

task run_test(virtual uart_if vif);

    logic [7:0] payload [] = '{
        8'h48,   // 'H'
        8'h65,   // 'e'
        8'h6c,   // 'l'
        8'h6c,   // 'l'
        8'h6f    // 'o'
    };

    int num_bytes = payload.size();

    uart_env      env = new(vif);
    uart_sequence seq = new(env.agent.get_seq_mbx(), payload);

    foreach (payload[i])
        env.scoreboard.push_expected(payload[i]);

    $display("[TEST] ============================");
    $display("[TEST] UART TX Smoke Test Start");
    $display("[TEST] Payload: Hello (%0d bytes)", num_bytes);
    $display("[TEST] BAUD_RATE=%0d  CLKS_PER_BIT=%0d", BAUD_RATE, CLKS_PER_BIT);
    $display("[TEST] ============================");

    fork
        seq.run();
        env.agent.driver.run(num_bytes);
        begin
            env.agent.monitor.run(num_bytes);
            foreach (payload[i]) env.coverage.sample(payload[i]);
        end
        env.scoreboard.run(num_bytes);
    join

    env.scoreboard.report();
    env.coverage.report();

    $display("[TEST] ============================");
    $display("[TEST] Smoke Test Done");
    $display("[TEST] ============================");

endtask
