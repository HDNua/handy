#!/bin/bash
# run.sh — iverilog UART TX smoke test

set -e
SIM_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="${SIM_DIR}/.."
OUT="${SIM_DIR}/uart_tx_sim"

echo "=============================="
echo " UART TX Smoke Test"
echo "=============================="

iverilog -g2012 -o "${OUT}" "${ROOT}/rtl/uart_tx.sv" "${ROOT}/tb/top/tb_top.sv"

echo "[OK] Compile success"
echo ""
echo "----- Simulation Output -----"
cd "${SIM_DIR}" && "${OUT}"

echo "=============================="
echo " Done"
echo "=============================="
