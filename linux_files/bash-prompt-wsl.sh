#!/bin/bash
#
# Add Windows Terminal Shell Integration codes to the prompt.

function main() {
   [ "$PS1" = "\\s-\\v\\\$ " ] && PS1="[\u@\h \W]\\$ "

  export PS1='\[\033]133;D;$?\]\[\033\\\033]133;A\033\\\]'"${PS1}"'\[\033]9;9;"$(wslpath -w "${PWD}")"\033\\\]\[\033]133;B\033\\\]'
}

main "$@"
