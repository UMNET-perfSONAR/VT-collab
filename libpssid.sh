# A bash library for pssid
#
# Expected vars:
# - JSON
#
# External programs used:
# - jq
# - zstd

function base_json() {
	jq \
		--null-input \
		--compact-output \
		--argjson none "$(none)" \
		'{
			"status_code": 0,
			"status_msg": "success",
			"pssid_log": [],
			"internal": {
				"interface": $none,
				"verbosity": 0
			}
		}'
}

function be_done() {
	local filter
	[[ $# -ge 2 ]] && set_status "$@"
	verbosity_met 4 && filter='.' || filter='del(.internal)'
	jq --compact-output "${filter}" <<< "${JSON}"
	# shellcheck disable=SC2046
	# .status_code is an integer, thus doesn't need quoting.
	# And if it isn't an integer, we want it to break
	exit $(get 'status_code' <<< "$JSON")
}

function set_status() {
	local -i code="$1"
	local msg="$2"
	err_log "$msg"
	JSON="$(jq \
		--compact-output \
		--arg code "$code" \
		--arg msg "$2" \
		'.status_code = ($code | tonumber) | .status_msg = $msg' \
		<<< "$JSON"
	)"
	shift 2
	while [[ $# -ge 2 ]]; do
		log "$1" "$2"
		shift 2
	done
}

function log() {
	local time
	time="$(date +%s.%6N)"
	local -i log_level="$1"
	local msg="$2"
	verbosity_met "${log_level}" || return 0

	err_log "${msg}"
	JSON="$(jq \
		--compact-output \
		--arg ll "$log_level" \
		--arg time "$time" \
		--arg msg "$msg" \
		'.pssid_log += [
			{
				"time": ($time | tonumber),
				"verbosity": ($ll | tonumber),
				"msg": $msg
			}
		]' \
		<<< "${JSON}"
	)"
}

function err_log() {
	echo "$(basename "$0"): $1" >&2
}

function panic() {
	set_status "$1" "$2"
	jq --null-input "${JSON}" >&2
	jq --null-input --compact-output "${JSON}"
	kill -HUP $$
}

function unwrap() {
	jq \
		--raw-output \
		--exit-status \
		'select(.is_set).value' \
		|| panic 128 "Error unwraping"
}

function some() {
	jq \
		--null-input \
		--compact-output \
		--arg value "$1" \
		'{ "is_set": true, "value": $value }'
}

function none() {
	jq \
		--null-input \
		--compact-output \
		'{ "is_set": false }'
}

function is_some() {
	jq --exit-status '.is_set' > /dev/null
}

function is_none() {
	jq --exit-status '.is_set == false' > /dev/null
}

function increase_verbosity() {
	JSON="$(jq \
		--compact-output \
		'.internal.verbosity += 1' \
		<<< "${JSON}"
	)"
}

function verbosity_met() {
	jq \
		--null-input \
		--exit-status \
		--argjson base "${JSON}" \
		--arg v "$1" \
		'$base | .internal.verbosity >= ($v | tonumber)' \
		> /dev/null \
		<<< "${JSON}"
}

function set_internal() {
	local key="$1"
	local value="$2"

	jq \
		--null-input \
		--argjson base "${JSON}" \
		--arg key "${key}" \
		'$base | .internal[$key]' \
		| is_none \
		|| be_done 129 "Internal error setting .internal[${key}] = \"${value}\""

	JSON="$(jq \
		--compact-output \
		--arg key "${key}" \
		--argjson value "$(some "${value}")" \
		'.internal[$key] = $value' \
		<<< "${JSON}"
	)"
}

function set_internal_group() {
	local group="$1"
	local key="$2"
	local value="$3"

	jq \
		--null-input \
		--argjson base "${JSON}" \
		--arg group "${group}" \
		--arg key "${key}" \
		'$base | .internal[$group][$key]' \
		| is_none \
		|| be_done 130 "Internal error setting .internal[${group}][${key}] = \"${value}\""

	JSON="$(jq \
		--compact-output \
		--arg group "${group}" \
		--arg key "${key}" \
		--argjson value "$(some "${value}")" \
		'.internal[$group][$key] = $value' \
		<<< "${JSON}"
	)"
}

function unset_internal() {
	local key="$2"

	jq \
		--null-input \
		--argjson base "${JSON}" \
		--arg key "${key}" \
		'.internal[$key]' \
		| is_some \
		|| return 1 # TODO: better error handling
	JSON="$(jq \
		--compact-output \
		--arg key "${key}" \
		--arg none "$(none)" \
		'.internal[$key] = $none' \
		<<< "${JSON}"
	)"
}

function unset_internal_group() {
	local group="$1"
	local key="$2"

	jq \
		--null-input \
		--argjson base "${JSON}" \
		--arg group "${group}" \
		--arg key "${key}" \
		'.internal[$group][$key]' \
		| is_some \
		|| return 1 # TODO: better error handling
	JSON="$(jq \
		--compact-output \
		--arg group "${JSON}" \
		--arg key "${key}" \
		--arg none "$(none)" \
		'.internal[$group][$key] = $none' \
		<<< "${JSON}"
	)"
}

function get() {
	jq \
		--exit-status \
		--raw-output \
		--arg key "$1" \
		'.[$key]
		| if type == "object" and has("is_set") then
			select(.is_set).value
		else
			.
		end' \
		|| set_status 131 "Internal error getting '${key}'"
}

function get_internal_group() {
	internal | (get "$1" || panic) | get "$2"
}

function get_interface() {
	internal | get 'interface'
}

function set_interface() {
	set_internal 'interface' "$1"
}

function internal() {
	jq --compact-output '.internal' <<< "$JSON"
}

function urlencode() {
	jq -Rr '@uri'
}

function encode() {
	zstd | base64 -w 0
}
