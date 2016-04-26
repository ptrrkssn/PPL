# Makefile

all:
	@echo Nothing to do.

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
