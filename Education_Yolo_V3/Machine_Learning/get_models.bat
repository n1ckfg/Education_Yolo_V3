@echo off

cd %~dp0
powershell -Command "Invoke-WebRequest https://fox-gieg.com/patches/github/n1ckfg/Education_Yolo_V3/Machine_Learning/Education_416.mlmodel -OutFile Education_416.mlmodel"
powershell -Command "Invoke-WebRequest https://fox-gieg.com/patches/github/n1ckfg/Education_Yolo_V3/Machine_Learning/Education_V2.mlmodel -OutFile Education_V2.mlmodel"
powershell -Command "Invoke-WebRequest https://fox-gieg.com/patches/github/n1ckfg/Education_Yolo_V3/Machine_Learning/Education_V3_Tiny.mlmodel -OutFile Education_V3_Tiny.mlmodel"

@pause