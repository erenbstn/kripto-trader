@echo off
chcp 65001 >nul
title Kripto Multi-Agent Day Trader (Paper Trading - $500)
cd /d "%~dp0"

echo ============================================================
echo   KRIPTO MULTI-AGENT DAY TRADER (11 AJANLI OTONOM SISTEM)
echo   Mod: Paper Trading (Sahte Bakiye Simülasyonu - $500.00)
echo ============================================================
echo.

python main.py run
pause

