LIBDIR = Sources/ADMM

EGFILE = example.swift
EGDIR = example
EGNAME= example
EGEXEC = $(EGDIR)/$(EGNAME)

DYLIB = libADMM.dylib
MODINFO = ADMM.swiftmodule


all: example

dir:
	mkdir -p $(EGDIR)

lib: dir
	rm -f $(EGDIR)/*.swift
	cp $(LIBDIR)/*.swift $(EGDIR)
	pushd $(EGDIR) ; swiftc -emit-library -emit-module -parse-as-library -module-name ADMM *.swift
	rm -f $(EGDIR)/*.swift

example: lib
	cp $(EGFILE) $(EGDIR)
	pushd $(EGDIR) ; swiftc -I . -L . -lADMM -o $(EGNAME) $(EGFILE)

run: $(EGEXEC)
	@export DYLD_LIBRARY_PATH=$(EGDIR):${DYLD_LIBRARY_PATH} ; $(EGEXEC)

test:
	@pushd Tests ; swift test --configuration release

clean:
	rm -Rf $(EGDIR)
	rm -Rf .build
