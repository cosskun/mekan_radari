@echo off
chcp 65001 >nul
title Mekan Radari - GitHub Gonderimi

echo ===================================================
echo     Mekan Radari - GitHub CI/CD Gonderim Sihirbazi
echo ===================================================
echo.

cd /d "%~dp0"

:: Check if git repository is initialized
if not exist ".git" (
    echo [BILGI] Git deposu baslatiliyor...
    git init -b main
    if errorlevel 1 (
        echo [HATA] Git deposu baslatilamadi!
        pause
        exit /b 1
    )
)

echo [1/3] Dosyalar git havuzuna ekleniyor...
git add .

:: Commit message handling
set "COMMIT_MSG=%~1"
if "%COMMIT_MSG%"=="" (
    set /p "COMMIT_MSG=Commit mesaji girin (Bos birakilirsa otomatik tarih atilir): "
)
if "%COMMIT_MSG%"=="" (
    set "COMMIT_MSG=Mekan Radari guncellemesi [%DATE% %TIME%]"
)

echo.
echo [2/3] Degisiklikler kaydediliyor (commit)...
git commit -m "%COMMIT_MSG%" >nul 2>&1
if errorlevel 1 (
    echo [BILGI] Kaydedilecek yeni degisiklik bulunamadi veya onceden commit yapilmis.
) else (
    echo [BASARILI] Degisiklikler yerel depoya kaydedildi.
)

echo.
echo [3/3] GitHub'a gonderiliyor (push)...
git remote get-url origin >nul 2>&1
if errorlevel 1 (
    echo.
    echo [BILGI] Uzak depo (remote origin) henuz tanimlanmamis.
    echo Degisiklikler yerel Git deposuna basariyla kaydedildi.
    echo.
    echo GitHub deponuzu baglamak icin su komutu calistirin:
    echo   git remote add origin ^<github-repo-url^>
    echo   git push -u origin main
    echo.
    echo Depo baglandiktan sonra bu betik otomatik TestFlight ve Firebase dagitimini tetikleyecektir.
    echo ===================================================
    pause
    exit /b 0
)

git branch -M main >nul 2>&1
git push -u origin main
if errorlevel 1 (
    echo.
    echo [UYARI] 'main' branch'ine gonderilemedi. Alternatif branch 'master' deneniyor...
    git push -u origin master
    if errorlevel 1 (
        echo.
        echo [DIKKAT] Push islemi basarisiz oldu. Internet baglantinizi ve erisim yetkinizi kontrol edin.
        echo.
        pause
        exit /b 1
    )
)

echo.
echo ===================================================
echo   Basariyla gonderildi!
echo   GitHub Actions TestFlight ve Firebase dagitimi tetiklendi.
echo ===================================================
echo.
pause
