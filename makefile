VOC ?= voc
BUILD ?= build/voc
ROOT := $(CURDIR)
MODULES := XMLUnicode XMLUnicodeCodec XMLUnicodeCodecUTF8 XMLUnicodeCodecUTF16 \
	XMLUnicodeCodecASCII XMLUnicodeCodecLatin1 XMLUnicodeCodecImportAll \
	LongStrings Msg Channel IOMemory XMLInputBuffer XMLUnicodeBuffer \
	TestUnicodeCodecs TestLongStrings TestMessages TestMemoryBuffers

.PHONY: all unicode codecs support buffers test clean
all: buffers

unicode:
	mkdir -p "$(BUILD)"
	cd "$(BUILD)" && $(VOC) -O2 -s "$(ROOT)/src/XML/Unicode.Mod"

# Build the Unicode support layer used by the XML port.
codecs: unicode
	cd "$(BUILD)" && $(VOC) -O2 -s \
		"$(ROOT)/src/XML/UnicodeCodec.Mod" \
		"$(ROOT)/src/XML/UnicodeCodec/ASCII.Mod" \
		"$(ROOT)/src/XML/UnicodeCodec/Latin1.Mod" \
		"$(ROOT)/src/XML/UnicodeCodec/UTF8.Mod" \
		"$(ROOT)/src/XML/UnicodeCodec/UTF16.Mod" \
		"$(ROOT)/src/XML/UnicodeCodec/ImportAll.Mod"

support: unicode
	cd "$(BUILD)" && $(VOC) -O2 -s \
		"$(ROOT)/src/oo2c/LongStrings.Mod" \
		"$(ROOT)/src/oo2c/Msg.Mod"

buffers: codecs support
	cd "$(BUILD)" && $(VOC) -O2 -s \
		"$(ROOT)/src/oo2c/Channel.Mod" \
		"$(ROOT)/src/IO/Memory.Mod" \
		"$(ROOT)/src/XML/InputBuffer.Mod" \
		"$(ROOT)/src/XML/UnicodeBuffer.Mod"

test: buffers
	cd "$(BUILD)" && $(VOC) -O2 -s -m "$(ROOT)/tests/voc/TestUnicodeCodecs.Mod"
	"$(BUILD)/TestUnicodeCodecs"
	cd "$(BUILD)" && $(VOC) -O2 -s -m "$(ROOT)/tests/voc/TestLongStrings.Mod"
	"$(BUILD)/TestLongStrings"
	cd "$(BUILD)" && $(VOC) -O2 -s -m "$(ROOT)/tests/voc/TestMessages.Mod"
	"$(BUILD)/TestMessages"
	cd "$(BUILD)" && $(VOC) -O2 -s -m "$(ROOT)/tests/voc/TestMemoryBuffers.Mod"
	"$(BUILD)/TestMemoryBuffers"

clean:
	rm -f $(foreach module,$(MODULES),$(foreach ext,c h o sym,"$(BUILD)/$(module).$(ext)")) \
		"$(BUILD)/TestUnicodeCodecs" "$(BUILD)/TestLongStrings" "$(BUILD)/TestMessages" \
		"$(BUILD)/TestMemoryBuffers"
