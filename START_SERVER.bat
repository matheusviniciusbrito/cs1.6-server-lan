@echo off
cls
title CS 1.6 LAN Server
:hlds
echo (%time%) HLDS Started...
start /wait hlds.exe -console -game cstrike -lan -sys_ticrate 1000 -pingboost 2 +map de_dust2 +maxplayers 11 +port 27015 +exec server.cfg
echo (%time%) HLDS Crashed, restarting...
goto hlds
