@ECHO OFF

IF EXIST luacov.stats.out del luacov.stats.out
IF EXIST luacov.report.out del luacov.report.out

echo running tests
lua -lluacov aos-carlscribe-test.lua

echo:
echo generating coverage report at luacov.report.out
lua luacov-bin\luacov luacov.stats.out
echo done

set arg0=%0
if [%arg0:~2,1%]==[:] pause