@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion

set "LOCAL_VERSION=1"
title EXBO TOKEN VIEWER 

set REGISTRY_PATH_EXBO=HKCU\SOFTWARE\EXBO
set REGISTRY_PATH_ESAVEEX=HKCU\Software\esaveex

:menu
cls
echo.
echo   ===================================================
echo   ::               EXBO TOKEN VIEWER 
echo   ::  email for questions: sokolnolegit@gmail.com
echo   ===================================================
echo.
echo   :: ACTIVE ACCOUNT IN SYSTEM (Press Enter to update):
call :get_current_exbo
echo. 
echo   ---------------------------------------------------
echo.
echo   :: ACTIONS WITH TOKENS
echo      1. Save current token (Add to database)
echo      2. View saved accounts
echo      3. Switch account (Insert token)
echo      4. Delete specific account
echo      5. Clear database (Wipe all)
echo.
echo   :: EDIT TOOLS
echo      6. Edit note for specific account
echo.
echo   ---------------------------------------------------
echo      0. Exit
echo.

set "menu_choice="
set /p menu_choice=   Select option (0-6): 

if "!menu_choice!"=="" goto menu
if "!menu_choice!"=="1" goto save_token
if "!menu_choice!"=="2" goto list_tokens
if "!menu_choice!"=="3" goto switch_token
if "!menu_choice!"=="4" goto delete_token
if "!menu_choice!"=="5" goto clear_all
if "!menu_choice!"=="6" goto edit_note
if "!menu_choice!"=="0" exit /b
goto menu


:get_current_exbo
set "curr_login="
for /f "tokens=2*" %%A in ('reg query "%REGISTRY_PATH_EXBO%" /v EXBO_LOGIN 2^>nul') do set "curr_login=%%B"
if defined curr_login (
    echo       Login: !curr_login!
) else (
    echo       Login not found (Launcher session is empty)
)
exit /b


:save_token
cls
echo :: Saving current EXBO session...
set "login="
set "session="

for /f "tokens=2*" %%A in ('reg query "%REGISTRY_PATH_EXBO%" /v EXBO_LOGIN 2^>nul') do set "login=%%B"
for /f "tokens=2*" %%A in ('reg query "%REGISTRY_PATH_EXBO%" /v EXBO_SESSION 2^>nul') do set "session=%%B"

if not defined login (
    echo Error: Active EXBO session not found.
    pause
    goto menu
)

echo Detected login: !login!
set /p "note=Enter a note for this account (or press Enter): "
if "!note!"=="" set "note=Empty"
set "note=!note:,= !"

:: Мгновенный поиск существующего логина или свободного индекса в один запрос
set "target_index="
set "max_idx=-1"

for /f "tokens=1,2*" %%A in ('reg query "%REGISTRY_PATH_ESAVEEX%" 2^>nul ^| findstr /I "SavedValue_"') do (
    set "vname=%%A"
    set "raw_val=%%C"
    set "current_idx=!vname:SavedValue_=!"
    if !current_idx! GTR !max_idx! set "max_idx=!current_idx!"
    
    for /f "delims=," %%X in ("!raw_val!") do (
        if "%%X"=="!login!" set "target_index=!current_idx!"
    )
)

if not defined target_index (
    set /a "next_idx=max_idx + 1"
    set "target_index=!next_idx!"
)

:do_save
reg add "%REGISTRY_PATH_ESAVEEX%" /f >nul 2>&1
reg add "%REGISTRY_PATH_ESAVEEX%" /v "SavedValue_!target_index!" /t REG_SZ /d "!login!,!session!,!note!" /f >nul
if !errorlevel!==0 (
    echo Token for !login! saved successfully.
) else (
    echo Registry write error.
)
pause
goto menu


:list_tokens
cls
echo :: Saved accounts list:
echo ----------------------------------------------------
set "found=0"
for /f "tokens=1,2*" %%A in ('reg query "%REGISTRY_PATH_ESAVEEX%" 2^>nul ^| findstr /I "SavedValue_"') do (
    set "found=1"
    set "vname=%%A"
    set "current_idx=!vname:SavedValue_=!"
    set "raw_data=%%C"
    for /f "tokens=1,2* delims=," %%X in ("!raw_data!") do (
        echo [!current_idx!] Name: %%X ^| Note: %%Z
    )
)

if "!found!"=="0" echo Database is empty.
echo ----------------------------------------------------
pause
goto menu


:switch_token
cls
echo :: Select account to switch (Insert token):
echo.

