GUILE ?= guile
GUILD ?= guild
BUILD_DIR ?= build
SCM_FILES := $(shell find canary -name '*.scm')
GO_FILES := $(patsubst canary/%.scm,$(BUILD_DIR)/canary/%.go,$(SCM_FILES))
TEST_FILES := $(wildcard tests/test-*.scm)

.PHONY: all compile test lint clean repl

all: compile

compile: $(GO_FILES)

$(BUILD_DIR)/canary/%.go: canary/%.scm
	@mkdir -p $(dir $@)
	$(GUILD) compile -L . -o $@ $<

test:
	@for f in $(TEST_FILES); do \
		echo "==> $$f"; \
		$(GUILE) -L . "$$f" || exit 1; \
	done

lint:
	@! grep -rn '\\x1b' canary --include='*.scm' \
		| grep -v 'backend-ansi.scm\|terminal.scm' \
		|| (echo "ANSI escape codes found outside backend-ansi/terminal" && exit 1)

clean:
	rm -rf $(BUILD_DIR)

repl:
	$(GUILE) -L . --listen=37147
