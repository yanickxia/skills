SLUG      := model-onboarding
SKILL_DIR := model-onboarding
VERSION   := 0.0.1

.PHONY: publish print

# 按需覆盖 VERSION；仅显式执行 publish 时发布。
publish:
	cd .. && clawhub publish $(SKILL_DIR) --slug $(SLUG) --version $(VERSION)

print:
	@echo "slug:    $(SLUG)"
	@echo "dir:     $(SKILL_DIR)"
	@echo "version: $(VERSION)"
