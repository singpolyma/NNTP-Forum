styles:
	for FILE in stylesheets/*.less; do $(MAKE) `dirname $$FILE`/`basename $$FILE .less`.css; done

.PHONY: clean
clean:
	$(RM) $^ stylesheets/*.css

.SUFFIXES: .less .css
.less.css:
	lessc $^ $@
