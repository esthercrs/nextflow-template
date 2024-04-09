#!/usr/bin/env bash

#################################################
##                                             ##
## [Add description of the script purpose]     ##
##                                             ##
#################################################

# Get module arguments for script
args=("$@")
XXX=${args[0]}
YYY=${args[1]}
LOGCMD=${args[2]}

# Command line to run
CMD="[commandline]"
echo ${CMD} > ${LOGCMD}
eval ${CMD}