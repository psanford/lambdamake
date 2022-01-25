BIN=my-lambda-binary
FUNCTION_NAME=$(BIN)
VERSION=v1.0.0
# LAMBDA_BINARY_BUCKET=
# LAMBDA_CONF_BUCKET=

GOBUILD_TAGS=-tags netgo,sqlite_omit_load_extension,fts5
# -s Omit the symbol table and debug information.
# -w Omit the DWARF symbol table.
GOBUILD_LDFLAGS=-ldflags="-s -w -extldflags=-static -X main.buildSha=$(shell git rev-list -1 HEAD) -X main.buildEpoch=$(shell date +%s)"

STATIC_RESOURCES=

$(BIN): $(wildcard *.go) $(wildcard **/*.go)
	go test .
	go build $(GOBUILD_LDFLAGS) $(GOBUILD_TAGS) -o $(BIN)

$(BIN).zip: $(BIN) $(STATIC_RESOURCES)
	rm -f $@
	zip -r $@ $^

.PHONY: upload
upload: $(BIN).zip
	aws lambda update-function-code --function-name $(FUNCTION_NAME) --zip-file fileb://$(BIN).zip
	rm $(BIN).zip

.PHONY: upload_s3
upload_s3: $(BIN).zip
	aws s3 cp $(BIN).zip "s3://$(LAMBDA_BINARY_BUCKET)/$(BIN)/$(VERSION)/$(BIN).zip"
	rm $(BIN).zip

.PHONY: upload_config
upload_config: $(BIN).toml
	aws s3 cp $^ "s3://$(LAMBDA_CONF_BUCKET)/$(FUNCTION_NAME)/$(FUNCTION_NAME).toml"

.PHONY: tail_logs
tail_logs:
	cw tail /aws/lambda/$(FUNCTION_NAME) -b 5m
