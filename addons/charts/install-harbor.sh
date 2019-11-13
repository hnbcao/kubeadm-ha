#!/bin/sh
BASEPATH=`pwd`
helm install -n harbor ${BASEPATH}/harbor-1.1.5 -f install-harbor-values.yaml --namespace=harbor