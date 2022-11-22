#!/bin/bash

create_log_folder() {
    timestamp=$(date +%Y_%b_%d_%H%M%S)

    if [ ! -d "deployments/${1}" ]
    then
        mkdir "deployments/${NETWORK}"
    fi

    logs_dir="deployments/${NETWORK}/${timestamp}"
    mkdir $logs_dir
}