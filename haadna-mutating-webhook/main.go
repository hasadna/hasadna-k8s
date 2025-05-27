package main

import (
    "context"
    "encoding/base64"
    "encoding/json"
    "flag"
    "fmt"
    "net/http"
    "os"
    "strings"
    "sync"
    "time"

    vaultapi "github.com/hashicorp/vault/api"
    corev1 "k8s.io/api/core/v1"
    "k8s.io/apimachinery/pkg/runtime"
    "k8s.io/apimachinery/pkg/types"
    ctrl "sigs.k8s.io/controller-runtime"
    "sigs.k8s.io/controller-runtime/pkg/admission"
    "sigs.k8s.io/controller-runtime/pkg/client"
    "sigs.k8s.io/controller-runtime/pkg/healthz"
    "sigs.k8s.io/controller-runtime/pkg/log/zap"
)

// -----------------------------------------------------------------------------
// Globals & setup
// -----------------------------------------------------------------------------

var (
    scheme   = runtime.NewScheme()
    setupLog = ctrl.Log.WithName("setup")
)

func init() {
    _ = corev1.AddToScheme(scheme)
}

func main() {
    var metricsAddr string
    var probeAddr string
    var enableLeaderElection bool

    flag.StringVar(&metricsAddr, "metrics-bind-address", ":8080", "The address the metric endpoint binds to.")
    flag.StringVar(&probeAddr, "health-probe-bind-address", ":8081", "The address the probe endpoint binds to.")
    flag.BoolVar(&enableLeaderElection, "leader-elect", false, "Enable leader election for controller manager. Ensures there is only one active controller manager.")

    opts := zap.Options{Development: true}
    opts.BindFlags(flag.CommandLine)
    flag.Parse()

    ctrl.SetLogger(zap.New(zap.UseFlagOptions(&opts)))

    mgr, err := ctrl.NewManager(ctrl.GetConfigOrDie(), ctrl.Options{
        Scheme:                 scheme,
        MetricsBindAddress:     metricsAddr,
        HealthProbeBindAddress: probeAddr,
        LeaderElection:         enableLeaderElection,
        LeaderElectionID:       "hasadna-mutating-webhook",
        Port:                   9443, // webhook server port
    })
    if err != nil {
        setupLog.Error(err, "unable to start manager")
        os.Exit(1)
    }

    // initialise IAC source (tf-outputs ConfigMap)
    iac := NewIACSource("argocd", "tf-outputs", mgr.GetClient())
    if err := iac.Start(context.Background()); err != nil {
        setupLog.Error(err, "failed to start IAC source; continuing, but IAC substitutions will be empty")
    }

    // initialise Vault client
    vclient, err := NewVaultClientFromEnv()
    if err != nil {
        setupLog.Error(err, "vault client disabled")
    }

    dec, err := admission.NewDecoder(scheme)
    if err != nil {
        setupLog.Error(err, "unable to create decoder")
        os.Exit(1)
    }

    placeholderWebhook := &PlaceholderWebhook{
        decoder:     dec,
        iac:         iac,
        vaultClient: vclient,
    }

    // register webhook path
    mgr.GetWebhookServer().Register("/mutate-placeholders", &admission.Webhook{Handler: placeholderWebhook})

    if err := mgr.AddHealthzCheck("healthz", healthz.Ping); err != nil {
        setupLog.Error(err, "unable to set up health check")
        os.Exit(1)
    }
    if err := mgr.AddReadyzCheck("readyz", healthz.Ping); err != nil {
        setupLog.Error(err, "unable to set up ready check")
        os.Exit(1)
    }

    setupLog.Info("starting manager")
    if err := mgr.Start(ctrl.SetupSignalHandler()); err != nil {
        setupLog.Error(err, "problem running manager")
        os.Exit(1)
    }
}

// -----------------------------------------------------------------------------
// IAC source implementation
// -----------------------------------------------------------------------------

type IACSource struct {
    namespace string
    name      string

    client client.Client

    mu   sync.RWMutex
    data map[string]string
}

func NewIACSource(ns, name string, c client.Client) *IACSource {
    return &IACSource{
        namespace: ns,
        name:      name,
        client:    c,
        data:      map[string]string{},
    }
}

func (s *IACSource) Start(ctx context.Context) error {
    if err := s.refresh(ctx); err != nil {
        return err
    }
    // refresh every 2 minutes in background
    go func() {
        ticker := time.NewTicker(2 * time.Minute)
        defer ticker.Stop()
        for {
            select {
            case <-ticker.C:
                _ = s.refresh(ctx)
            case <-ctx.Done():
                return
            }
        }
    }()
    return nil
}

func (s *IACSource) refresh(ctx context.Context) error {
    cm := &corev1.ConfigMap{}
    if err := s.client.Get(ctx, types.NamespacedName{Namespace: s.namespace, Name: s.name}, cm); err != nil {
        return err
    }
    s.mu.Lock()
    defer s.mu.Unlock()
    s.data = cm.Data
    return nil
}

func (s *IACSource) Get(key string) string {
    s.mu.RLock()
    defer s.mu.RUnlock()
    return s.data[key]
}

// -----------------------------------------------------------------------------
// Vault client wrapper (minimal)
// -----------------------------------------------------------------------------

type VaultClient struct {
    client *vaultapi.Client

    mu    sync.RWMutex
    cache map[string]map[string]string // path → data map
}

