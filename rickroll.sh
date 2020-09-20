#!/bin/bash

declare -a VARIABLES
VARIABLES=(
	RELEASES_TOKEN
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

for org in ${ORGS[@]}; do
	repos=$(travis repos --pro -o ${org} -a --no-interactive)
	for repo in ${repos}; do
		if [ "${repo}" == "hybris-mobian-releng/rickroll" ]; then
			continue
		fi

		for var in ${VARIABLES[@]}; do
			travis env --pro set ${var} "${!var}" --private --repo ${repo}
		done
	done
done
