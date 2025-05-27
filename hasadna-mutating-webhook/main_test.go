package main

import (
	"encoding/base64"
	"testing"
)

func newTestIAC(data map[string]string) *IACSource {
	return &IACSource{data: data}
}

func newTestVault(data map[string]map[string]string) *VaultClient {
	return &VaultClient{cache: data}
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
