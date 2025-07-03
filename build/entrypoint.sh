#!/bin/sh

set -e

cd "$(dirname "$0")"

env >/tmp/env_before.txt

# CONVERT 1PASSWORD ENVIRONMENT VARIABLES
if env | grep -E '^[^=]*=OP:' >/dev/null; then
	curl -sS -o /tmp/1password-vars.sh "https://raw.githubusercontent.com/JtMotoX/1password-docker/main/1password/op-vars.sh"
	chmod 755 /tmp/1password-vars.sh
	. /tmp/1password-vars.sh || exit 1
fi

env >/tmp/env_after.txt

# STORE CHANGED VARIABLES AS A FILE
diff --changed-group-format='%>' --unchanged-group-format='' /tmp/env_before.txt /tmp/env_after.txt > /tmp/env_changed.txt || true

# MAKE SURE OP ENVIRONMENT VARIABLES WERE CONVERTED
if [ "$(cat /tmp/env_changed.txt 2>/dev/null | grep -cvE '^\s*$')" = "0" ]; then
	echo "ERROR: No 1password variables retrieved."
	exit 1
fi

# MAKE SURE /configs-init IS MOUNTED AS READ-ONLY
if [ ! -d "/configs-init" ]; then
	echo "INFO: No '/configs-init' directory found to this container where your template files are stored."
else
	if touch /configs-init/rw_test.txt 2>/dev/null && rm -f /configs-init/rw_test.txt 2>/dev/null ; then
		echo "ERROR: This init container should have read-only access to the '/configs-init' mount."
		exit 1
	fi
fi

# MAKE SURE /configs IS MOUNTED AS READ-WRITE
if [ ! -d "/configs" ]; then
	echo "ERROR: You need to mount a '/configs' directory to this container. Recommended using a Named Volume for this."
	exit 1
fi
if ! { touch /configs/rw_test.txt 2>/dev/null && rm -f /configs/rw_test.txt 2>/dev/null; }; then
	echo "ERROR: This init container should have read-write access to the '/configs' mount."
	exit 1
fi

# STORE ENVIRONMENT VARIABLES FILE IN /configs
mv /tmp/env_changed.txt /configs/1password-injected.env

# LOOP OVER EACH /configs-init FILE AND INJECT VARIABLES AND STORE IN /configs
if [ ! -d "/configs-init" ]; then
	files_processed=0
	for f in $(find /configs-init -type f 2>/dev/null); do
		f_new="$(echo "$f" | sed -E 's|^(/configs)-init|\1|')"
		envsubst < "$f" >"${f_new}"
		files_processed=$((files_processed + 1))
	done

	if [ "${files_processed}" = "0" ]; then
		echo "INFO: No files in '/configs-init' to process."
	fi
fi
