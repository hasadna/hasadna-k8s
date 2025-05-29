#!/bin/sh
if MSG=$(/bin/sh $VALIDATE_SCRIPT 2>&1); then
    STATUS="200 OK"
else
    STATUS="500 Internal Server Error"
fi
echo "Status: $STATUS"
echo "Content-Type: text/plain"
echo
echo "$MSG"
