#!/bin/bash

intall_cert_manager=true
intall_istio=true
install_auth2_proxy=true
install_dex=true
install_knative=true
####
install_knative_eventing=true
install_kubeflow_namespace=true
install_network_policies=true
install_kubeflow_roles=true
install_kubeflow_istio_resources=true
install_kubeflow_pipelines=true
install_kserve_and_models_web=true
install_katib=true
install_central_dashboard=true
install_admission_webhook=true
install_notebooks=true
install_pvc_viewer_controller=true
install_profiles_and_kubeflow_access_management=true
install_volumes_web_app=true
install_volumes_web_app=true
install_tensorboard=true
install_training_operator=true
install_user_namespaces=true
check_kubeflow_cluster_pods_running=true


if [ "$intall_cert_manager" = true ]; then
    echo -e "........ Installing cert-maneger.........................\n"
    kubectl kustomize common/cert-manager/base | kubectl apply -f -
    kubectl kustomize common/cert-manager/kubeflow-issuer/base | kubectl apply -f -
    echo "Waiting for cert-manager to be ready ..."
    kubectl wait --for=condition=ready pod -l 'app in (cert-manager,webhook)' --timeout=180s -n cert-manager
    kubectl wait --for=jsonpath='{.subsets[0].addresses[0].targetRef.kind}'=Pod endpoints -l 'app in (cert-manager,webhook)' --timeout=180s -n cert-manager
    echo -e "........ End Installing cert-maneger.........................\n"
fi
if [ "$intall_istio" = true ]; then
    echo -e "Installing Istio configured with external authorization...\n"
    kubectl kustomize common/istio-1-23/istio-crds/base | kubectl apply -f -
    kubectl kustomize common/istio-1-23/istio-namespace/base | kubectl apply -f -
    kubectl kustomize common/istio-1-23/istio-install/overlays/oauth2-proxy | kubectl apply -f -

    echo "Waiting for all Istio Pods to become ready..."
    kubectl wait --for=condition=Ready pods --all -n istio-system --timeout 300s
    echo -e "........ End Installing Istio.........................\n"
fi
if [ "$install_auth2_proxy" = true ]; then
    echo -e "Installing oauth2-proxy...\n"

    # Only uncomment ONE of the following overlays, they are mutually exclusive,
    # see `common/oauth2-proxy/overlays/` for more options.

    # OPTION 1: works on most clusters, does NOT allow K8s service account
    #           tokens to be used from outside the cluster via the Istio ingress-gateway.
    #
    kubectl kustomize common/oauth2-proxy/overlays/m2m-dex-only/ | kubectl apply -f -
    kubectl wait --for=condition=ready pod -l 'app.kubernetes.io/name=oauth2-proxy' --timeout=180s -n oauth2-proxy

    # Option 2: works on Kind, K3D, Rancher, GKE and many other clusters with the proper configuration, and allows K8s service account tokens to be used
    #           from outside the cluster via the Istio ingress-gateway. For example for automation with github actions.
    #           In the end you need to patch the issuer and jwksUri fields in the requestauthentication resource in the istio-system namespace 
    #           as for example done in /common/oauth2-proxy/overlays/m2m-dex-and-kind/kustomization.yaml
    #           Please follow the guidelines in the section Upgrading and extending below for patching.
    #           curl --insecure -H "Authorization: Bearer `cat /var/run/secrets/kubernetes.io/serviceaccount/token`"  https://kubernetes.default/.well-known/openid-configuration
    #           from a pod in the cluster should provide you with the issuer of your cluster.
    # 
    #kustomize build common/oauth2-proxy/overlays/m2m-dex-and-kind/ | kubectl apply -f -
    #kubectl wait --for=condition=ready pod -l 'app.kubernetes.io/name=oauth2-proxy' --timeout=180s -n oauth2-proxy
    #kubectl wait --for=condition=ready pod -l 'app.kubernetes.io/name=cluster-jwks-proxy' --timeout=180s -n istio-system

    # OPTION 3: works on most EKS clusters with  K8s service account
    #           tokens to be used from outside the cluster via the Istio ingress-gateway.
    #           You have to adjust AWS_REGION and CLUSTER_ID in common/oauth2-proxy/overlays/m2m-dex-and-eks/ first.
    #
    #kustomize build common/oauth2-proxy/overlays/m2m-dex-and-eks/ | kubectl apply -f -
    #kubectl wait --for=condition=ready pod -l 'app.kubernetes.io/name=oauth2-proxy' --timeout=180s -n oauth2-proxy
