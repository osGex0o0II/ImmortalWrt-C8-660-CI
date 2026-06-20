#!/bin/sh
rec=$(sendat "$1" "$2")
printf '%s\n' "$rec" >> /tmp/result.at
