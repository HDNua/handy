#!/bin/bash
SIM_DIR="$(cd "$(dirname "$0")" && pwd)"

gtkwave "${SIM_DIR}/uart_tx.vcd" &