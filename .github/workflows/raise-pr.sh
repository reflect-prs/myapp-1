#!/usr/bin/env bash
#set -x
PR_BODY="$(<./CHANGELOG.md)"
hub config --global user.email "${GITHUB_EMAIL}"
hub config --global user.name "${GITHUB_USERNAME}"
cd infra
# Read CHANGELOG.md generated above. Using the task output doesn't work for multi-line content.
# Check for an open PR to deploy our app to `${TARGET_ENV}`
OPEN_DEV_PR_NUMBER=$(hub pr list -h "release-${TARGET_ENV}/${REPOSITORY_NAME}" -L1 -f "%I")
GITHUB_BRANCH="${GITHUB_REF#refs/heads/}"
if [[ -n "${OPEN_DEV_PR_NUMBER}" ]]; then # we already have an open PR for deploying this app, update it
  # Checkout the open PR we found
  hub pr checkout "${OPEN_DEV_PR_NUMBER}"
  cd "${TARGET_PROJECT}/${TARGET_ENV}"

  kustomize edit set image "${IMAGE_REGISTRY}/pw-web-cms:${APP_VERSION}"

  hub commit -am "update: \`${REPOSITORY_NAME}\` to \`${APP_VERSION}\`"
  # Push changes to our int release branch and update the PR
  hub push -f -u origin "release-${TARGET_ENV}/${REPOSITORY_NAME}"
  hub issue update "${OPEN_DEV_PR_NUMBER}" -m "Deploy \`${GITHUB_REPOSITORY}\` version \`${APP_VERSION}\` to \`${TARGET_ENV}\`" -m "${PR_BODY}" -l "release/${TARGET_ENV},awaiting-review"
else # open a pr
  # Checkout a new branch for the PR
  hub checkout -b "release-${TARGET_ENV}/${REPOSITORY_NAME}"
  cd "${TARGET_PROJECT}/${TARGET_ENV}"

  kustomize edit set image "${IMAGE_REGISTRY}/pw-web-cms:${APP_VERSION}"

  hub commit -am "update: \`${REPOSITORY_NAME}\` to \`${APP_VERSION}\`"
  # Push the changes up and raise a new PR
  hub push -f -u origin "release-${TARGET_ENV}/${REPOSITORY_NAME}"
  hub pull-request -m "Deploy \`${GITHUB_REPOSITORY}\` version \`${APP_VERSION}\` to \`${TARGET_ENV}\`" -m "${PR_BODY}" -l "release/${TARGET_ENV},awaiting-review" -b "${TARGET_BRANCH}" -r BSFDV/core
fi
