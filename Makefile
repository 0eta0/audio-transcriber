BREW					= brew
SWIFTGEN			= swiftgen
LICENSE_PLIST	= license-plist

.PHONY: install
install:
	$(BREW) update
	$(BREW) install swiftgen licenseplist

.PHONY: generates
generates: swiftgen license

.PHONY: swiftgen
swiftgen:
	$(SWIFTGEN) config run --config AudioTranscriber/Resources/swiftgen.yml

.PHONY: license
license:
	$(LICENSE_PLIST) --suppress-opening-directory --markdown-path ./AudioTranscriber/Resources/licenses.md --force --add-version-numbers