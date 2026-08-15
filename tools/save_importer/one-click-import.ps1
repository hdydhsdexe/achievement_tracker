[CmdletBinding()]
param(
    [switch] $DryRun
)

$ErrorActionPreference = 'Stop'
$coreScript = Join-Path $PSScriptRoot 'one-click-import-core.ps1'
. $coreScript

try {
    $toolsDirectory = Split-Path $PSScriptRoot -Parent
    $modRoot = Split-Path $toolsDirectory -Parent
    $modsDirectory = Split-Path $modRoot -Parent
    $gameRoot = Split-Path $modsDirectory -Parent
    if ([string]::IsNullOrWhiteSpace($gameRoot)) { throw '无法从脚本位置确定游戏目录。' }

    if ($DryRun) { Write-Host '正在执行只读检查，不会创建、修改或备份任何文件……' -ForegroundColor Cyan }
    else { Write-Host '正在查找并验证以撒存档，请勿启动游戏……' -ForegroundColor Cyan }

    $result = Invoke-OneClickAchievementImport -ModRoot $modRoot -DryRun:$DryRun
    Write-Host ("来源：{0} / {1} / {2}" -f $result.Edition, $result.Location, $result.SetName)
    foreach ($slot in $result.Slots) {
        Write-Host ("存档槽 {0}：已解锁 {1} 项成就" -f $slot.SaveSlot, $slot.UnlockedCount)
    }
    if ($result.DryRun) { Write-Host '只读检查完成：没有修改任何文件。' -ForegroundColor Green }
    else {
        Write-Host '一键导入完成。请重新启动游戏。' -ForegroundColor Green
        Write-Host ("旧文件备份：{0}" -f $result.BackupPath) -ForegroundColor Green
    }
    exit 0
} catch {
    Write-Host ("导入已停止：{0}" -f $_.Exception.Message) -ForegroundColor Red
    exit 1
}
