# VS Code Remote SSH без ручной войны с Vim

Основной Terraform/Ansible/Kubernetes code остаётся в клоне на ноутбуке.
Remote SSH нужен, когда доказательство существует только на Linux VM:
`dmesg`, cgroup, `ip route`, systemd journal или фактически отрендеренный
HAProxy config.

Пример локального `~/.ssh/config` (ключ и IP не коммитятся):

```sshconfig
Host video2-lb1
  HostName <LB1_PUBLIC_IP>
  User root
  IdentityFile ~/.ssh/k8s_stand
  IdentitiesOnly yes
```

Затем в VS Code: `Remote-SSH: Connect to Host…` → `video2-lb1`. Можно открыть
`/etc/haproxy/haproxy.cfg`, journal и файлы рядом в нормальном редакторе.

Важная production-оговорка: `/etc/haproxy/haproxy.cfg` управляется Ansible.
Ручная аварийная правка допустима только как временный workaround: сохранить
diff/timestamp, проверить `haproxy -c`, безопасно reload, затем немедленно
перенести изменение в `roles/haproxy/templates/haproxy.cfg.j2` и прогнать
playbook. Иначе следующий Ansible run молча сотрёт ручной fix.

Remote SSH не нужен для Terraform apply или обычного `kubectl`: их нормально
выполнять локально. Не открывай через него control-plane во время Kubespray
upgrade — reconnect в середине записи не является полезной демонстрацией.
