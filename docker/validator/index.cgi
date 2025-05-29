#!/bin/sh
if MSG=$(/bin/sh $VALIDATE_SCRIPT); then
    STATUS="200 OK"
else
    STATUS="500 Internal Server Error"
fi
echo "Status: $STATUS"
echo "Content-Type: text/plain"
echo
echo "$MSG"
