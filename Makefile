.SUFFIXES: .less .css

styles:
	for FILE in stylesheets/*.less; do $(MAKE) `dirname $$FILE`/`basename $$FILE .less`.css; done

.less.css:
	lessc $^ $@
