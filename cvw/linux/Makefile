BUILDROOT := buildroot
IMAGES := ${BUILDROOT}/output/images
WALLYLINUX := $(WALLY)/linux
DIS := ${IMAGES}/disassembly
BR2_EXTERNAL_TREE := $(WALLYLINUX)/br2-external-tree

# set sudo if needed depending on $RISCV
SUDO := $(shell mkdir -p $(RISCV)/.test > /dev/null 2>&1 || echo sudo)

# Device tree files
DTS ?= $(shell find devicetree -type f -regex ".*\.dts" | sort)
DTB := $(DTS:%.dts=%.dtb)
DTB := $(foreach name, $(DTB), $(IMAGES)/$(shell basename $(name)))

# Disassembly stuff
BINARIES := fw_jump.elf vmlinux busybox
OBJDUMPS := $(foreach name, $(BINARIES), $(basename $(name) .elf))
OBJDUMPS := $(foreach name, $(OBJDUMPS), $(DIS)/$(name).objdump)

.PHONY: all generate disassemble install clean cleanDTB check_write_permissions check_environment

all: check_environment check_write_permissions clean download Image disassemble install dumptvs

check_environment: $(RISCV)
ifeq ($(findstring :$(RISCV)/lib:,:$(LD_LIBRARY_PATH):),)
	@(echo "ERROR: Your environment variables are not set correctly." >&2 \
	&& echo "Make sure to source setup.sh or install buildroot using the wally-tool-chain-install.sh script." >&2 \
	&& exit 1)
endif

check_write_permissions:
ifeq ($(SUDO), sudo)
	@echo "Cannot write to '$(RISCV)'." \
		"Using sudo (you may be prompted for your password several times throughout the install)"
endif
	@$(SUDO) mkdir -p $(RISCV)/.test || \
		(echo "ERROR: Still unable to write to '$(RISCV)'." >&2 \
		&& exit 1)
	@$(SUDO) rm -r $(RISCV)/.test

Image: check_environment
	bash -c "unset LD_LIBRARY_PATH; $(MAKE) -C $(BUILDROOT)"
	$(MAKE) generate
	@echo "Buildroot Image successfully generated."

install: check_write_permissions check_environment
	$(SUDO) rm -rf $(RISCV)/$(BUILDROOT)
	$(SUDO) mv $(BUILDROOT) $(RISCV)/$(BUILDROOT)
	@echo "Buildroot successfully installed."

dumptvs: check_write_permissions check_environment
	$(SUDO) mkdir -p $(RISCV)/linux-testvectors
	./genInitMem.sh
	@echo "Testvectors successfully generated."

generate: $(DTB) $(IMAGES)

$(IMAGES)/%.dtb: ./devicetree/%.dts
	dtc -I dts -O dtb $< > $@

$(IMAGES):
	@ echo "No output/images directory in buildroot."
	@ echo "Run make --jobs in buildroot directory before generating device tree binaries."; exit 1

$(RISCV):
	@ echo "ERROR: No $(RISCV) directory. Make sure you have installed the Wally Toolchain."
	@ echo "and sourced setup.sh"

# Disassembly rules ---------------------------------------------------
disassemble: check_environment
	rm -rf $(BUILDROOT)/output/images/disassembly
	find  $(BUILDROOT)/output/build/linux-* -maxdepth 1 -name "vmlinux" | xargs  cp -t $(BUILDROOT)/output/images/
	mkdir -p $(DIS)
	$(MAKE) $(OBJDUMPS)
	# extract rootfs
	mkdir -p $(BUILDROOT)/output/images/disassembly/rootfs
	@echo "Ignore error about dev/console when extracting rootfs from rootfs.cpio"
	-cpio -i -D $(BUILDROOT)/output/images/disassembly/rootfs < $(BUILDROOT)/output/images/rootfs.cpio
	@echo "Disassembly successfully completed."

$(DIS)/%.objdump: $(IMAGES)/%.elf
	riscv64-unknown-elf-objdump -DS $< >> $@
	$(WALLY)/bin/extractFunctionRadix.sh $@

$(DIS)/%.objdump: $(IMAGES)/%
	riscv64-unknown-elf-objdump -S $< >> $@
	$(WALLY)/bin/extractFunctionRadix.sh $@

$(IMAGES)/vmlinux:
	linuxDir=$$(find $(BUILDROOT)/output/build -maxdepth 2 -type d -regex ".*/linux-[0-9]+\.[0-9]+\.[0-9]+$$") ;\
	cp $$linuxDir/vmlinux $@ ;\

$(IMAGES)/busybox:
	busyboxDir=$$(find $(BUILDROOT)/output/build -maxdepth 2 -type d -regex ".*/busybox-[0-9]+\.[0-9]+\.[0-9]+$$") ;\
	cp $$busyboxDir/busybox $@ ;\

# Generating new Buildroot directories --------------------------------
download: $(BUILDROOT)
	$(MAKE) -C $(BUILDROOT) wally_defconfig BR2_EXTERNAL=$(BR2_EXTERNAL_TREE)
	@echo "Buildroot successfully download."

$(BUILDROOT):
	git clone https://github.com/buildroot/buildroot.git $@
	cd $@; git checkout 2024.11.x

# ---------------------------------------------------------------------

cleanDTB:
	rm -f $(IMAGES)/*.dtb

clean:
	rm -rf $(BUILDROOT)
