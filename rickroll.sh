#!/bin/bash

# ADD_MISSING_ONLY controls whether only missing (non-active) repositories
# should be added. Default is "yes". If not, every repository will be
# processed.
[ -z "${ADD_MISSING_ONLY}" ] && ADD_MISSING_ONLY="yes"

declare -a VARIABLES
VARIABLES=(
	RELEASES_TOKEN
	GPG_STAGINGPRODUCTION_SIGNING_KEY
	GPG_STAGINGPRODUCTION_SIGNING_KEYID
	INTAKE_SSH_USER
	INTAKE_SSH_KEY
)

declare -a ORGS
ORGS=(
	g7-debs
)

error() {
	echo "E: $@"
	exit 1
}

[ -z "${DRONE_ACCESS_TOKEN}" ] && error "No drone access token supplied"

export DRONE_TOKEN="${DRONE_ACCESS_TOKEN}"
export DRONE_SERVER="https://cloud.drone.io"

# Sync first
drone repo sync

for org in ${ORGS[@]}; do
	if [ "${ADD_MISSING_ONLY}" == "yes" ]; then
		repos=$(drone repo ls --org ${org} --format "{{ .Active }} {{ .Slug }}" | grep 'false ' | awk '{ print $2 }')
	else
		repos=$(drone repo ls --org ${org})
	fi
	for repo in ${repos}; do
		echo "Processing ${repo}..."
		case "${repo}" in
			"g7-debs/rickroll" | "g7-debs/docker-images" | "g7-debs/build-snippets")
				# Skip
				echo "Skipping ${repo}..."
				continue
				;;
		esac

		# Enable
		drone repo enable ${repo}

		# Update configuration
		drone repo update --config debian/drone.star --ignore-pull-requests ${repo}

		if [ "${ADD_MISSING_ONLY}" != "yes" ]; then
			# Get list of existing variables, and nuke them
			for var in $(drone secret ls ${repo} --format '{{ .Name }}'); do
				drone secret rm --name "${var}" ${repo}
			done
		fi

		for var in ${VARIABLES[@]}; do
			# Select target branch
			case "${var}" in
#				"RELEASES_TOKEN" | "GPG_STAGINGPRODUCTION_SIGNING_KEY" |"GPG_STAGINGPRODUCTION_SIGNING_KEYID")
#					# Target is bullseye
#					target_branch="bullseye"
#					;;
				*)
					target_branch=""
					;;
			esac

			echo "Setting ${var} for repo ${repo} (target_branch is ${target_branch})"
			drone secret add \
				${repo} \
				--name "${var}" \
				--data "${!var}"
		done
	done
done
