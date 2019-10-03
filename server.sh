#!/bin/sh

echo "Hello"
echo my ip is "$(ip -4 addr)"
nc -l -p 4000
