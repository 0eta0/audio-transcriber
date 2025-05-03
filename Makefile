BREW					= brew
SWIFTGEN			= swiftgen

.PHONY: install
install:
	$(BREW) update
	$(BREW) install swiftgen

.PHONY: generates
generates:
	$(SWIFTGEN) config run --config AudioTranscriber/Resources/swiftgen.yml