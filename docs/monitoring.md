# cluster monitoring

monitoring is based on Rancher

go to the hasadna cluster > tools > monitoring >
  * enable persistent storage for prometheus: true
  * storage class: nfs-client
  * enable persistent storage for grafana: true
  * storage class: nfs-client
  * enable

go to hasadna cluster > cluster metrics > grafana
  * on the bottom left - sign in
  * `admin` / `admin`
  * set a new password

The password is stored in Hasadna's vault `Projects/k8s/grafana-admin`
