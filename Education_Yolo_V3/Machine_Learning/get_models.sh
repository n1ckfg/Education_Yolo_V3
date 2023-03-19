#!/bin/bash

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

cd $DIR

wget https://fox-gieg.com/patches/github/n1ckfg/Education_Yolo_V3/Machine_Learning/Education_416.mlmodel
wget https://fox-gieg.com/patches/github/n1ckfg/Education_Yolo_V3/Machine_Learning/Education_V2.mlmodel
wget https://fox-gieg.com/patches/github/n1ckfg/Education_Yolo_V3/Machine_Learning/Education_V3_Tiny.mlmodel