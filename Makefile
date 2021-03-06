.SUFFIXES:

MAKEFLAGS += -sj

ROM = bin/vuiiger.gb
MOD2GBT = tools/bin/mod2gbt
MAKEFONT = tools/bin/makefont
PALCONV = tools/bin/palconv

# 0x1B is MBC5 with RAM + Battery
MBC := 0x1B
# 0x02 is one bank of SRAM
SRAMSIZE := 0x02
VERSION := 0

INCDIRS  = src/ src/include/
WARNINGS = all extra

ASFLAGS  = -p 0xFF -h $(addprefix -i, $(INCDIRS)) $(addprefix -W, $(WARNINGS))
LDFLAGS  = -p 0xFF -w -S romx=64
FIXFLAGS = -p 0xFF -j -v -c -k "EV" -l 0x33 -m $(MBC) \
           -n $(VERSION) -r $(SRAMSIZE) -t "Vuiiger"
GFXFLAGS = -c embedded

SRCS := $(shell find src -name '*.asm')
EVSS := $(shell find src -name '*.evs')
OBJS := $(patsubst src/%.asm, obj/%.o, $(SRCS)) \
        $(patsubst src/%.evs, obj/%.o, $(EVSS))
.SECONDARY: $(OBJS)

################################################
#                                              #
#                    TARGETS                   #
#                                              #
################################################

# `all` (Default target): build the ROM
all: $(ROM)
.PHONY: all

# `clean`: Clean temp and bin files
clean:
	rm -rf bin obj dep res
	rm -f src/include/charmap.inc

.PHONY: clean

# `rebuild`: Build everything from scratch
# It's important to do these two in order if we're using more than one job
rebuild:
	$(MAKE) clean
	$(MAKE) all
.PHONY: rebuild

release:
	$(MAKE) clean
	${MAKE} LDFLAGS="-p 0xFF -w"
.PHONY: release

###############################################
#                                             #
#                 COMPILATION                 #
#                                             #
###############################################

# How to build a ROM
bin/%.gb bin/%.sym bin/%.map: $(OBJS)
	@mkdir -p $(@D)
	printf "SECTION \"Version\", ROM0\nVersion:: db \"Vuiiger v%s\\\\nBuilt on {d:__UTC_YEAR__}-{d:__UTC_MONTH__}-{d:__UTC_DAY__}\\\\nUsing RGBDS {__RGBDS_VERSION__}\", 0\n" `git describe --tags --always --dirty` \
	| rgbasm $(ASFLAGS) -o obj/version.o -
	rgblink $(LDFLAGS) -m bin/$*.map -n bin/$*.sym -o bin/$*.gb $^ obj/version.o  \
	&& rgbfix $(FIXFLAGS) bin/$*.gb

obj/libs/vwf.o dep/libs/vwf.mk res/charmap.inc: src/libs/vwf.asm
	@mkdir -p obj/libs/ dep/libs/ res/
	rgbasm $(ASFLAGS) -M dep/libs/vwf.mk -MG -MP -MQ obj/libs/vwf.o -MQ dep/libs/vwf.mk -o obj/libs/vwf.o $< > res/charmap.inc

# `.mk` files are auto-generated dependency lists of the "root" ASM files, to save a lot of hassle.
# Also add all obj dependencies to the dep file too, so Make knows to remake it
# Caution: some of these flags were added in RGBDS 0.4.0, using an earlier version WILL NOT WORK
# (and produce weird errors)
obj/%.o dep/%.mk: src/%.asm
	@mkdir -p $(patsubst %/, %, $(dir obj/$* dep/$*))
	rgbasm $(ASFLAGS) -M dep/$*.mk -MG -MP -MQ obj/$*.o -MQ dep/$*.mk -o obj/$*.o $<

obj/%.o obj/%.asm dep/%.mk: src/%.evs
	@mkdir -p $(patsubst %/, %, $(dir obj/$* dep/$*))
	evscript -o obj/$*.asm $<
	rgbasm $(ASFLAGS) -M dep/$*.mk -MG -MP -MQ obj/$*.o -MQ dep/$*.mk -o obj/$*.o obj/$*.asm

ifneq ($(MAKECMDGOALS),clean)
-include $(patsubst src/%.asm, dep/%.mk, $(SRCS))
endif

################################################
#                                              #
#                RESOURCE FILES                #
#                                              #
################################################


# By default, asset recipes convert files in `res/` into other files in `res/`
# This line causes assets not found in `res/` to be also looked for in `src/res/`
# "Source" assets can thus be safely stored there without `make clean` removing them
VPATH := src

# Convert .png files using custom atfile arguments
res/%.2bpp res/%.map: res/%.arg res/%.png
	@mkdir -p $(@D)
	rgbgfx @$^

# Convert .png files into .2bpp files.
res/%.2bpp: res/%.png
	@mkdir -p $(@D)
	rgbgfx $(GFXFLAGS) -o $@ $<

# Convert .png files into .pal files.
res/%.pal: res/%.png
	@mkdir -p $(@D)
	rgbgfx $(GFXFLAGS) -p $@ $<

# Convert .png files into .1bpp files.
res/%.1bpp: res/%.png
	@mkdir -p $(@D)
	rgbgfx $(GFXFLAGS) -d 1 -o $@ $<

# Convert .png files into .2bpp and .map files.
res/%.2bpp res/%.map: res/%.map.png
	@mkdir -p $(@D)
	rgbgfx $(GFXFLAGS) -u -o res/$*.2bpp -t res/$*.map $<

# Convert .png files into .h.2bpp files (-h flag).
res/%.2bpp: res/%.h.png
	@mkdir -p $(@D)
	rgbgfx -Z -o $@ $<

# Convert .png files into .h.1bpp files (-h flag).
res/%.1bpp: res/%.h.png
	@mkdir -p $(@D)
	rgbgfx -Z -d 1 -o $@ $<

res/%.vwf: res/%.png $(MAKEFONT)
	@mkdir -p $(@D)
	$(MAKEFONT) $< $@

res/%.asm: res/%.mod $(MOD2GBT)
	@mkdir -p $(@D)
	$(MOD2GBT) $< $@ $(patsubst res/music/%.asm, %, $@)

# Adjust .pal files to rgb888 instead of rgb555.
res/%.pal8: res/%.pal $(PALCONV)
	@mkdir -p $(@D)
	$(PALCONV) $@ $<

################################################
#                                              #
#                 BUILD TOOLS                  #
#                                              #
################################################

$(MAKEFONT): tools/makefont.c tools/libplum.c
	@mkdir -p $(@D)
	$(CC) -o $@ $^

$(MOD2GBT): tools/mod2gbt.c
	@mkdir -p $(@D)
	$(CC) -o $@ $<

$(PALCONV): tools/palconv.c
	@mkdir -p $(@D)
	$(CC) -o $@ $<

# Catch non-existent files
# KEEP THIS LAST!!
%:
	@false
