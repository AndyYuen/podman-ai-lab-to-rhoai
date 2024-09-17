#! /bin/bash

oc  get clusterrolebindings | grep "cluster-admin" > /dev/null 2>&1
if [ $? == 1 ] ; then
  echo "*****************************************************"
  echo "Please login to OpenShift using an account with cluster-admin privileges and rerun command."
  echo "*****************************************************"
  exit 1;
fi

# -----------------------------------------
# Wait till all target pods are running (maybe 1 or more)
# -----------------------------------------
waitTillPodsRunning()
{
    NAMESPACE=$1
    POD=$2

    # sleep a while for pod to start
    sleep 15
    
    while true 
    do
        not_ready=false
        PODS=`oc get pod -n ${NAMESPACE} 2>/dev/null | tail -n +1 | grep -i ${POD}`
        echo ${PODS} | while read -r line; 
        do
            echo ${line} | grep "Running"
            [ $? -ne 0 ] && not_ready=true && break
        done > /dev/null

        [ $not_ready=false ] && break
        sleep 10
    done

    oc get pod -n ${NAMESPACE} 2>/dev/null | tail -n +1 | grep -i ${POD} | \
    while read -r line;
    do 
        PODNAME=`echo ${line} | cut -f1 -d ' '`
        echo -e "Pod ${GREEN}Running${RESET}: '${PODNAME}' in project '${NAMESPACE}'"
    done

}

# -----------------------------------------
# Wait for the operator to complete installation
# Input: Operator
# -----------------------------------------
waitTillOperatorInstalled()
{

    OPERATOR_NAME=$1
    NAMESPACE=$2

    while true 
    do
            oc get csv -n ${NAMESPACE} 2>/dev/null | grep -i ${OPERATOR_NAME} | grep 'Succeeded\|Failed' > /dev/null
            [ $? -eq 0 ] && break
            echo "Waiting for ${OPERATOR_NAME}..."
            sleep 10
    done
    OPERATOR_NAME_LONG=`oc get csv -n ${NAMESPACE} | grep ${OPERATOR_NAME} | cut -f1 -d ' '`
    STATE="${RED}Failed${RESET}"
    oc get csv -n ${NAMESPACE} 2>/dev/null | grep -i ${OPERATOR_NAME} | grep Succeeded > /dev/null
    [ $? -eq 0 ] && STATE="${GREEN}Succeeded${RESET}"
    echo -e "Operator State: '${OPERATOR_NAME_LONG}' in project '${NAMESPACE}' ${STATE}"
}

printSeparator()
{
    python -c "print('*' * 64)"
}

BLACK="\033[1;30m"
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
MAGENTA="\033[1;35m"
CYAN="\033[1;36m"
WHITE="\033[1;37m"
RESET="\033[0m"
# -----------------------------------------
# Deploy the OpenShift AI operator
# namespace: redhat-ods-operator
# -----------------------------------------
printSeparator
echo "Deploying the OpenShift AI operator..."
oc apply -k ../components/openshift-ai/operator/overlays/fast
waitTillOperatorInstalled rhods-operator redhat-ods-operator
echo

# -----------------------------------------
# Deploy the OpenShift AI instance
# namespace: redhat-ods-applications
# DataScienceCluster: default-dsc
# DSCInitialization: default-dsci
# OdhDashboardConfig: odh-dashboard-config
# -----------------------------------------
printSeparator
echo "Deploying the OpenShift AI instance..."
oc apply -k ../components/openshift-ai/instance/overlays/fast
waitTillPodsRunning redhat-ods-operator rhods-operator-
echo

# -----------------------------------------
# Deploy Elasticsearch Vector DB
# namespace: elastic-vectordb
# -----------------------------------------
printSeparator
echo "Deploying Elasticsearch Vector DB..."
oc apply -k ../components/elasticsearch/base/
waitTillPodsRunning elastic-vectordb elastic-operator-
echo

