#!/bin/bash
git rev-parse HEAD >> log.txt
/Applications/Xcode-beta.app/Contents/Developer/usr/bin/xcodebuild -scheme LedgerGUI test | grep "testFile.*passed" >> log.txt
/Applications/Xcode-beta.app/Contents/Developer/usr/bin/xcodebuild -scheme LedgerGUI -showBuildSettings | ack SWIFT_OPTIM >> log.txt
echo "---" >> log.txt
