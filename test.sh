#!/bin/bash

# This script automates the creation of a Docker image and pushes it to 
# Azure's Container Registry (acr) based on the requirements of lab 4. 

REGISTRY_NAME=w255mids
ACR_DOMAIN=${REGISTRY_NAME}.azurecr.io
NAMESPACE=$(az account list --all | jq -r '.[0].user.name' | awk -F@ '{print $1}' | sed 's/\.//g; s/_/-/g')
IMAGE_NAME=lab4
TAG=""
FQDN=""



# Use this to pull down the last tag pushed to the registry
#az acr manifest list-metadata $ACR_DOMAIN/$NAMESPACE/$IMAGE_NAME | jq -r '.[0].tags[0]'
# 30a44a7


display_menu() {
    echo 
    echo "*******************"
    echo "*** Lab 4 Menu *** "
    echo "*******************"
    echo 
    echo "0. Get the status of the project"
    echo "1. Commit project and return short hash"
    echo "2. Build image with tag of short hash"
    echo "3. Tag image with FQDN" 
    echo "4. Push image to AKS registry"
    echo "5. Deploy app in AKS"
    echo "6. Prune Docker" 
    echo "7. Exit"
    echo
}

git_status() {
    echo 
    git status
}

commit_to_repo() {
    echo "Inside of commit_to_repo"
    read -p "Enter commit message: " commit_msg
    echo $commit_msg
    git add . 
    git commit -m "$commit_msg"
    git push
    TAG=$(git rev-parse --short HEAD)
    echo
    echo "Short Commit Hash: " $TAG
}

build_image() {
    # Check if TAG is set and if not prompt user 
    if [ -z "$TAG" ]; then 
        read -p "Enter tag value: " TAG
    fi 

    # Find [TAG] string in _copy and replace with TAG value by overwriting patch file
    sed "s/\[TAG\]/${TAG}/g" .k8s/overlays/prod/patch-deployment-lab4_copy.yaml > .k8s/overlays/prod/patch-deployment-lab4.yaml

    # Check if image already exists and if not build it 
    if docker image inspect $IMAGE_NAME &>/dev/null; then 
        echo "Docker image $IMAGE_NAME already exists. Continuing..."
    else
        echo "Docker image $IMAGE_NAME does not exist. Building..."
        docker build --platform linux/amd64 -t $IMAGE_NAME:$TAG .

        # Verify a successful build
        if [ $? -eq 0 ]; then 
            echo "Docker image $IMAGE_NAME built sucessfully."
        else 
            echo "Failed to build Docker image $IMAGE_NAME. Please fix."
            exit 1
        fi
    fi
}

tag_image() {
    FQDN=$ACR_DOMAIN/$NAMESPACE/$IMAGE_NAME:$TAG
    echo "Taggin Image with FQDN: $FQDN"
    docker tag $IMAGE_NAME:$TAG $FQDN 
}

push_to_aks() {
    echo "Inside push_to_aks"
    az acr login --name $REGISTRY_NAME
    docker push $FQDN
}

deploy_app() {
    read -p "Will this be deployed to prod? (y|n)?" env

    if [ "env" == "y" ];  then 
        echo "Deploying to prod..."
        kubectl kustomize .k8s/overlays/prod
        echo
        kubectl apply -k .k8s/overlays/prod
    elif [ "env" == "n" ]; then 
        echo "Deploying to dev..."
        kubectl kustomize .k8s/overlays/dev
        echo
        kubectl apply -k .k8s/overlays/dev
    else 
        echo "[ERROR] Input must be 'y' or 'n'."
    fi 
}

main() {
    while true; do 
        display_menu 

        read -p "Enter your selection: " selection 

        case $selection in 
            0) git_status ;; 
            1) commit_to_repo ;;
            2) build_image ;;
            3) tag_image ;;
            4) push_to_aks ;; 
            5) deploy_app ;;
            6) prune_docker ;; 
            7) echo "Exiting..."; exit ;;
            *) echo "Please select a valid option from the menu." ;;
        esac
    done 
}

main
