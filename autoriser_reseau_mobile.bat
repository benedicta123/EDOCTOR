@echo off
chcp 65001 > nul
echo ========================================================
echo   CONFIGURATION PARE-FEU WINDOWS POUR EDOCTOR MOBILE
echo ========================================================
echo.

:: Vérification des droits administrateur
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [!] Ce script doit etre execute en tant qu'Administrateur.
    echo [!] Relance automatique avec elevation de privileges...
    powershell -Command "Start-Process cmd -ArgumentList '/c \"%~f0\"' -Verb RunAs"
    exit /b
)

echo [+] Droits Administrateur detectes.
echo.

echo 1. Ouverture du port 8000 (API Laravel) dans le Pare-feu Windows...
netsh advfirewall firewall add rule name="Laravel eDoctor API (Port 8000)" dir=in action=allow protocol=TCP localport=8000 profile=any
if %errorLevel% equ 0 (
    echo    -> Port 8000 autorise avec succes pour tous les profils reseau !
) else (
    echo    [!] Erreur lors de l'ajout de la regle pare-feu port 8000.
)

echo.
echo 2. Bascule de la connexion Wi-Fi en profil "Prive" (recommande pour le dev local)...
powershell -Command "Set-NetConnectionProfile -InterfaceAlias 'Wi-Fi' -NetworkCategory Private" >nul 2>&1
if %errorLevel% equ 0 (
    echo    -> Reseau Wi-Fi passe en mode Prive avec succes !
) else (
    echo    -> (Information : profil reseau inchange ou deja applique)
)

echo.
echo ========================================================
echo   CONFIGURATION TERMINEE !
echo   Votre telephone peut desormais joindre l'API sur :
echo   http://192.168.1.79:8000/api
echo ========================================================
echo.
pause
