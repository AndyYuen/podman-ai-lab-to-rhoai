#! /bin/bash

# -----------------------------------------
# Wait for the operator to complete installation
# Input: a string containing parameters as comma-separated-values
# -----------------------------------------
waitTillOperatorInstalled()
{

    OPERATOR_NAME=$1
    NAMESPACE=$2
    # echo "${OPERATOR_NAME} ${NAMESPACE}"

    while true 
    do
            oc get csv -n ${NAMESPACE} 2>/dev/null | grep -i ${OPERATOR_NAME} | grep "Succeeded" > /dev/null
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
# Control the order of operator installation
# -----------------------------------------
for name in elasticsearch-operator jaeger-product kiali-ossm servicemeshoperator
do
    printSeparator
    DIR=../helm-operator-subscription/
    FILE=${DIR}values-${name}.yaml
    helm template ${DIR} --values ${FILE} | oc apply -f -

    OPERATOR_NAME=`cat ${FILE} | grep operatorName | awk '{ print $2;}'`
    NAMESPACE=`cat ${FILE}  | grep targetNamespace | awk '{ print $2;}'`
    waitTillOperatorInstalled ${OPERATOR_NAME} ${NAMESPACE}
    echo

done