fi
if [ "$install_dex" = true ]; then
    echo -e "Installing Dex...\n"
    kubectl kustomize common/dex/overlays/oauth2-proxy | kubectl apply -f -
    kubectl wait --for=condition=ready pods --all --timeout=180s -n auth

#cat <<EOF | kubectl apply -f -
#    apiVersion: v1
#    kind: ConfigMap
#    metadata:
#        name: dex
#    data:
#        config.yaml: |
#            issuer: http://dex.auth.svc.cluster.local:5556/dex
#            storage:
#            type: kubernetes
#            config:
#                inCluster: true
#            web:
#            http: 0.0.0.0:5556
#            logger:
#            level: "debug"
#            format: text
#            oauth2:
#            skipApprovalScreen: true
#            enablePasswordDB: true
            #### WARNING YOU SHOULD NOT USE THE DEFAULT STATIC PASSWORDS
            #### and patch /common/dex/base/dex-passwords.yaml in a Kustomize overlay or remove it
#            staticPasswords:
#            - email: user@example.com
#            hashFromEnv: DEX_USER_PASSWORD
#            username: user
#            userID: "15841185641784"
#            staticClients:
            # https://github.com/dexidp/dex/pull/1664
#            - idEnv: OIDC_CLIENT_ID
#            redirectURIs: ["/oauth2/callback"]
#            name: 'Dex Login Application'
#            secretEnv: OIDC_CLIENT_SECRET
            #### Here come the connectors to OIDC providers such as Azure, GCP, GitHub, GitLab etc.
            #### Connector config values starting with a "$" will read from the environment.
#           connectors:
#            - type: oidc
#            id: azure
#            name: azure
#            config:
#                issuer: https://login.microsoftonline.com/$TENANT_ID/v2.0
#                redirectURI: https://$KUBEFLOW_INGRESS_URL/dex/callback
#                clientID: $AZURE_CLIENT_ID
#                clientSecret: $AZURE_CLIENT_SECRET
#                insecureSkipEmailVerified: true
#                scopes:
#                - openid
#                - profile
#                - email
#                #- groups # groups might be used in the future
#EOF
fi

if [ "$install_knative" = true ]; then
    echo -e "........ Installing knative.........................\n"
    kubectl kustomize common/knative/knative-serving/overlays/gateways | kubectl apply -f -
    kubectl kustomize common/istio-1-23/cluster-local-gateway/base | kubectl apply -f -
    kubectl wait --for=condition=ready pods --all --timeout=180s -n knative-serving
fi
if [ "$install_knative_eventing" = true ]; then
    echo -e "........ Installing knative-eventing.........................\n"
    kubectl kustomize common/knative/knative-eventing/base | kubectl apply -f -
    kubectl wait --for=condition=ready pods --all --timeout=180s -n knative-eventing
fi
if [ "$install_kubeflow_namespace" = true ]; then
    echo -e "........ Installing kubeflow manager.........................\n"
    kubectl kustomize common/kubeflow-namespace/base | kubectl apply -f -
fi
if [ "$install_network_policies" = true ]; then
    echo -e "........ Installing network policies.........................\n"
    kubectl kustomize common/networkpolicies/base | kubectl apply -f -
fi
if [ "$install_kubeflow_roles" = true ]; then
    echo -e "........ Installing kubeflow roles.........................\n"
    kubectl kustomize common/kubeflow-roles/base | kubectl apply -f -
