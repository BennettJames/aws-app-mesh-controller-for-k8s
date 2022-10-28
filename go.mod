module github.com/aws/aws-app-mesh-controller-for-k8s

go 1.16

require (
	github.com/aws/aws-sdk-go v1.44.79
	github.com/bmizerany/assert v0.0.0-20160611221934-b7ed37b82869 // indirect
	github.com/docker/docker v20.10.17+incompatible // indirect
	github.com/evanphx/json-patch v4.12.0+incompatible
	github.com/garyburd/redigo v1.6.3 // indirect
	github.com/go-logr/logr v1.2.2
	github.com/golang/mock v1.6.0
	github.com/google/go-cmp v0.5.6
	github.com/marstr/guid v1.1.0 // indirect
	github.com/onsi/ginkgo v1.16.4
	github.com/onsi/gomega v1.19.0
	github.com/pkg/errors v0.9.1
	github.com/prometheus/client_golang v1.12.1
	github.com/satori/go.uuid v1.2.0 // indirect
	github.com/spf13/pflag v1.0.5
	github.com/stretchr/testify v1.7.2
	go.uber.org/zap v1.19.0
	golang.org/x/time v0.0.0-20220210224613-90d013bbcef8
	gomodules.xyz/jsonpatch/v2 v2.2.0
	gonum.org/v1/gonum v0.7.0
	gopkg.in/gorp.v1 v1.7.2 // indirect
	gopkg.in/yaml.v3 v3.0.1 // indirect
	gotest.tools v2.2.0+incompatible
	helm.sh/helm/v3 v3.9.4
	k8s.io/api v0.24.2
	k8s.io/apimachinery v0.24.2
	k8s.io/cli-runtime v0.24.2
	k8s.io/client-go v0.24.2
	rsc.io/letsencrypt v0.0.3 // indirect
	sigs.k8s.io/controller-runtime v0.9.2
)

replace golang.org/x/sys => golang.org/x/sys v0.0.0-20210603081109-ebe580a85c40

replace k8s.io/client-go => k8s.io/client-go v0.21.2

replace k8s.io/api => k8s.io/api v0.21.2

replace k8s.io/apimachinery => k8s.io/apimachinery v0.21.2

replace k8s.io/cli-runtime => k8s.io/cli-runtime v0.21.2

replace github.com/containerd/containerd => github.com/containerd/containerd v1.5.13

replace github.com/opencontainers/runc => github.com/opencontainers/runc v1.1.2

replace github.com/docker/distribution => github.com/docker/distribution v2.8.1+incompatible
