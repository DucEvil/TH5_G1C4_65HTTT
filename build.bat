@echo off
setlocal enabledelayedexpansion
REM Remove Java 25 from PATH to avoid compatibility issues with Gradle's Kotlin DSL
set JAVA_HOME=C:\Program Files\Android\Android Studio\jbr

REM Build the new PATH without Java 25.0.2
set NEWPATH=
for %%A in ("%PATH:;=" "%") do (
    if not "%%~A"=="" (
        if not "%%~A"=="C:\Program Files\Java\jdk-25.0.2\bin" (
            if "!NEWPATH!"=="" (
                set "NEWPATH=%%~A"
            ) else (
                set "NEWPATH=!NEWPATH!;%%~A"
            )
        )
    )
)
set PATH=!NEWPATH!

cd /d "%~dp0"
flutter build apk %*
