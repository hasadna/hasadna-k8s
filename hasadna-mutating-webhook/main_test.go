package main

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"testing"
	"time"

	tfe "github.com/hashicorp/go-tfe"
	vaultapi "github.com/hashicorp/vault/api"
	"sigs.k8s.io/yaml"
)

func newTestIAC(data map[string]string) *IACSource {
	return &IACSource{data: data}
}

func newTestVault(data map[string]map[string]string) *VaultClient {
	return &VaultClient{cache: data}
}

type fakeWorkspaces struct{ id string }

func (f *fakeWorkspaces) Read(ctx context.Context, organization, workspace string) (*tfe.Workspace, error) {
	return &tfe.Workspace{ID: f.id, Name: workspace}, nil
}

type fileStateVersions struct{ path string }

func (f *fileStateVersions) ReadCurrent(ctx context.Context, workspaceID string) (*tfe.StateVersion, error) {
	data, err := os.ReadFile(f.path)
	if err != nil {
		return nil, err
	}
	var state struct {
		Outputs map[string]struct {
			Sensitive bool        `json:"sensitive"`
			Type      string      `json:"type"`
			Value     interface{} `json:"value"`
		} `json:"outputs"`
	}
	if err := json.Unmarshal(data, &state); err != nil {
		return nil, err
	}
	items := []*tfe.StateVersionOutput{}
	for k, v := range state.Outputs {
		items = append(items, &tfe.StateVersionOutput{Name: k, Sensitive: v.Sensitive, Type: v.Type, Value: v.Value})
	}
	return &tfe.StateVersion{ID: "local", Outputs: items}, nil
}

func TestReplacePlaceholdersIAC(t *testing.T) {
	iac := newTestIAC(map[string]string{"foo": "bar"})
	out, changed := replacePlaceholders("pre ~iac:foo~ post", iac, nil)
	if !changed {
		t.Fatalf("expected changed")
	}
	if out != "pre bar post" {
		t.Fatalf("got %q", out)
	}
}

func TestReplacePlaceholdersVault(t *testing.T) {
	v := newTestVault(map[string]map[string]string{"p": {"k": "val"}})
	out, changed := replacePlaceholders("pre ~vault:p:k~ post", nil, v)
	want := "pre " + base64.StdEncoding.EncodeToString([]byte("val")) + " post"
	if !changed {
		t.Fatalf("expected changed")
	}
	if out != want {
		t.Fatalf("got %q want %q", out, want)
	}
}

func TestReplacePlaceholdersInvalidVault(t *testing.T) {
	v := newTestVault(map[string]map[string]string{"p": {"k": "val"}})
	out, changed := replacePlaceholders("pre ~vault:invalid~ post", nil, v)
	if !changed {
		t.Fatalf("expected change")
	}
	if out != "pre  post" {
		t.Fatalf("got %q", out)
	}
}

func TestMutateObjectPlaceholders(t *testing.T) {
	iac := newTestIAC(map[string]string{"foo": "bar"})
	v := newTestVault(map[string]map[string]string{"p": {"k": "val"}})
	obj := map[string]interface{}{
		"a": "~iac:foo~",
		"b": []interface{}{"~vault:p:k~", map[string]interface{}{"c": "~iac:foo~"}},
		"d": "none",
	}
	changed := mutateObjectPlaceholders(obj, iac, v)
	if !changed {
		t.Fatal("expected change")
	}
	if obj["a"] != "bar" {
		t.Fatalf("a=%v", obj["a"])
	}
	wantVault := base64.StdEncoding.EncodeToString([]byte("val"))
	arr := obj["b"].([]interface{})
	if arr[0] != wantVault {
		t.Fatalf("arr[0]=%v", arr[0])
	}
	if arr[1].(map[string]interface{})["c"] != "bar" {
		t.Fatalf("nested=%v", arr[1].(map[string]interface{})["c"])
	}
	if obj["d"] != "none" {
		t.Fatalf("d changed: %v", obj["d"])
	}
}

func TestMutateObjectPlaceholdersNoChange(t *testing.T) {
	obj := map[string]interface{}{"a": "x", "b": []interface{}{"y"}}
	changed := mutateObjectPlaceholders(obj, newTestIAC(nil), nil)
	if changed {
		t.Fatalf("expected no change")
	}
}