func NewVaultClientFromEnv() (*VaultClient, error) {
    addr := os.Getenv("VAULT_ADDR")
    if addr == "" {
        return nil, fmt.Errorf("VAULT_ADDR not set")
    }

    cfg := vaultapi.DefaultConfig()
    cfg.Address = addr
    client, err := vaultapi.NewClient(cfg)
    if err != nil {
        return nil, err
    }

    if token := os.Getenv("VAULT_TOKEN"); token != "" {
        client.SetToken(token)
    } else if roleID, secretID := os.Getenv("VAULT_ROLE_ID"), os.Getenv("VAULT_SECRET_ID"); roleID != "" && secretID != "" {
        data := map[string]interface{}{
            "role_id":   roleID,
            "secret_id": secretID,
        }
        secret, err := client.Logical().Write("auth/approle/login", data)
        if err != nil {
            return nil, fmt.Errorf("vault approle login: %w", err)
        }
        client.SetToken(secret.Auth.ClientToken)
    } else {
        return nil, fmt.Errorf("no vault auth method provided")
    }

    return &VaultClient{client: client, cache: map[string]map[string]string{}}, nil
}

func (v *VaultClient) get(path string) (map[string]string, error) {
    v.mu.RLock()
    if data, ok := v.cache[path]; ok {
        v.mu.RUnlock()
        return data, nil
    }
    v.mu.RUnlock()

    secret, err := v.client.Logical().Read(fmt.Sprintf("v1/kv/data/%s", path))
    if err != nil {
        return nil, err
    }
    if secret == nil || secret.Data == nil {
        return map[string]string{}, nil
    }
    raw, ok := secret.Data["data"].(map[string]interface{})
    if !ok {
        return map[string]string{}, nil
    }
    result := map[string]string{}
    for k, v := range raw {
        if s, ok := v.(string); ok {
            result[k] = s
        }
    }

    v.mu.Lock()
    v.cache[path] = result
    v.mu.Unlock()
    return result, nil
}

// -----------------------------------------------------------------------------
// Webhook handler
// -----------------------------------------------------------------------------

type PlaceholderWebhook struct {
    decoder     *admission.Decoder
    iac         *IACSource
    vaultClient *VaultClient
}

var _ admission.Handler = &PlaceholderWebhook{}
var _ admission.DecoderInjector = &PlaceholderWebhook{}

func (w *PlaceholderWebhook) InjectDecoder(d *admission.Decoder) error {
    w.decoder = d
    return nil
}

func (w *PlaceholderWebhook) Handle(ctx context.Context, req admission.Request) admission.Response {
    // decode to map[string]interface{} so we can walk generically
    obj := map[string]interface{}{}
    if err := json.Unmarshal(req.Object.Raw, &obj); err != nil {
        return admission.Errored(http.StatusBadRequest, err)
    }

    mutated := mutateObjectPlaceholders(obj, w.iac, w.vaultClient)
    if !mutated {
        return admission.Allowed("no placeholders found")
    }

    newRaw, err := json.Marshal(obj)
    if err != nil {
        return admission.Errored(http.StatusInternalServerError, err)
    }

    return admission.PatchResponseFromRaw(req.Object.Raw, newRaw)
}

// -----------------------------------------------------------------------------
// Placeholder processing helpers
// -----------------------------------------------------------------------------

func mutateObjectPlaceholders(obj interface{}, iac *IACSource, v *VaultClient) bool {
    changed := false

    switch typed := obj.(type) {
    case map[string]interface{}:
        for k, v2 := range typed {
            switch vv := v2.(type) {
            case string:
                newStr, c := replacePlaceholders(vv, iac, v)
                if c {
                    typed[k] = newStr
                    changed = true
                }
            default:
                if mutateObjectPlaceholders(v2, iac, v) {
                    changed = true
                }
            }
        }
    case []interface{}:
        for idx, elem := range typed {
            switch ev := elem.(type) {
            case string:
                newStr, c := replacePlaceholders(ev, iac, v)
                if c {
                    typed[idx] = newStr
                    changed = true
                }
            default:
                if mutateObjectPlaceholders(ev, iac, v) {
                    changed = true
                }
            }
        }
    }

    return changed
}

func replacePlaceholders(s string, iac *IACSource, v *VaultClient) (string, bool) {
    original := s

    // IAC placeholders
    for {
        i := strings.Index(s, "~iac:")
        if i == -1 {
            break
        }
        tail := s[i+5:]
        j := strings.Index(tail, "~")
        if j == -1 {
            break
        }
        key := tail[:j]
        value := iac.Get(key)
        s = s[:i] + value + tail[j+1:]
    }

    // Vault placeholders
    for {
        i := strings.Index(s, "~vault:")
        if i == -1 {
            break
        }
        tail := s[i+7:]
        j := strings.Index(tail, "~")
        if j == -1 {
            break
        }
        pathKey := tail[:j]
        parts := strings.SplitN(pathKey, ":", 2)
        if len(parts) != 2 {
            s = s[:i] + tail[j+1:]
            continue
        }
        path, key := parts[0], parts[1]
        var value string
        if v != nil {
            if data, err := v.get(path); err == nil {
                value = base64.StdEncoding.EncodeToString([]byte(data[key]))
            }
        }
        s = s[:i] + value + tail[j+1:]
    }

    return s, s != original
}
