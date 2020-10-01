#!/bin/bash

declare -a VARIABLES
VARIABLES=(
	RELEASES_TOKEN
#	GPG_FEATURE_SIGNING_KEY
#	GPG_FEATURE_SIGNING_KEYID
	GPG_STAGINGPRODUCTION_SIGNING_KEY
	GPG_STAGINGPRODUCTION_SIGNING_KEYID
)

declare -a ORGS
ORGS=(
	hybris-mobian-images
	hybris-mobian-releng
	hybris-mobian
)

error() {
	echo "E: $@"
	exit 1
}

# UGLY WORKAROUND WARNING!
# travis-ci command line tool requires admin privileges to set variables.
# This is a bug which has not been resolved (see https://github.com/travis-ci/travis.rb/issues/609)
# Patch the command line client so that it can go on without admin privileges:
file_to_patch=$(find ~/.rvm/gems -type f -iname env.rb | grep "travis" | head -n 1)
if [ -n "${file_to_patch}" ]; then
	sed -i 's/unless repository.admin/unless repository.push/' ${file_to_patch}
fi

[ -z "${GITHUB_ACCESS_TOKEN}" ] && error "No github access token supplied"

travis login --pro --github-token "${GITHUB_ACCESS_TOKEN}"

# Obtain access token to use with the curl workaround
_TRAVIS_AUTH_TOKEN=$(grep -oP 'access_token: .+' ~/.travis/config.yml | awk '{ print $2 }')

for org in ${ORGS[@]}; do
	repos=$(travis repos --pro -o ${org} -a --no-interactive)
	for repo in ${repos}; do
		case "${repo}" in
			"hybris-mobian-releng/rickroll" | "hybris-mobian-releng/docker-images" | "hybris-mobian-releng/build-snippets")
				# Skip
				echo "Skipping ${repo}..."
				continue
				;;
		esac

		travis env --pro clear --repo ${repo}

		for var in ${VARIABLES[@]}; do
			# FIXME! Switch back to travis-cli once it supports per-branch
			# env vars
			#travis env --pro set ${var} "${!var}" --private --repo ${repo}

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

			# Properly escape gpg keys
			case "${var}" in
				"GPG_FEATURE_SIGNING_KEY" | "GPG_STAGINGPRODUCTION_SIGNING_KEY")
					target_var=$(echo "${!var}" | awk 1 ORS='\\n')
					target_var="\\\"\$(echo -e '${target_var}')\\\""
					;;
				*)
					target_var="${!var}"
					;;
			esac

			echo "Setting ${var} for repo ${repo} (target_branch is ${target_branch})"
			curl -X POST \
				-H "Content-Type: application/json" \
				-H "Travis-API-Version: 3" \
				-H "Authorization: token ${_TRAVIS_AUTH_TOKEN}" \
				-d @<(cat <<EOF
{
	"env_var.name" : "${var}",
	"env_var.value" : "${target_var}",
	"env_var.public" : false,
	"env_var.branch" : "${target_branch}"
}
EOF
				) \
				https://api.travis-ci.com/repo/$(echo ${repo} | sed 's,/,%2F,g')/env_vars \
				&> /dev/null \
				|| error "Unable to set variable ${var} for repo ${repo}"
		done
	done
done