fi
if [ "$install_kubeflow_istio_resources" = true ]; then
    echo -e "........ Installing kubeflow istio resources.........................\n"
    kubectl kustomize common/istio-1-23/kubeflow-istio-resources/base | kubectl apply -f -
fi
if [ "$install_kubeflow_pipelines" = true ]; then
    echo -e "........ Installing kubeflow pipelines.........................\n"
    kubectl kustomize apps/pipeline/upstream/env/cert-manager/platform-agnostic-multi-user | kubectl apply -f -
fi
if [ "$install_katib" = true ]; then
    echo -e "........ Installing Katib.........................\n"
    kubectl kustomize apps/katib/upstream/installs/katib-with-kubeflow | kubectl apply -f -
fi
if [ "$install_central_dashboard" = true ]; then
    echo -e "........ Installing Central Dashboard.........................\n"
    kubectl kustomize apps/centraldashboard/overlays/oauth2-proxy | kubectl apply -f -
fi
if [ "$install_admission_webhook" = true ]; then
    echo -e "........ Installing Admission Webhook.........................\n"
    kubectl kustomize apps/admission-webhook/upstream/overlays/cert-manager | kubectl apply -f -
fi
if [ "$install_notebooks" = true ]; then
    echo -e "........ Installing Notebooks.........................\n"
    kubectl kustomize apps/jupyter/notebook-controller/upstream/overlays/kubeflow | kubectl apply -f -
    kubectl kustomize apps/jupyter/jupyter-web-app/upstream/overlays/istio | kubectl apply -f -
fi
if [ "$install_profiles_and_kubeflow_access_management" = true ]; then
    echo -e "........ Installing Kubeflow Access Management.........................\n"
    kubectl kustomize apps/profiles/upstream/overlays/kubeflow | kubectl apply -f -
fi
if [ "$install_pvc_viewer_controller" = true ]; then
    echo -e "........ Installing viewer controller.........................\n"
    kubectl kustomize apps/pvcviewer-controller/upstream/default | kubectl apply -f -
fi
if [ "$install_volumes_web_app" = true ]; then
    echo -e "........ Installing Volumes Web App.........................\n"
    kubectl kustomize apps/volumes-web-app/upstream/overlays/istio | kubectl apply -f -
fi
if [ "$install_tensorboard" = true ]; then
    echo -e "........ Installing Tensorboard.........................\n"
    kubectl kustomize apps/tensorboard/tensorboards-web-app/upstream/overlays/istio | kubectl apply -f -
    kubectl kustomize apps/tensorboard/tensorboard-controller/upstream/overlays/kubeflow | kubectl apply -f -
fi
if [ "$install_training_operator" = true ]; then
    echo -e "........ Installing Training Operator.........................\n"
    kubectl kustomize apps/training-operator/upstream/overlays/kubeflow | kubectl apply -f -
fi
if [ "$install_user_namespaces" = true ]; then
    echo -e "........ Installing User Namespaces.........................\n"
    kubectl kustomize common/user-namespace/base | kubectl apply -f -
fi
if [ "$install_kserve_and_models_web" = true ]; then
    echo -e "........ Installing Kserve and Models Web.........................\n"
    kubectl kustomize contrib/kserve/kserve | kubectl apply --server-side --force-conflicts -f -
    kubectl kustomize contrib/kserve/models-web-app/overlays/kubeflow | kubectl apply -f -
fi

if [ "$check_kubeflow_cluster_pods_running" = true ]; then
    kubectl get pods -n cert-manager
    kubectl get pods -n istio-system
    kubectl get pods -n auth
    kubectl get pods -n knative-eventing
    kubectl get pods -n knative-serving
    kubectl get pods -n kubeflow
    kubectl get pods -n kubeflow-user-example-com

    sleep 10

    echo "Accessing kubeflow via Port-forwarding........."
    kubectl port-forward svc/istio-ingressgateway -n istio-system 8080:80
fi