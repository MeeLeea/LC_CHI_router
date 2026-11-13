# =============================================================================
# 文件: scripts/env.ps1
# 功能: 配置 Vivado 仿真/综合运行环境（PATH + XILINX_VIVADO）
# 用法（在工程根目录下的 PowerShell 中）:
#   . .\scripts\env.ps1
# 配置后可直接执行:
#   vivado -mode batch -source scripts/start.tcl
#   vivado -mode batch -source scripts/run_one.tcl -tclargs <tb_name> [<define>]
# =============================================================================

$VIVADO_BIN = "D:\AMDTools\2025.2\Vivado\bin"
$VIVADO_ROOT = "D:\AMDTools\2025.2\Vivado"

if (-not (Test-Path -LiteralPath "$VIVADO_BIN\vivado.bat")) {
    Write-Host "[ERROR] 未找到 vivado.bat: $VIVADO_BIN\vivado.bat" -ForegroundColor Red
    return
}

# XILINX_VIVADO 供 start.tcl / run_one.tcl 定位 glbl.v
$env:XILINX_VIVADO = $VIVADO_ROOT

# 将 Vivado bin 加入本次会话 PATH（幂等，不重复追加）
if ($env:Path -notlike "*$VIVADO_BIN*") {
    $env:Path = "$VIVADO_BIN;" + $env:Path
}

Write-Host "[INFO] Vivado 环境已就绪:"
Write-Host "       XILINX_VIVADO = $env:XILINX_VIVADO"
Write-Host "       PATH 已加入   = $VIVADO_BIN"
