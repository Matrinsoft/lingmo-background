name := 'cosmic-bg'
export APPID := 'com.system76.CosmicBackground'

# Use mold linker if clang and mold exists.
clang-path := `which clang || true`
mold-path := `which mold || true`

linker-arg := if clang-path != '' {
    if mold-path != '' {
        '-C linker=' + clang-path + ' -C link-arg=--ld-path=' + mold-path + ' '
    } else {
        ''
    }
} else {
    ''
}

export RUSTFLAGS := linker-arg + env_var_or_default('RUSTFLAGS', '')

rootdir := ''
prefix := '/usr'


base-dir := absolute_path(clean(rootdir / prefix))

export INSTALL_DIR := base-dir / 'share'

cargo-target-dir := env('CARGO_TARGET_DIR', 'target')
bin-src := cargo-target-dir / 'release' / name
bin-dst := base-dir / 'bin' / name

# Default recipe which runs `just build-release`
default: build-release

# Runs `cargo clean`
clean:
    cargo clean

# `cargo clean` and removes vendored dependencies
clean-dist: clean
    rm -rf .cargo vendor vendor.tar

# Compiles with debug profile
build-debug *args:
    cargo build {{args}}

# Compiles with release profile
build-release *args: (build-debug '--release' args)

# Compiles release profile with vendored dependencies
build-vendored *args:
    @just vendor-extract
    cargo build --release {{ args }} --frozen --offline

# Runs a clippy check
check *args:
    cargo clippy --all-features {{args}} -- -W clippy::pedantic

# Runs a clippy check with JSON message format
check-json: (check '--message-format=json')

# Run with debug logs
run *args:
    env RUST_LOG=debug RUST_BACKTRACE=1 cargo run --release {{args}}

# Installs files
install:
    install -Dm0755 {{bin-src}} {{bin-dst}}
    @just data/install

# Uninstalls installed files
uninstall:
    rm {{bin-dst}}
    @just data/uninstall

# Vendor dependencies locally
vendor:
	mkdir -p .cargo
	cargo vendor --sync Cargo.toml --sync config/Cargo.toml 2>/dev/null | awk '/^\[/{p=1} p' > .cargo/config.toml
	if ! grep -q 'directory' .cargo/config.toml 2>/dev/null; then
	echo '[source.crates-io]' >> .cargo/config.toml
	echo 'replace-with = "vendored-sources"' >> .cargo/config.toml
	echo '' >> .cargo/config.toml
	echo '[source.vendored-sources]' >> .cargo/config.toml
	echo 'directory = "vendor"' >> .cargo/config.toml
	fi
	grep '^source = "git+" Cargo.lock | sed 's/source = "//;s/"$//' | sort -u | while read src; do \
	echo "[source \"$src\"]"; \
	echo 'replace-with = "vendored-sources"'; \
	echo ""; \
	done >> .cargo/config.toml
	tar pcf vendor.tar vendor .cargo/config.toml
	rm -rf vendor

# Extracts vendored dependencies
vendor-extract:
    #!/usr/bin/env sh
    rm -rf vendor
    tar pxf vendor.tar
