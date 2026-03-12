#!/bin/env zsh
0="${ZERO:-${${0:#$ZSH_ARGZERO}:-${(%):-%N}}}"
0="${ZERO:-${${${(M)${0::=${(%):-%x}}:#/*}:-$PWD/$0}:A}}"
local ZERO="$0"

if [[ ${zsh_loaded_plugins[-1]} != */diskguard && -z ${fpath[(r)${0:h}]} ]] {
    fpath+=( "${0:h}" )
}

if [[ $PMSPEC != *f* ]] {
    fpath+=( "${0:h}/functions" )
}

typeset -gA Plugins && Plugins[DISKGUARD]="${0:h}"
typeset -g DISKGUARD_PLUGIN_DIR="${0:A:h}"
typeset -g DISKGUARD_FUNC_DIR="${DISKGUARD_PLUGIN_DIR}/functions"

source ${0:A:h}/diskguard.zsh
