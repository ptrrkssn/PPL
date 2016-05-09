# Makefile

DEST1=/opt/liupf/share/perl5/PPL
DEST2=/home/peter/Projects/pm-liuit-packetfence/files/common/ppl

all:
	@echo Nothing to do.

install: install-opt install-liupf

install-opt:
	mkdir -p $(DEST1) && cp *.pm $(DEST1)

install-liupf:
	mkdir -p $(DEST2) && cp *.pm $(DEST2)

check:
	@echo No checks.

clean:
	rm -f *~ \#* core

add:	
	@git add -A && echo ""

commit:
	@git commit -a -m "Updated" && echo ""

upload push: clean check add commit
	@git push
