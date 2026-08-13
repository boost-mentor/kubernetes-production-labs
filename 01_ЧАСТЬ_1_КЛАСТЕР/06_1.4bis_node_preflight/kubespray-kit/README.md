# Kubespray recording kit

Этот каталог хранит только наш inventory contract и безопасные обвязки.
Исходный Kubespray не копируется в учебный репозиторий: `bootstrap.sh`
клонирует официальный tag `v2.31.0`, чтобы в кадре был настоящий upstream.

## Порядок

```bash
./bootstrap.sh
./prepare-inventory.sh <NODE1_PUBLIC_IP> <NODE2_PUBLIC_IP> <NODE3_PUBLIC_IP> ~/Downloads/bmlab_key.pem
./preflight.sh
./deploy.sh
./verify.sh
```

`prepare-inventory.sh` сначала подключается по floating/public IP, снимает
`ansible_default_ipv4.address` и записывает private IP в `ip/access_ip`.
Public IP node1 добавляется в SAN API-сервера до установки кластера — поэтому
не нужны `--insecure-skip-tls-verify` и ручное удаление CA из kubeconfig.

`lb1/lb2` намеренно не входят в Kubespray inventory. Они остаются чистыми до
Ч4, где отдельный Ansible kit ставит HAProxy и keepalived.
