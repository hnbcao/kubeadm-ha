#!/bin/sh
BASEPATH=`pwd`
helm install -n grafana ${BASEPATH}/grafana-6.4.2 -f install-grafana-values.yaml --namespace=kube-monitor