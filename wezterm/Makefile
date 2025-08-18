SRC := src/config.moon
OUT := build/config.lua

$(OUT): $(SRC)
	@mkdir -p build
	moonc -o $(OUT) $(SRC)

.PHONY: build
build: $(OUT)

.PHONY: clean
clean:
	rm -rf build
