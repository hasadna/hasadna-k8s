import os
import subprocess

import pexpect
from pexpect import replwrap


def kubectl_get_deployment_pod(namespace, labels):
    return subprocess.check_output(["kubectl", "-n", namespace, "get", "pod", "-l", labels, "-o", "jsonpath={.items[0].metadata.name}"], text=True).strip()


def kubectl_exec_bash(namespace, pod, container):
    bashrc = os.path.join(os.path.dirname(replwrap.__file__), 'bashrc.sh')
    subprocess.check_call([
        "kubectl", "-n", namespace, "cp", "-c", container, bashrc, f"{pod}:/tmp/bashrc.sh"
    ])
    return replwrap._repl_sh("kubectl", [
        "-n", namespace, "exec", "-c", container, "-it", pod, "--", "bash", '--rcfile', "/tmp/bashrc.sh"
    ], non_printable_insert='\\[\\]')


def main_odata(allow_delete=True):
    print("Starting odata ckan resources cleanup...")
    ckan_bash = kubectl_exec_bash("odata", kubectl_get_deployment_pod("odata", "app=ckan"), "ckan")
    num_deleted_files = 0
    num_resources = 0
    for resource_id in subprocess.check_output([
        "kubectl", "-n", "odata", "exec", "deploy/db", "--", "su", "-", "postgres", "-c",
        "psql -dckan -nqtc \"select id from resource where state = 'deleted' and last_modified < now() - interval '10 day';\""
    ], text=True).splitlines():
        num_resources += 1
        if num_resources % 100 == 0:
            print(f"Checked {num_resources} deleted resources, deleted {num_deleted_files} files")
        resource_id = resource_id.strip()
        if resource_id:
            resource_path = os.path.join(
                "/var", "lib", "ckan", "data", "resources",
                resource_id[:3],
                resource_id[3:6],
                resource_id[6:]
            )
            if allow_delete:
                out = ckan_bash.run_command(f'rm "{resource_path}"\n').strip()
                out = out.split("\n")[1:]
                if len(out) == 0:
                    num_deleted_files += 1
                else:
                    assert "No such file or directory" in "\n".join(out)
            else:
                print(ckan_bash.run_command(f"ls -lah \"{resource_path}\" || true\n").strip().encode())
    print(f"Checked {num_resources} deleted resources, deleted {num_deleted_files} files")
    ckan_bash.child.sendline("exit")
    ckan_bash.child.expect(pexpect.EOF)
    print("Great Success!")
