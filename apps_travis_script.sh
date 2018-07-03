#!/usr/bin/env bash

HELM_VERSION=v2.8.2

if [ "${1}" == "install_helm" ]; then
    if ! helm version --client --short | grep "Client: ${HELM_VERSION}+"; then
        curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get > get_helm.sh &&\
        chmod 700 get_helm.sh &&\
        ./get_helm.sh --version "${HELM_VERSION}" &&\
        helm version --client --short | grep "Client: ${HELM_VERSION}+"
        [ "$?" != "0" ] && echo failed helm client installation && exit 1
        rm get_helm.sh
    fi

elif [ "${1}" == "script" ]; then
    docker pull "${DOCKER_IMAGE}:latest"
    docker build --cache-from "${DOCKER_IMAGE}:latest" -t "${DOCKER_IMAGE}:latest" .
    [ "$?" != "0" ] && echo failed script && exit 1

elif [ "${1}" == "deploy" ]; then
    tag="${TRAVIS_COMMIT}"
    [ "${tag}" == "" ] && echo empty tag && exit 1
    docker login -u "${DOCKER_USER:-$DOCKER_USERNAME}" -p "${DOCKER_PASS:-$DOCKER_PASSWORD}" &&\
    docker push "${DOCKER_IMAGE}:latest" &&\
    docker tag "${DOCKER_IMAGE}:latest" "${DOCKER_IMAGE}:${tag}" &&\
    docker push "${DOCKER_IMAGE}:${tag}"
    [ "$?" != "0" ] && echo failed docker push && exit 1
    docker run -e CLONE_PARAMS="--branch ${K8S_OPS_REPO_BRANCH} https://github.com/${K8S_OPS_REPO_SLUG}.git" \
               -e YAML_UPDATE_JSON='{"'"${DEPLOY_VALUES_CHART_NAME}"'":{"'"${DEPLOY_VALUES_IMAGE_PROP}"'":"'"${DOCKER_IMAGE}:${tag}"'"}}' \
               -e YAML_UPDATE_FILE="${DEPLOY_YAML_UPDATE_FILE}" \
               -e GIT_USER_EMAIL="${DEPLOY_GIT_EMAIL}" \
               -e GIT_USER_NAME="${DEPLOY_GIT_USER}" \
               -e GIT_COMMIT_MESSAGE="${DEPLOY_COMMIT_MESSAGE}" \
               -e PUSH_PARAMS="https://${GITHUB_TOKEN}@github.com/${K8S_OPS_REPO_SLUG}.git ${K8S_OPS_REPO_BRANCH}" \
               orihoch/github_yaml_updater
    [ "$?" != "0" ] && echo failed github yaml update && exit 1

elif [ "${1}" == "setup" ]; then
    echo "Setting up continuous deployment for an external app repository"
    read -p "Docker user: " DOCKER_USER
    read -p "Docker image name (not including the user prefix): " DOCKER_IMAGENAME
    read -p "Docker password: " DOCKER_PASS
    read -p "K8S repo slug: " K8S_OPS_REPO_SLUG
    read -p "K8S repo branch: " K8S_OPS_REPO_BRANCH
    read -p "App's chart name: " DEPLOY_VALUES_CHART_NAME
    read -p "App's image property name: " DEPLOY_VALUES_IMAGE_PROP
    read -p "App's repo slug" APP_REPO_SLUG
    read -p "Relative path to values.auto-updated.yaml in the K8S repo: " DEPLOY_YAML_UPDATE_FILE
    read -p "Git user email: " DEPLOY_GIT_EMAIL
    read -p "Git user name: " DEPLOY_GIT_USER
    read -p "Github token: " GITHUB_TOKEN
    ENCRYPTED_DOCKER_USER=$(travis encrypt --repo "${APP_REPO_SLUG}" "DOCKER_USER=${DOCKER_USER}" --no-interactive)
    ENCRYPTED_DOCKER_PASS=$(travis encrypt --repo "${APP_REPO_SLUG}" "DOCKER_PASS=${DOCKER_PASS}" --no-interactive)
    ENCRYPTED_GITHUB_TOKEN=$(travis encrypt --repo "${APP_REPO_SLUG}" "GITHUB_TOKEN=${GITHUB_TOKEN}" --no-interactive)
    echo "Use the following .travis.yml directly or integrate with existing .travis.yml"
    echo "--"
    echo "language: bash
sudo: required
env:
  global:
    - secure: ${ENCRYPTED_DOCKER_USER}
    - secure: ${ENCRYPTED_DOCKER_PASS}
    - secure: ${ENCRYPTED_GITHUB_TOKEN}
    - K8S_OPS_REPO_BRANCH=${K8S_OPS_REPO_BRANCH}
    - K8S_OPS_REPO_SLUG=${K8S_OPS_REPO_SLUG}
    - DOCKER_IMAGE=${DOCKER_USER}/${DOCKER_IMAGENAME}
    - DEPLOY_YAML_UPDATE_FILE=${DEPLOY_YAML_UPDATE_FILE}
    - DEPLOY_VALUES_CHART_NAME=${DEPLOY_VALUES_CHART_NAME}
    - DEPLOY_VALUES_IMAGE_PROP=${DEPLOY_VALUES_IMAGE_PROP}
    - DEPLOY_COMMIT_MESSAGE="'"'"automatic update of ${DOCKER_IMAGENAME}"'"'"
    - DEPLOY_GIT_EMAIL=${DEPLOY_GIT_EMAIL}
    - DEPLOY_GIT_USER=${DEPLOY_GIT_USER}
services:
  - docker
script:
  - curl -s https://raw.githubusercontent.com/hasadna/hasadna-k8s/master/apps_travis_script.sh > .travis.sh
  - bash .travis.sh script
deploy:
  skip_cleanup: true
  provider: script
  script: bash .travis.sh deploy
  on:
    branch: master
"
    echo "--"
    exit 0

else
    exit 1

fi

echo Great Success
exit 0
