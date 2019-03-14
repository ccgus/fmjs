#!/bin/bash

xcodeversion="Xcode 9.4.1"
xcodebuild=/Applications/Xcode9.4.1.app/Contents/Developer/usr/bin/xcodebuild
deployTarget=10.12

if [ ! -f  $xcodebuild ]; then
    echo "$xcodebuild not found, trying another loc"
    xcodebuild=/Volumes/srv/Applications/Xcode9.4.1.app/Contents/Developer/usr/bin/xcodebuild
fi

if [ ! -f  $xcodebuild ]; then
    echo "$xcodebuild not found, exiting"
    exit 2
fi



function xcbuild {
    $xcodebuild $* clean
    $xcodebuild $* MACOSX_DEPLOYMENT_TARGET=$deployTarget build
}


function failForBadBuild {
    if [ $? != 0 ]; then
        failmsg="Bad build for $1"
        echo $failmsg
        say $failmsg
        exit
    fi
}

SRC_DIR=`cd ${0%/*}/..; pwd`

xcv=`$xcodebuild -version | grep Xcode`

if [ "$xcv" != "$xcodeversion" ]; then    
    echo ""
    echo ""
    echo ""
    echo "Building with the wrong version of Xcode: '$xcv' .  Should be '$xcodeversion'"
    echo ""
    beep
    exit
fi

echo "Building using $xcv, deploy target $deployTarget" 

buildDate=`/bin/date +"%Y.%m.%d.%H"`

cd /tmp/

rm -rf fmjs

echo "Checking out from server"
gitcmd="git clone git@github.com:ccgus/fmjs.git fmjs"
echo $gitcmd
$gitcmd

cd /tmp/fmjs



xcbuild -configuration Release -target fmjstool OBJROOT=/tmp/fmjs/build SYMROOT=/tmp/fmjs/build OTHER_CFLAGS="$appStoreFlags" INFOPLIST_OTHER_PREPROCESSOR_FLAGS="$appStoreFlags"

failForBadBuild "fmjstool"

open  /tmp/fmjs/build

