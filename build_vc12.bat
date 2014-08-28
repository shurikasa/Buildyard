@echo OFF
REM Simple one-click batch file for executing Debug builds on all Buildyard
REM projects using the Visual Studio 2013 aka vc12 compiler. Note that
REM cmake.exe, git.exe and svn.exe must be part of %PATH%.

REM load environment for Visual Studio 2013
set PWD=%~dp0
CALL "%VS120COMNTOOLS%"\vsvars32.bat

REM do initial configuration if required
IF not exist build_vc12 (
  mkdir build_vc12
  cd /D build_vc12
  cmake .. -G "Visual Studio 12"
) ELSE (
  cd /D build_vc12
  msbuild /p:Configuration=Debug ZERO_CHECK.vcxproj
)

REM build Debug configuration and use all local CPU cores
msbuild /p:Configuration=Debug /m ALL_BUILD.vcxproj
cd /D %PWD%
pause
