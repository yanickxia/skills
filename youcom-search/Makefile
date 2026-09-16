SLUG      := youcom-search
SKILL_DIR := youcom-search
VERSION   := 0.0.1

.PHONY: publish print

# Bump VERSION above (or override on the command line) and run `make publish`.
# Override example:  make publish VERSION=0.0.2
publish:
	cd .. && clawhub publish $(SKILL_DIR) --slug $(SLUG) --version $(VERSION)

print:
	@echo "slug:    $(SLUG)"
	@echo "dir:     $(SKILL_DIR)"
	@echo "version: $(VERSION)"