# -----------------------------------------
# Create an Elasticsearch cluster instance after Elasticsearch operatior installed
# -----------------------------------------
printSeparator
echo "Creating an Elasticsearch cluster instance..."
oc apply -f ../components/elasticsearch/cluster/instance.yaml
waitTillPodsRunning elastic-vectordb elasticsearch-sample-es-default-
echo

# -----------------------------------------
# Show OpenShift AI Dashboard URL
# -----------------------------------------
printSeparator
DASHBOARD=`oc get route rhods-dashboard -n redhat-ods-applications --output jsonpath={.spec.host}`
echo "OpenShift AI Dashboard URL:"
echo -e "${CYAN}https://${DASHBOARD}${RESET}"
echo

# -----------------------------------------
# Show Workbench Configmap Environment variables
# -----------------------------------------
printSeparator
CLUSTER_IP=`oc get service elasticsearch-sample-es-http -n elastic-vectordb | tail -n +2 | awk '{print $3; }'`
MYPASSWORD=`oc get secret elasticsearch-sample-es-elastic-user -n elastic-vectordb -o jsonpath="{.data['elastic']}" | base64 -d`
echo "Workbench Configmap Environment variable key/value pairs:"
echo -e "${CYAN}CONNECTION_STRING: ${CLUSTER_IP}:9200${RESET}"
echo -e "${CYAN}PASSWORD: ${MYPASSWORD}${RESET}"
echo

# -----------------------------------------
# Deploy s3 Storage (Minio)
# namespace: minio
# route: minio-ui
# -----------------------------------------
printSeparator
echo "Deploying s3 Storage (Minio)..."
oc apply -k ../components/minio/base
waitTillPodsRunning minio minio-
echo

# -----------------------------------------
# Show Minio Web Console URL
# -----------------------------------------
MINIO=`oc get route minio-ui -n minio --output jsonpath={.spec.host}`
printSeparator
echo "Minio Web Console URL:"
echo -e "${CYAN}https://${MINIO}${RESET}"
echo
echo "Minio API URL:"
MINIO_API=`oc get route minio-api -n minio --output jsonpath={.spec.host}`
echo -e "${CYAN}https://${MINIO_API}${RESET}"
echo

# -----------------------------------------
# Deploy Service Mesh
# namespace: istio-system
# Note: Use a separate shell script to install Service Mesh and dependencies
# -----------------------------------------
printSeparator
echo "Deploying Service Mesh..."
oc apply -k ../components/openshift-servicemesh/operator/overlays/stable
waitTillOperatorInstalled servicemeshoperator openshift-operators
echo

# -----------------------------------------
# Deploy Serverless Operator
# namespace: openshift-serverless
# -----------------------------------------
printSeparator
echo "Deploying Serverless..."
oc apply -k ../components/openshift-serverless/operator/overlays/stable
waitTillOperatorInstalled serverless-operator openshift-serverless
echo

# -----------------------------------------
# Deploy Serverless Instance
# namespace: openshift-serverless
# -----------------------------------------
# printSeparator
# echo "Deploying Serverless Instance..."
# oc apply -k ../components/openshift-serverless/instance/knative-serving/overlays/default
# waitTillPodsRunning minio minio-
# echo


# -----------------------------------------
# Create ingress-certs folder in project root
# With files: tls.crt and tls.key
# Use them in our OpenShift AI data science cluster,
# And enable the Single Model Serving runtime for OpenShift AI
# -----------------------------------------
printSeparator
echo "Deploying Single Model Knative Serving runtime..."
CERTS=router-metrics-certs-default
oc extract secret/${CERTS} -n openshift-ingress --to=ingress-certs --confirm
oc create secret generic knative-serving-cert -n istio-system --from-file=./ingress-certs/ --dry-run=client -o yaml | oc apply -f -
# oc apply -k ../components/model-server/components-serving
while true 
do
    oc get knativeserving.operator.knative.dev/knative-serving -n knative-serving | grep knative-serving | awk '{print $3;}' | grep True > /dev/null
    [ $? -eq 0 ] && break
    echo "Waiting for knative-serving to be ready..."
    sleep 10
done
echo -e "knative-serving status: ${GREEN}Succeeded${RESET}"
echo