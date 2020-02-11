#!/usr/bin/env bash

HELM2_VERSION=v2.8.2
HELM3_VERSION=v3.0.3

[ -f .travis.env ] && source .travis.env

if [ "${1}" == "install_helm" ]; then
    if ! helm3 version --client --short | grep "${HELM3_VERSION}"; then
        if [ ! -f ./get_helm.sh ]; then
          curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get > get_helm.sh &&\
          chmod 700 get_helm.sh
        fi &&\
        ./get_helm.sh --version "${HELM3_VERSION}" &&\
        sudo mv /usr/local/bin/helm /usr/local/bin/helm3 &&\
        echo helm3 version: &&\
        helm3 version --client --short | grep "${HELM3_VERSION}"
        [ "$?" != "0" ] && echo failed helm3 installation && exit 1
    fi
    if ! helm version --client --short | grep "Client: ${HELM2_VERSION}+"; then
        if [ ! -f ./get_helm.sh ]; then
          curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get > get_helm.sh &&\
          chmod 700 get_helm.sh
        fi &&\
        ./get_helm.sh --version "${HELM2_VERSION}" &&\
        echo helm version: &&\
        helm version --client --short | grep "Client: ${HELM2_VERSION}+"
        [ "$?" != "0" ] && echo failed helm client installation && exit 1
    fi
    rm -f get_helm.sh

elif [ "${1}" == "script" ]; then
    latest_tag=`eval 'echo $LATEST_IMAGE_TAG_'${TRAVIS_BRANCH}`
    [ "${latest_tag}" == "" ] \
        && latest_tag="${LATEST_IMAGE_TAG}"
    [ "${latest_tag}" == "" ] \
        && latest_tag=latest
    docker pull "${DOCKER_IMAGE}:${latest_tag}"
    docker build --cache-from "${DOCKER_IMAGE}:latest" -t "${DOCKER_IMAGE}:${latest_tag}" .
    [ "$?" != "0" ] && echo failed script && exit 1

elif [ "${1}" == "deploy" ]; then
    tag="${TRAVIS_COMMIT}"
    [ "${tag}" == "" ] && echo empty tag && exit 1
    latest_tag=`eval 'echo $LATEST_IMAGE_TAG_'${TRAVIS_BRANCH}`
    [ "${latest_tag}" == "" ] && latest_tag="${LATEST_IMAGE_TAG}"
    [ "${latest_tag}" == "" ] && latest_tag=latest
    chart_name=`eval 'echo $DEPLOY_VALUES_CHART_NAME_'${TRAVIS_BRANCH}`
    [ "${chart_name}" == "" ] && chart_name="${DEPLOY_VALUES_CHART_NAME}"
    image_prop=`eval 'echo $DEPLOY_VALUES_IMAGE_PROP_'${TRAVIS_BRANCH}`
    [ "${image_prop}" == "" ] && image_prop="${DEPLOY_VALUES_IMAGE_PROP}"
    yaml_update_file=`eval 'echo $DEPLOY_YAML_UPDATE_FILE_'${TRAVIS_BRANCH}`
    [ "${yaml_update_file}" == "" ] && yaml_update_file="${DEPLOY_YAML_UPDATE_FILE}"
    deploy_commit_message=`eval 'echo $DEPLOY_COMMIT_MESSAGE_'${TRAVIS_BRANCH}`
    [ "${deploy_commit_message}" == "" ] && deploy_commit_message="${DEPLOY_COMMIT_MESSAGE}"
    docker login -u "${DOCKER_USER:-$DOCKER_USERNAME}" -p "${DOCKER_PASS:-$DOCKER_PASSWORD}" &&\
    docker push "${DOCKER_IMAGE}:${latest_tag}" &&\
    docker tag "${DOCKER_IMAGE}:${latest_tag}" "${DOCKER_IMAGE}:${tag}" &&\
    docker push "${DOCKER_IMAGE}:${tag}"
    [ "$?" != "0" ] && echo failed docker push && exit 1
    echo "${TRAVIS_COMMIT_MESSAGE}" | grep -- --no-deploy && echo skipping deployment && exit 0
    if [ "${SSH_DEPLOY_KEY_OPENSSL_CMD}" != "" ]; then
        PUSH_PARAMS="git@github.com:${K8S_OPS_REPO_SLUG}.git ${K8S_OPS_REPO_BRANCH}"
        ! eval "${SSH_DEPLOY_KEY_OPENSSL_CMD}" && echo failed to decrypt github deploy key && exit 1
        SSH_DEPLOY_KEY_VOLUME_ARG="-v `pwd`/${DEPLOY_VALUES_CHART_NAME}_github_deploy_key.id_rsa:/tmp/${DEPLOY_VALUES_CHART_NAME}_github_deploy_key.id_rsa"
        SSH_DEPLOY_KEY_ENV_ARG="-e SSH_DEPLOY_KEY_FILE=/tmp/${DEPLOY_VALUES_CHART_NAME}_github_deploy_key.id_rsa"
    else
        PUSH_PARAMS="https://${GITHUB_TOKEN}@github.com/${K8S_OPS_REPO_SLUG}.git ${K8S_OPS_REPO_BRANCH}"
    fi
    docker run -e CLONE_PARAMS="--branch ${K8S_OPS_REPO_BRANCH} https://github.com/${K8S_OPS_REPO_SLUG}.git" \
               -e YAML_UPDATE_JSON='{"'"${chart_name}"'":{"'"${image_prop}"'":"'"${DOCKER_IMAGE}:${tag}"'"}}' \
               -e YAML_UPDATE_FILE="${yaml_update_file}" \
               -e GIT_USER_EMAIL="${DEPLOY_GIT_EMAIL}" \
               -e GIT_USER_NAME="${DEPLOY_GIT_USER}" \
               -e GIT_COMMIT_MESSAGE="${deploy_commit_message}" \
               -e PUSH_PARAMS="${PUSH_PARAMS}" \
               $SSH_DEPLOY_KEY_VOLUME_ARG $SSH_DEPLOY_KEY_ENV_ARG \
               orihoch/github_yaml_updater
    [ "$?" != "0" ] && echo failed github yaml update && exit 1

