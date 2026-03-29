// =============================================================================
// uart_tx.sv
// Simple UART Transmitter
//
// Parameters:
//   CLK_FREQ  : system clock frequency in Hz (default 50MHz)
//   BAUD_RATE : baud rate (default 115200)
//
// Interface:
//   tx_data   : 8-bit data to transmit
//   tx_valid  : pulse high 1 cycle to start transmission
//   tx_ready  : high when idle (ready to accept new data)
//   tx_serial : serial output line (idle = 1)
//
// Frame format: 1 start bit (0), 8 data bits (LSB first), 1 stop bit (1)
// =============================================================================

module uart_tx #(
    parameter int CLK_FREQ  = 50_000_000,
    parameter int BAUD_RATE = 115_200
) (
    input  logic       clk,
    input  logic       rst_n,

    // CPU interface
    input  logic [7:0] tx_data,
    input  logic       tx_valid,
    output logic       tx_ready,

    // Serial output
    output logic       tx_serial
);

    // -------------------------------------------------------------------------
    // Baud rate divider
    // -------------------------------------------------------------------------
    localparam int CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;

    // -------------------------------------------------------------------------
    // FSM states
    // -------------------------------------------------------------------------
    typedef enum logic [2:0] {
        IDLE  = 3'd0,
        START = 3'd1,
        DATA  = 3'd2,
        STOP  = 3'd3
    } state_t;

    state_t state;

    // -------------------------------------------------------------------------
    // Internal registers
    // -------------------------------------------------------------------------
    logic [$clog2(CLKS_PER_BIT)-1:0] baud_cnt;   // baud clock counter
    logic [2:0]                        bit_idx;    // current data bit index (0~7)
    logic [7:0]                        shift_reg;  // TX shift register

    // -------------------------------------------------------------------------
    // FSM + datapath
    // -------------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= IDLE;
            baud_cnt  <= '0;
            bit_idx   <= '0;
            shift_reg <= '0;
            tx_serial <= 1'b1;   // idle line high
            tx_ready  <= 1'b1;
        end else begin
            case (state)

                IDLE: begin
                    tx_serial <= 1'b1;
                    tx_ready  <= 1'b1;
                    baud_cnt  <= '0;
                    bit_idx   <= '0;
                    if (tx_valid) begin
                        shift_reg <= tx_data;
                        tx_ready  <= 1'b0;
                        state     <= START;
                    end
                end

                START: begin
                    tx_serial <= 1'b0;   // start bit
                    if (baud_cnt == CLKS_PER_BIT - 1) begin
                        baud_cnt <= '0;
                        state    <= DATA;
                    end else begin
                        baud_cnt <= baud_cnt + 1;
                    end
                end

                DATA: begin
                    tx_serial <= shift_reg[bit_idx];   // LSB first
                    if (baud_cnt == CLKS_PER_BIT - 1) begin
                        baud_cnt <= '0;
                        if (bit_idx == 3'd7) begin
                            bit_idx <= '0;
                            state   <= STOP;
                        end else begin
                            bit_idx <= bit_idx + 1;
                        end
                    end else begin
                        baud_cnt <= baud_cnt + 1;
                    end
                end

                STOP: begin
                    tx_serial <= 1'b1;   // stop bit
                    if (baud_cnt == CLKS_PER_BIT - 1) begin
                        baud_cnt <= '0;
                        state    <= IDLE;
                        tx_ready <= 1'b1;
                    end else begin
                        baud_cnt <= baud_cnt + 1;
                    end
                end

                default: state <= IDLE;

            endcase
        end
    end

endmodule
