#!/usr/bin/env bash
# ЛАБА 4.10 · «Трафик не идёт»: чеклист на сломанном сервисе
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

# Первый блок работает и при копировании из VS Code в новый терминал:
# путь вычисляется от корня git clone, а не от случайного текущего каталога.
REPO_ROOT="$(git rev-parse --show-toplevel)"
LAB_DIR="$REPO_ROOT/04_ЧАСТЬ_4_TRAFFIC/42_4.10_broken_service"
SOURCE_ROOT="$REPO_ROOT"
cd "$LAB_DIR"

kubectl apply -f ./devops_may_cry.yaml
kubectl -n traffic-lab rollout status deploy/devops-may-cry --timeout=180s
kubectl apply -f ./debug-client.yaml
kubectl -n traffic-lab wait --for=condition=Ready pod/client --timeout=180s

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: devops-may-cry-broken
  namespace: traffic-lab
spec:
  selector:
    app: nigth-shift
  ports:
    - port: 80
      targetPort: 8080
EOF

kubectl -n traffic-lab exec client --   curl -m3 -s -o /dev/null -w '%{http_code}
' devops-may-cry-broken || true
kubectl -n traffic-lab exec client -- dig +search +short devops-may-cry-broken
kubectl -n traffic-lab get endpointslice   -l kubernetes.io/service-name=devops-may-cry-broken -o wide
# DNS и ClusterIP есть, но endpoints пусты: это не поломка Go-приложения.
kubectl -n traffic-lab describe svc devops-may-cry-broken | grep Selector
kubectl -n traffic-lab get pods --show-labels

kubectl -n traffic-lab patch svc devops-may-cry-broken   -p '{"spec":{"selector":{"app":"devops-may-cry"}}}'
kubectl -n traffic-lab get endpointslice   -l kubernetes.io/service-name=devops-may-cry-broken -o wide
kubectl -n traffic-lab exec client --   curl -fsS -o /dev/null -w '%{http_code}
' devops-may-cry-broken
kubectl -n traffic-lab delete svc devops-may-cry-broken