elif [ "${1}" == "setup" ]; then
    echo "Setting up continuous deployment for an external app repository"
    echo Create a dedicated user on docker hub for each project and use organizations to limit access
    echo The user should have write access to the relevant project
    read -p "Docker user: " DOCKER_USER
    read -p "Docker password: " DOCKER_PASS
    read -p "Docker image (repo/name): " DOCKER_IMAGE
    echo the K8S repo will usually be hasadna/hasadna-k8s on branch master
    read -p "K8S repo slug: " K8S_OPS_REPO_SLUG
    read -p "K8S repo branch: " K8S_OPS_REPO_BRANCH
    echo details of the app configuration on the k8s repo
    read -p "App's chart name: " DEPLOY_VALUES_CHART_NAME
    read -p "App's image property name: " DEPLOY_VALUES_IMAGE_PROP
    echo the app repo slug is used to get the encrypted travis env vars
    read -p "App's repo slug: " APP_REPO_SLUG
    echo this is the file in the k8s repo that stores the updated image names
    read -p "Relative path to values.auto-updated.yaml in the K8S repo: " DEPLOY_YAML_UPDATE_FILE
    echo these details are only used in the commit message
    read -p "Git user email: " DEPLOY_GIT_EMAIL
    read -p "Git user name: " DEPLOY_GIT_USER
    echo this will be the commit message on updates to the k8s repo
    read -p "Automatic update commit message: " DEPLOY_COMMIT_MESSAGE
    echo create a deploy key for the k8s repo with write permissions
    # read -p "GitHub token: " GITHUB_TOKEN
    read -p "Path to the private ssh deploy key: " SSH_DEPLOY_KEY
    ENCRYPTED_DOCKER_USER=$(travis encrypt --repo "${APP_REPO_SLUG}" "DOCKER_USER=${DOCKER_USER}" --no-interactive)
    ENCRYPTED_DOCKER_PASS=$(travis encrypt --repo "${APP_REPO_SLUG}" "DOCKER_PASS=${DOCKER_PASS}" --no-interactive)
    # ENCRYPTED_GITHUB_TOKEN=$(travis encrypt --repo "${APP_REPO_SLUG}" "GITHUB_TOKEN=${GITHUB_TOKEN}" --no-interactive)
    SSH_DEPLOY_KEY_OPENSSL_CMD=$(travis encrypt-file --repo "${APP_REPO_SLUG}" \
                                                     "${SSH_DEPLOY_KEY}" \
                                                     "${DEPLOY_VALUES_CHART_NAME}_github_deploy_key.id_rsa.enc" \
                                                     --decrypt-to "${DEPLOY_VALUES_CHART_NAME}_github_deploy_key.id_rsa" \
                                                     -p --no-interactive | grep '^openssl ')
    echo 1. copy the key file to the app repo and commit: "${DEPLOY_VALUES_CHART_NAME}_github_deploy_key.id_rsa.enc"
    echo 2. update the app .travis.yml pasting the following directly or integrate with existing .travis.yml
    echo
    echo
    echo "language: bash
sudo: required
env:
  global:
    - secure: ${ENCRYPTED_DOCKER_USER}
    - secure: ${ENCRYPTED_DOCKER_PASS}
    - K8S_OPS_REPO_BRANCH=${K8S_OPS_REPO_BRANCH}
    - K8S_OPS_REPO_SLUG=${K8S_OPS_REPO_SLUG}
    - DOCKER_IMAGE=${DOCKER_IMAGE}
    - DEPLOY_YAML_UPDATE_FILE=${DEPLOY_YAML_UPDATE_FILE}
    - DEPLOY_VALUES_CHART_NAME=${DEPLOY_VALUES_CHART_NAME}
    - DEPLOY_VALUES_IMAGE_PROP=${DEPLOY_VALUES_IMAGE_PROP}
    - DEPLOY_COMMIT_MESSAGE="'"'"${DEPLOY_COMMIT_MESSAGE}"'"'"
    - DEPLOY_GIT_EMAIL=${DEPLOY_GIT_EMAIL}
    - DEPLOY_GIT_USER=${DEPLOY_GIT_USER}
    - SSH_DEPLOY_KEY_OPENSSL_CMD="'"'"${SSH_DEPLOY_KEY_OPENSSL_CMD}"'"'"
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