set "count=0"
for /f "tokens=1,2*" %%A in ('reg query "%REGISTRY_PATH_ESAVEEX%" 2^>nul ^| findstr /I "SavedValue_"') do (
    set /a count+=1
    set "raw_data=%%C"
    for /f "tokens=1,2* delims=," %%X in ("!raw_data!") do (
        echo   !count!. %%X ^(Note: %%Z^)
        set "acc_login_!count!=%%X"
        set "acc_sess_!count!=%%Y"
    )
)

if !count!==0 (
    echo No saved accounts available.
    pause
    goto menu
)
echo   0. Back
echo.

set /p "choice=Enter account number: "
if "!choice!"=="" goto menu
if "!choice!"=="0" goto menu

set "sel_login=!acc_login_%choice%!"
set "sel_sess=!acc_sess_%choice%!"

if not defined sel_login (
    echo Invalid choice.
    pause
    goto switch_token
)

reg add "%REGISTRY_PATH_EXBO%" /v EXBO_LOGIN /t REG_SZ /d "!sel_login!" /f >nul
reg add "%REGISTRY_PATH_EXBO%" /v EXBO_SESSION /t REG_SZ /d "!sel_sess!" /f >nul
reg add "%REGISTRY_PATH_EXBO%" /v EXBO_AUTO_AUTH /t REG_SZ /d "true" /f >nul

echo Token successfully injected! EXBO_AUTO_AUTH set to true.
echo Active account: !sel_login!
pause
goto menu


:delete_token
cls
echo :: Select account to DELETE:
echo.

set "count=0"
for /f "tokens=1,2*" %%A in ('reg query "%REGISTRY_PATH_ESAVEEX%" 2^>nul ^| findstr /I "SavedValue_"') do (
    set /a count+=1
    set "del_raw_!count!=%%C"
    for /f "tokens=1 delims=," %%X in ("%%C") do (
        echo   !count!. %%X
    )
)

if !count!==0 (
    echo No saved accounts available.
    pause
    goto menu
)
echo   0. Back
echo.

set /p "choice=Enter number to delete: "
if "!choice!"=="" goto menu
if "!choice!"=="0" goto menu

set "to_delete=!del_raw_%choice%!"
if not defined to_delete (
    echo Invalid choice.
    pause
    goto delete_token
)

reg delete "%REGISTRY_PATH_ESAVEEX%" /f >nul 2>&1
reg add "%REGISTRY_PATH_ESAVEEX%" /f >nul 2>&1

set "new_idx=0"
for /l %%I in (1,1,!count!) do (
    if not "%%I"=="%choice%" (
        reg add "%REGISTRY_PATH_ESAVEEX%" /v "SavedValue_!new_idx!" /t REG_SZ /d "!del_raw_%%I!" /f >nul
        set /a new_idx+=1
    )
)

echo Account deleted successfully.
pause
goto menu


:clear_all
cls
echo WARNING! You are going to completely wipe all saved tokens.
set /p "confirm=Are you sure? (Y/N): "
if /i "%confirm%"=="Y" (
    reg delete "%REGISTRY_PATH_ESAVEEX%" /f >nul 2>&1
    echo Database cleared successfully.
) else (
    echo Canceled.
)
pause
goto menu


:edit_note
cls
echo :: Select account to edit note:
echo.

set "count=0"
for /f "tokens=1,2*" %%A in ('reg query "%REGISTRY_PATH_ESAVEEX%" 2^>nul ^| findstr /I "SavedValue_"') do (
    set /a count+=1
    set "raw_data=%%C"
    set "val_name_!count!=%%A"
    for /f "tokens=1,2* delims=," %%X in ("!raw_data!") do (
        echo   !count!. %%X ^(Current note: %%Z^)
        set "acc_login_!count!=%%X"
        set "acc_sess_!count!=%%Y"
    )
)

if !count!==0 (
    echo No saved accounts available.
    pause
    goto menu
)
echo   0. Back
echo.

set /p "choice=Enter account number: "
if "!choice!"=="" goto menu
if "!choice!"=="0" goto menu

set "sel_login=!acc_login_%choice%!"
set "sel_sess=!acc_sess_%choice%!"
set "sel_vname=!val_name_%choice%!"

if not defined sel_login (
    echo Invalid choice.
    pause
    goto edit_note
)

echo.
echo Selected account: !sel_login!
set /p "new_note=Enter NEW note (or press Enter to set Empty): "
if "!new_note!"=="" set "new_note=Empty"

set "new_note=!new_note:,= !"

reg add "%REGISTRY_PATH_ESAVEEX%" /v "!sel_vname!" /t REG_SZ /d "!sel_login!,!sel_sess!,!new_note!" /f >nul

if !errorlevel!==0 (
    echo Note updated successfully for !sel_login!.
) else (
    echo Failed to update note in registry.
)
pause
goto menu
