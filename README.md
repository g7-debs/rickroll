rickroll
========

Until travis-ci supports organization-level variables (which is probably
never, see https://github.com/travis-ci/travis-ci/issues/2069), we
need to find a way to properly set and rotate access tokens for the
various services we need (github releases, target repository, etc).

This simple project is tasked to do exactly that - it cycles through
every project on the listed organizations, and updates their secret
variables.

Adding or modifying a new variable
----------------------------------

Go to this repository's settings in the [Travis CI Web-UI](https://travis-ci.com/github/hybris-mobian-releng/rickroll/settings),
and change the variables there.

**If the variable has been already added previously**, just trigger a new Build via the Travis CI Web-UI.

**If the variable is new, you should update the `rickroll.sh` script.**

Adding a new repository
-----------------------

Variables are synced to every repository, so if you add a new one, just
be sure to trigger a rebuild via the Web-UI.
