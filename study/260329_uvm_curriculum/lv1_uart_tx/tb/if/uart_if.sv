// =============================================================================
// uart_if.sv
// Interface between TB and uart_tx DUT
// Parameters hardcoded — iverilog does not support parameterized virtual if
// =============================================================================

`timescale 1ns/1ps

interface uart_if (
    input logic clk,
    input logic rst_n
);

    // CPU side signals
    logic [7:0] tx_data;
    logic       tx_valid;
    logic       tx_ready;

    // Serial output
    logic       tx_serial;

    // -------------------------------------------------------------------------
    // Clocking blocks
    // -------------------------------------------------------------------------
    clocking cb_drv @(posedge clk);
        default input #1step output #1;
        output tx_data;
        output tx_valid;
        input  tx_ready;
    endclocking

    clocking cb_mon @(posedge clk);
        default input #1step;
        input tx_serial;
        input tx_ready;
        input tx_valid;
        input tx_data;
    endclocking

    modport drv_mp (clocking cb_drv, input clk, input rst_n);
    modport mon_mp (clocking cb_mon, input clk, input rst_n, input tx_serial);

endinterface
