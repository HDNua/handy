#!/bin/bash
set -e
SIM_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="${SIM_DIR}/../.."
OUT="${SIM_DIR}/uart_tx_sim"
LOG="${SIM_DIR}/sim.log"

iverilog -g2012 -o "${OUT}" "${ROOT}/rtl/UART_Tx.sv" "${SIM_DIR}/../tb/tb_top.sv"
cd "${SIM_DIR}" && "${OUT}" 2>&1 | tee "${LOG}"
