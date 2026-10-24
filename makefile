VOC ?= voc
BUILD ?= build/voc
ROOT := $(CURDIR)
MODULES := XMLUnicodeCodec XMLUnicodeCodecUTF8 XMLUnicodeCodecUTF16 \
	XMLUnicodeCodecASCII XMLUnicodeCodecLatin1 XMLUnicodeCodecImportAll \
	XMLInputBuffer XMLUnicodeBuffer XMLDTD XMLEntityResolver \
	XMLError XMLLocator XMLBuilder XMLParser XMLCheck \
	TestUnicodeCodecs TestUnicodeMessages TestMemoryBuffers TestDTDResolver TestParser

.PHONY: all codecs buffers resolver parser xmlcheck conformance test clean
all: parser

$(BUILD):
	mkdir -p "$(BUILD)"

# Shared ooc modules are supplied by VOC.
codecs: | $(BUILD)
	cd "$(BUILD)" && $(VOC) -O2 -s \
		"$(ROOT)/src/XML/UnicodeCodec.Mod" \
		"$(ROOT)/src/XML/UnicodeCodec/ASCII.Mod" \
		"$(ROOT)/src/XML/UnicodeCodec/Latin1.Mod" \
		"$(ROOT)/src/XML/UnicodeCodec/UTF8.Mod" \
		"$(ROOT)/src/XML/UnicodeCodec/UTF16.Mod" \
		"$(ROOT)/src/XML/UnicodeCodec/ImportAll.Mod"

buffers: codecs
	cd "$(BUILD)" && $(VOC) -O2 -s \
		"$(ROOT)/src/XML/InputBuffer.Mod" \
		"$(ROOT)/src/XML/UnicodeBuffer.Mod"

resolver: buffers
	cd "$(BUILD)" && $(VOC) -O2 -s \
		"$(ROOT)/src/XML/DTD.Mod" \
		"$(ROOT)/src/XML/EntityResolver.Mod"

parser: resolver
	cd "$(BUILD)" && $(VOC) -O2 -s \
		"$(ROOT)/src/XML/Error.Mod" \
		"$(ROOT)/src/XML/Locator.Mod" \
		"$(ROOT)/src/XML/Builder.Mod" \
		"$(ROOT)/src/XML/Parser.Mod"

test: parser
	cd "$(BUILD)" && $(VOC) -O2 -s -m "$(ROOT)/tests/voc/TestUnicodeCodecs.Mod"
	"$(BUILD)/TestUnicodeCodecs"
	cd "$(BUILD)" && $(VOC) -O2 -s -m "$(ROOT)/tests/voc/TestUnicodeMessages.Mod"
	"$(BUILD)/TestUnicodeMessages"
	cd "$(BUILD)" && $(VOC) -O2 -s -m "$(ROOT)/tests/voc/TestMemoryBuffers.Mod"
	"$(BUILD)/TestMemoryBuffers"
	cd "$(BUILD)" && $(VOC) -O2 -s -m "$(ROOT)/tests/voc/TestDTDResolver.Mod"
	"$(BUILD)/TestDTDResolver"
	cd "$(BUILD)" && $(VOC) -O2 -s -m "$(ROOT)/tests/voc/TestParser.Mod"
	"$(BUILD)/TestParser"

xmlcheck: parser
	cd "$(BUILD)" && $(VOC) -O2 -s -m "$(ROOT)/tools/XMLCheck.Mod"

conformance: xmlcheck
	python3 tests/voc/check-xmltest.py "$(BUILD)/XMLCheck"

clean:
	rm -f $(foreach module,$(MODULES),$(foreach ext,c h o sym,"$(BUILD)/$(module).$(ext)")) \
		"$(BUILD)/TestUnicodeCodecs" "$(BUILD)/TestUnicodeMessages" \
		"$(BUILD)/TestMemoryBuffers" "$(BUILD)/TestDTDResolver" "$(BUILD)/TestParser" \
		"$(BUILD)/XMLCheck"
