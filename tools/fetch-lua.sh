#!/bin/sh
set -eu

root=${1:-.zlua-deps}
version=5.5.0

lua_url=${ZLUA_LUA_URL:-https://www.lua.org/ftp/lua-${version}.tar.gz}
tests_url=${ZLUA_LUA_TESTS_URL:-https://www.lua.org/tests/lua-${version}-tests.tar.gz}

lua_sha=57ccc32bbbd005cab75bcc52444052535af691789dba2b9016d5c50640d68b3d
tests_sha=5e47bbfad7db2965d69580e918ee64edeb8d8d32de404b8dae9ce5c6d76a1472

lua_archive=${root}/lua-${version}.tar.gz
tests_archive=${root}/lua-${version}-tests.tar.gz
lua_dir=${root}/lua-${version}
tests_dir=${root}/lua-${version}-tests

mkdir -p "$root"

sha256_file() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" | awk '{print $1}'
    else
        echo "fetch-lua: need sha256sum or shasum" >&2
        exit 1
    fi
}

download() {
    url=$1
    path=$2
    if [ -f "$path" ]; then
        return
    fi

    tmp=${path}.tmp
    rm -f "$tmp"
    if command -v curl >/dev/null 2>&1; then
        curl -L --fail --output "$tmp" "$url"
    elif command -v wget >/dev/null 2>&1; then
        wget -O "$tmp" "$url"
    else
        echo "fetch-lua: need curl or wget" >&2
        exit 1
    fi
    mv "$tmp" "$path"
}

verify() {
    path=$1
    expected=$2
    actual=$(sha256_file "$path")
    if [ "$actual" != "$expected" ]; then
        echo "fetch-lua: checksum mismatch for $path" >&2
        echo "  expected: $expected" >&2
        echo "  actual:   $actual" >&2
        exit 1
    fi
}

download "$lua_url" "$lua_archive"
download "$tests_url" "$tests_archive"

verify "$lua_archive" "$lua_sha"
verify "$tests_archive" "$tests_sha"

if [ ! -f "$lua_dir/src/lua.h" ]; then
    rm -rf "$lua_dir"
    tar -xzf "$lua_archive" -C "$root"
fi

if [ ! -f "$tests_dir/all.lua" ]; then
    rm -rf "$tests_dir"
    tar -xzf "$tests_archive" -C "$root"
fi
