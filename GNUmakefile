#!gmake
.PHONY: debug release ninja coverage clean clobber tests

ifeq ($(wildcard Makefile), Makefile)
all:
	@$(MAKE) --no-print-directory -f Makefile $(MAKECMDGOALS)

clean:
	@$(MAKE) --no-print-directory -f Makefile $(MAKECMDGOALS)

.DEFAULT:
	@$(MAKE) --no-print-directory -f Makefile $(MAKECMDGOALS)

else

BUILD ?= Build

normal: $(BUILD)/Makefile
	@$(MAKE) --no-print-directory -C $(BUILD) makes pngs

all: debug release
clean:
	@-$(MAKE) --no-print-directory -C Build clean cleans
	@-$(MAKE) --no-print-directory -C Debug clean cleans
	@-$(MAKE) --no-print-directory -C Release clean cleans

tests: $(BUILD)/Makefile
	@$(MAKE) --no-print-directory -C $(BUILD) tests
endif

clobber:
	rm -rf Debug Release Build Ninja Coverage

debug: Debug/Makefile
	@$(MAKE) --no-print-directory -C Debug

Debug/Makefile:
	@mkdir -p Debug
	@cd Debug; cmake .. -DCMAKE_BUILD_TYPE=Debug

release: Release/Makefile | debug
	@$(MAKE) --no-print-directory -C Release

Release/Makefile:
	@mkdir -p Release
	@cd Release; cmake .. -DCMAKE_BUILD_TYPE=Release

ninja: Ninja/Makefile
	ninja $(MAKECMDFLAGS) -C Ninja

Ninja/Makefile:
	@mkdir -p Ninja
	@cd Ninja; cmake .. -DCMAKE_BUILD_TYPE=Debug -G Ninja

coverage: Coverage/Makefile
	make $(MAKECMDFLAGS) -C Coverage tests

Coverage/Makefile:
	@mkdir -p Coverage
	@cd Coverage; cmake .. -DCMAKE_BUILD_TYPE=Debug -DENABLE_COVERAGE:STRING=ON

%/Makefile:
	@mkdir -p $*
	@cd $*; cmake ..

ifneq ($(wildcard Makefile), Makefile)

${BUILD}/projects.make: $(BUILD)/Makefile

-include ${BUILD}/projects.make

.DEFAULT: $(BUILD)/Makefile
	@$(MAKE) --no-print-directory -C $(BUILD) cmake_check_build_system
	@$(MAKE) --no-print-directory -C $(BUILD) $(MAKECMDGOALS)
endif
