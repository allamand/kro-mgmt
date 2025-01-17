function argocd_kill_port_forward (){
	pkill -9 -f "kubectl --context $1 port-forward svc/argocd-server -n argocd $2:80"
}

function argocd_credentials (){
	argocd_kill_port_forward $1 $2
    kubectl --context $1 port-forward svc/argocd-server -n argocd $2:80 >/dev/null 2>&1 &
    # wait for port-forward to be up
    sleep 3
	export ARGOCD_PWD=$(kubectl get secrets argocd-initial-admin-secret -n argocd --template='{{index .data.password | base64decode}}' --context $1)
    argocd login "localhost:$2" --plaintext --username admin --password $ARGOCD_PWD --name $1
	echo "ArgoCD Username: admin"
	echo "ArgoCD Password: $ARGOCD_PWD"
	echo "ArgoCD URL: $IDE_URL/proxy/$2"
}

function argocd_hub_credentials (){
	argocd_credentials kro-mgmt 8080
}
function argocd_workload-cluster1 (){
	argocd_credentials workload-cluster1 8081
}
function argocd_workload-cluster2 (){
	argocd_credentials workload-cluster2 8083
}

function argocd_workload-cluster3 (){
	argocd_credentials workload-cluster3 8083
}
