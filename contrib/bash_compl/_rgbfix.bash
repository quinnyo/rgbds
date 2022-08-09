#!/usr/bin/env bash

# Same notes as RGBASM

_rgbfix_completions() {
	# Format: "long_opt:state_after"
	# Empty long opt = it doesn't exit
	# See the `state` variable below for info about `state_after`
	declare -A opts=(
		[V]="version:normal"
		[j]="non-japanese:normal"
		[s]="sgb-compatible:normal"
		[v]="validate:normal"
		[C]="color-only:normal"
		[c]="color-compatible:normal"
		[f]="fix-spec:fix-spec"
		[i]="game-id:unk"
		[k]="new-licensee:unk"
		[l]="old-licensee:unk"
		[m]="mbc-type:mbc"
		[n]="rom-version:unk"
		[p]="pad-value:unk"
		[r]="ram-size:unk"
		[t]="title:unk"
	)
	# Parse command-line up to current word
	local opt_ena=true
	# Possible states:
	# - normal  = Well, normal. Options are parsed normally.
	# - unk     = An argument that can't be completed, and should just be skipped.
	# - warning = A warning flag.
	# - dir     = A directory path
	# - glob-*  = A glob, after the dash is a whitespace-separated list of file globs to use
	local state=normal
	# The length of the option, used as a return value by the function below
	local optlen=0
	# $1: a short option word
	# `state` will be set to the parsing state after the last option character in the word. If
	# "normal" is not returned, `optlen` will be set to the length (dash included) of the "option"
	# part of the argument.
	parse_short_opt() {
		for (( i = 1; i < "${#1}"; i++ )); do
			# If the option is not known, assume it doesn't take an argument
			local opt="${opts["${1:$i:1}"]:-":normal"}"
			state="${opt#*:}"
			# If the option takes an argument, record the length and exit
			if [[ "$state" != 'normal' ]]; then
				let optlen="$i + 1"
				return
			fi
		done
		optlen=0
	}

	for (( i = 1; i < COMP_CWORD; i++ )); do
		local word="${COMP_WORDS[$i]}"

		# If currently processing an argument, skip this word
		if [[ "$state" != 'normal' ]]; then
			state=normal
			continue
		fi

		if [[ "$word" = '--' ]]; then
			# Options stop being parsed after this
			opt_ena=false
			break
		fi

		# Check if it's a long option
		if [[ "$word" = '--'* ]]; then
			# If the option is unknown, assume it takes no arguments: keep the state at "normal"
			for long_opt in "${opts[@]}"; do
				if [[ "$word" = "--${long_opt%%:*}" ]]; then
					state="${long_opt#*:}"
					# Check if the next word is just '='; if so, skip it, the argument must follow
					# (See "known bugs" at the top of this script)
					let i++
					if [[ "${COMP_WORDS[$i]}" != '=' ]]; then
						let i--
					fi
					optlen=0
					break
				fi
			done
		# Check if it's a short option
		elif [[ "$word" = '-'* ]]; then
			parse_short_opt "$word"
			# The last option takes an argument...
			if [[ "$state" != 'normal' ]]; then
				if [[ "$optlen" -ne "${#word}" ]]; then
					# If it's contained within the word, we won't complete it, revert to "normal"
					state=normal
				else
					# Otherwise, complete it, but start at the beginning of *that* word
					optlen=0
				fi
			fi
		fi
	done

	# Parse current word
	# Careful that it might look like an option, so use `--` aggressively!
	local cur_word="${COMP_WORDS[$COMP_CWORD]}"

	# Process options, as short ones may change the state
	if $opt_ena && [[ "$state" = 'normal' && "$cur_word" = '-'* ]]; then
		# We might want to complete to an option or an arg to that option
		# Parse the option word to check
		# There's no whitespace in the option names, so we can ride a little dirty...

		# Is this a long option?
		if [[ "$cur_word" = '--'* ]]; then
			# It is, try to complete one
			mapfile -t COMPREPLY < <(compgen -W "${opts[*]%%:*}" -P '--' -- "${cur_word#--}")
			return 0
		else
			# Short options may be grouped, parse them to determine what to complete
			parse_short_opt "$cur_word"

			if [[ "$state" = 'normal' ]]; then
				mapfile -t COMPREPLY < <(compgen -W "${!opts[*]}" -P "$cur_word" '')
				return 0
			elif [[ "$optlen" = "${#cur_word}" && "$state" != "warning" ]]; then
				# This short option group only awaits its argument!
				# Post the option group as-is as a reply so that Readline inserts a space,
				# so that the next completion request switches to the argument
				# An exception is made for warnings, since it's idiomatic to stick them to the
				# `-W`, and it doesn't break anything.
				COMPREPLY=( "$cur_word" )
				return 0
			fi
		fi
	fi

	COMPREPLY=()
	case "$state" in
		unk) # Return with no replies: no idea what to complete!
			;;
		fix-spec)
			COMPREPLY=( "${cur_word}"{l,h,g,L,H,G} )
			;;
		mbc)
			local cur_arg="${cur_word:$optlen}"
			cur_arg="${cur_arg@U}"
			compopt -o nosort # Keep `help` first in the list, mainly
			mapfile -t COMPREPLY < <(compgen -W "help" -P "${cur_word:0:$optlen}" -- "${cur_word:$optlen}")
			mapfile -t COMPREPLY -O ${#COMPREPLY} < <(compgen -W "
				ROM_ONLY
				MBC1{,+RAM,+RAM+BATTERY}
				MBC2{,+BATTERY}
				MMM01{,+RAM}
				MBC3{+TIMER+BATTERY,+TIMER+RAM+BATTERY,,+RAM,+RAM+BATTERY}
				MBC5{,+RAM,+RAM+BATTERY,+RUMBLE,+RUMBLE+RAM,+RUMBLE+RAM+BATTERY}
				MBC6
				MBC7+SENSOR+RUMBLE+RAM+BATTERY
				POCKET_CAMERA
				BANDAI_TAMA5
				HUC3
				HUC1+RAM+BATTERY
				TPP1_1.0{,+BATTERY}{,+RTC}{,+RUMBLE,+MULTIRUMBLE}" -P "${cur_word:0:$optlen}" -- "${cur_word/ /_}")
			;;
		normal) # Acts like a glob...
			state="glob-*.gb *.gbc *.sgb"
			;&
		glob-*)
			while read -r word; do
				COMPREPLY+=("${cur_word:0:$optlen}$word")
			done < <(for glob in ${state#glob-}; do compgen -A file -X \!"$glob" -- "${cur_word:$optlen}"; done)
			# Also complete directories
			;&
		dir)
			while read -r word; do
				COMPREPLY+=("${cur_word:0:$optlen}$word")
			done < <(compgen -A directory -- "${cur_word:$optlen}")
			compopt -o filenames
			;;
		*)
			echo >&2 "Internal completion error: invalid state \"$state\", please report this bug"
			return 1
			;;
	esac
}

complete -F _rgbfix_completions rgbfix
