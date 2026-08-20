#!/bin/sh
set -e

# This entrypoint is no longer used.
# The container runs as the 'tomcat' user via the USER directive in the Dockerfile.
# Kept for backward compatibility reference only.
exec catalina.sh run
