#!/bin/sh
BASEPATH=`pwd`
# helm2
helm install -n grafana ${BASEPATH}/gitlab-1.8.1 -f install-gitlab-values.yaml --namespace=kube-gitlab

# helm3
helm install grafana ${BASEPATH}/gitlab-1.8.1 -f install-gitlab-values.yaml -n kube-gitlab