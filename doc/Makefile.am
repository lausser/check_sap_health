PLUGIN=check_sap_health

alles: check dedoc unix2dos
	$(RM) $(PLUGIN).html
	cat $(PLUGIN).de.html >> $(PLUGIN).html
	sed -ri '/col width/d' $(PLUGIN).html

.PHONY: unix2dos
unix2dos:
	@[ -f /usr/bin/unix2dos ] && unix2dos $(PLUGIN).html

.PHONY: check
check:
	@[ -f `which asciidoc` ] || echo "Install asciidoc first"

dedoc:
	asciidoc --unsafe --no-header-footer -a max-width=800 $(PLUGIN).de.txt

endoc:
	asciidoc --unsafe --no-header-footer -a max-width=800 $(PLUGIN).en.txt

clean:
	rm -f $(PLUGIN).de.html
