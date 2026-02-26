@echo off
:: 检查是否以管理员身份运行
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo restart with admin    
    powershell -Command "Start-Process cmd -ArgumentList '/c %~s0' -Verb RunAs"
    timeout /t 1 /nobreak
    exit
)
:--------------------------------------
echo Running with elevated privileges...

@echo off
REM -- 关闭自动更新
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate /t REG_DWORD /d 1 /f
REM -- 禁止手动检查更新
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v SetDisableUXWUAccess /t REG_DWORD /d 1 /f
REM -- 禁止自动更新驱动
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v ExcludeWUDriversInQualityUpdate /t REG_DWORD /d 1 /f

echo Windows Update settings had been modified. Please reboot to take effect
pause
