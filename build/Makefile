VERSION=2.0b2
SVN=http://code.sixapart.com/svn/mtplugins/trunk/MediaManager/branches/4.x
PACKAGE=MediaManager-$(VERSION)

package:
	svn export $(SVN) $(PACKAGE)
	tar --exclude="*.svn" --exclude="*~" --exclude="build" --exclude="#*" -zcvf $(PACKAGE).tar.gz $(PACKAGE)
	zip -r $(PACKAGE).zip $(PACKAGE) -x $(PACKAGE)/build
	rm -rf MediaManager-$(VERSION)

clean:
	rm -rf MediaManager-$(VERSION)
	rm -f *~

real-clean: clean
	rm -f *.tar.gz
	rm -f *.zip