func TestE2E(t *testing.T) {
	testCases := []struct {
		name               string
		terraformOutputs   map[string]string
		vaultSecrets       map[string]map[string]string
		inputYaml          string
		expectedOutputYaml string
	}{
		{
			"simple",
			map[string]string{"nfs_server_ip": "1.2.3.4"},
			map[string]map[string]string{
				"database": {
					"password": "123456",
				},
			},
			`
                apiVersion: v1
                kind: ConfigMap
                metadata:
                    name: example-config
                data:
                    nfs: '~iac:nfs_server_ip~'
                    db_pass: '~vault:database:password~'
            `,
			`
                apiVersion: v1
                kind: ConfigMap
                metadata:
                    name: example-config
                data:
                    nfs: '1.2.3.4'
                    db_pass: 'MTIzNDU2'
            `,
		},
	}
	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			dir := t.TempDir()
			tf := "terraform {}\n"
			for k, v := range tc.terraformOutputs {
				tf += fmt.Sprintf("output \"%s\" { value = \"%s\" }\n", k, v)
			}
			if err := os.WriteFile(filepath.Join(dir, "main.tf"), []byte(tf), 0600); err != nil {
				t.Fatal(err)
			}
			cmd := exec.Command("terraform", "init", "-input=false")
			cmd.Dir = dir
			if out, err := cmd.CombinedOutput(); err != nil {
				t.Fatalf("terraform init: %v\n%s", err, out)
			}
			cmd = exec.Command("terraform", "apply", "-auto-approve", "-input=false")
			cmd.Dir = dir
			if out, err := cmd.CombinedOutput(); err != nil {
				t.Fatalf("terraform apply: %v\n%s", err, out)
			}
			fws := &fakeWorkspaces{id: "ws-1"}
			sv := &fileStateVersions{path: filepath.Join(dir, "terraform.tfstate")}
			iac := &IACSource{organization: "o", workspace: "w", workspaces: fws, stateVersions: sv, data: map[string]string{}}
			if err := iac.refresh(context.Background()); err != nil {
				t.Fatal(err)
			}

			vaultCmd := exec.Command("vault", "server", "-dev", "-dev-root-token-id=root", "-dev-listen-address=127.0.0.1:8200")
			vaultCmd.Stdout = os.Stdout
			vaultCmd.Stderr = os.Stderr
			if err := vaultCmd.Start(); err != nil {
				t.Fatal(err)
			}
			defer vaultCmd.Process.Kill()
			time.Sleep(1 * time.Second)
			enableCmd := exec.Command("vault", "secrets", "enable", "-path=kv", "-version=2", "kv")
			enableCmd.Env = append(os.Environ(), "VAULT_ADDR=http://127.0.0.1:8200", "VAULT_TOKEN=root")
			if out, err := enableCmd.CombinedOutput(); err != nil {
				t.Fatalf("enable kv: %v\n%s", err, out)
			}

			cfg := vaultapi.DefaultConfig()
			cfg.Address = "http://127.0.0.1:8200"
			vclient, err := vaultapi.NewClient(cfg)
			if err != nil {
				t.Fatal(err)
			}
			vclient.SetToken("root")
			for path, data := range tc.vaultSecrets {
				m := map[string]interface{}{"data": map[string]interface{}{}}
				for k, v := range data {
					m["data"].(map[string]interface{})[k] = v
				}
				if _, err := vclient.Logical().Write("kv/data/"+path, m); err != nil {
					t.Fatal(err)
				}
			}
			os.Setenv("VAULT_ADDR", "http://127.0.0.1:8200")
			os.Setenv("VAULT_TOKEN", "root")
			vaultWrapper, err := NewVaultClientFromEnv()
			if err != nil {
				t.Fatal(err)
			}

			obj := map[string]interface{}{}
			if err := yaml.Unmarshal([]byte(tc.inputYaml), &obj); err != nil {
				t.Fatal(err)
			}
			mutateObjectPlaceholders(obj, iac, vaultWrapper)
			gotBytes, err := yaml.Marshal(obj)
			if err != nil {
				t.Fatal(err)
			}
			expObj := map[string]interface{}{}
			if err := yaml.Unmarshal([]byte(tc.expectedOutputYaml), &expObj); err != nil {
				t.Fatal(err)
			}
			expBytes, _ := yaml.Marshal(expObj)
			if string(gotBytes) != string(expBytes) {
				t.Fatalf("\nexpected:\n%s\n\ngot:\n%s", expBytes, gotBytes)
			}
		})
	}
}
