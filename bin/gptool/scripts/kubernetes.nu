def "main kubernetes create" [] {
    print $"(ansi yellow_bold)Création du cluster k8s (ansi red_bold)cluster-main(ansi reset)"

    talosctl cluster create docker --name cluster-main --subnet 10.20.0.0/24
    talosctl config context cluster-main
    talosctl config nodes 10.20.0.2 10.20.0.3

    kubectl config use-context admin@cluster-main

    kubectl create namespace argocd
    kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

    echo "⏳ Waiting for argocd-server to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

    let argocdPassword = "password123123!!!"

    let initialPassword = argocd admin initial-password -n argocd | head -n 1

    argocd login --port-forward --port-forward-namespace argocd --username admin --password ($initialPassword) --insecure argocd-server

    argocd account update-password --port-forward --port-forward-namespace argocd --insecure --current-password ($initialPassword) --new-password ($argocdPassword)

    kubectl delete secret argocd-initial-admin-secret -n argocd

    argocd repo add https://github.com/gpasini/gpcorp-infra.git --insecure --port-forward --port-forward-namespace argocd

    kubectl apply -f ./argocd-setup/ -n argocd --server-side --force-conflicts

    echo "✅ Cluster installed."
}

def "main kubernetes destroy" [] {
    let name = "cluster-main"

    print $"(ansi yellow_bold)Suppression du cluster k8s (ansi red_bold)cluster-main(ansi reset)"

    kubectl config unset current-context
    talosctl config add talos-default 
    talosctl config context talos-default

    talosctl cluster destroy --name cluster-main
    talosctl config remove -y cluster-main
    kubectl config delete-context admin@cluster-main
    kubectl config delete-cluster cluster-main
    kubectl config delete-user admin@cluster-main

}