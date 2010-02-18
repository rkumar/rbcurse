DISTFILES := README.markdown TODO2.txt NOTES lib/ examples/
VERSION := `cat VERSION_FILE`
 
#all: install

DISTNAME=rbcurse-$(VERSION)
dist: $(DISTFILES)
	echo "ver: $(VERSION)"
	mkdir -p $(DISTNAME)
	cp -fr $(DISTFILES)  $(DISTNAME)/
	rm -rf $(DISTNAME)/examples/expected_output
	tar cf $(DISTNAME).tar $(DISTNAME)/
	gzip -f -9 $(DISTNAME).tar
	zip -9r $(DISTNAME).zip $(DISTNAME)/
	rm -r $(DISTNAME)

.PHONY: distclean
distclean:
	rm -f $(DISTNAME).tar.gz $(DISTNAME).zip

#install:
