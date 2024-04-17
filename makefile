GOFMT_FILES?=$$(find . -name '*.go' |grep -v vendor)
GOOS?=darwin
GOARCH?=arm64

MAKEFLAGS += --silent

# Official version is 4.4.0 - ffuf version 4.4.1
VERSION=4.4.1

NAME=keycloak
BINARY=terraform-provider-${NAME}_${VERSION}

build:
	CGO_ENABLED=0 go build -trimpath -ldflags "-s -w -X main.version=$(VERSION)" -o terraform-provider-keycloak_$(VERSION)

build-example: build
	mkdir -p example/.terraform/plugins/terraform.local/mrparkers/keycloak/4.0.0/$(GOOS)_$(GOARCH)
	mkdir -p example/terraform.d/plugins/terraform.local/mrparkers/keycloak/4.0.0/$(GOOS)_$(GOARCH)
	cp terraform-provider-keycloak_* example/.terraform/plugins/terraform.local/mrparkers/keycloak/4.0.0/$(GOOS)_$(GOARCH)/
	cp terraform-provider-keycloak_* example/terraform.d/plugins/terraform.local/mrparkers/keycloak/4.0.0/$(GOOS)_$(GOARCH)/

local: deps
	docker compose up --build -d
	./scripts/wait-for-local-keycloak.sh
	./scripts/create-terraform-client.sh

deps:
	./scripts/check-deps.sh

fmt:
	gofmt -w -s $(GOFMT_FILES)

test: fmtcheck vet
	go test $(TEST)

testacc: fmtcheck vet
	go test -v github.com/mrparkers/terraform-provider-keycloak/keycloak
	TF_ACC=1 CHECKPOINT_DISABLE=1 go test -v -timeout 60m -parallel 4 github.com/mrparkers/terraform-provider-keycloak/provider $(TESTARGS)

fmtcheck:
	lineCount=$(shell gofmt -l -s $(GOFMT_FILES) | wc -l | tr -d ' ') && exit $$lineCount

vet:
	go vet ./...

user-federation-example:
	cd custom-user-federation-example && ./gradlew shadowJar

release:
	mkdir -p ${NAME}/${VERSION}/linux_amd64
	mkdir -p ${NAME}/${VERSION}/windows_amd64
	mkdir -p ${NAME}/${VERSION}/darwin_amd64
	GOOS=linux GOARCH=amd64 go build -o ${BINARY}
	mv ${BINARY} ${NAME}/${VERSION}/linux_amd64
	GOOS=windows GOARCH=amd64 go build -o ${BINARY}
	mv ${BINARY} ${NAME}/${VERSION}/windows_amd64
	GOOS=darwin GOARCH=amd64 go build -o ${BINARY}
	mv ${BINARY} ${NAME}/${VERSION}/darwin_amd64
