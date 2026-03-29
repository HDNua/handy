#!/bin/bash
# run.sh — iverilog UART TX smoke test

set -e
SIM_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="${SIM_DIR}/../.."
OUT="${SIM_DIR}/uart_tx_sim"
LOG="${SIM_DIR}/sim.log"

echo "=============================="
echo " UART TX Smoke Test"
echo "=============================="

iverilog -g2012 -o "${OUT}" "${ROOT}/rtl/UART_Tx.sv" "${SIM_DIR}/../tb/top/tb_top_v6.sv"

echo "[OK] Compile success"
echo ""
echo "----- Simulation Output -----"

cd "${SIM_DIR}" && "${OUT}" 2>&1 | tee "${LOG}"

echo "=============================="
echo " Done"
echo "=============================="
