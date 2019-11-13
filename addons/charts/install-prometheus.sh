#!/bin/sh
BASEPATH=`pwd`
helm install -n prometheus ${BASEPATH}/prometheus-2.13.1 -f install-prometheus-values.yaml --namespace=kube-monitor