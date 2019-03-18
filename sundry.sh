#!/bin/bash

# change caps to ctrl
setxkbmap -option ctrl:nocaps

# natural rolling 
xmodmap -e 'pointer = 1 2 3 5 4 7 6 8 9 10 11 12'
