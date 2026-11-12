.PHONY: test preview icons package
test:
	./tools/run_tests.sh
preview:
	python3 tools/setup_lua55.py
	python3 tools/preview.py
icons:
	python3 tools/app_icon.py
package: test
	python3 tools/package_local.py
