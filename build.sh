#!/usr/bin/env bash
# build.sh - build the Eigen C++ engine (shared library) and the Java app.
#
# Usage:
#   ./build.sh              build engine + app
#   ./build.sh --engine     build only the C++ engine
#   ./build.sh --app        build only the Java app
#   ./build.sh --test       build, then run C++ (ctest) and Java (mvn test) tests
#   ./build.sh --clean      remove build outputs
#
# Environment overrides:
#   CXX         C++ compiler (default: clang++, then g++)
#   CXXFLAGS    extra compiler flags for the direct-compile fallback
#
# Works on Linux, macOS (bash 3.2+), and Windows (Git Bash / MSYS2 / Cygwin).

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
engine_dir="${repo_root}/engine"
app_dir="${repo_root}/app"
build_dir="${engine_dir}/build"
output_lib_dir="${build_dir}/lib"
lib_name="eigen"

# ---------------------------------------------------------------- platform --

uname_s="$(uname -s)"
case "${uname_s}" in
    Linux*)
        platform="linux"
        lib_prefix="lib"
        lib_ext="so"
        ;;
    Darwin*)
        platform="macos"
        lib_prefix="lib"
        lib_ext="dylib"
        ;;
    MINGW*|MSYS*|CYGWIN*)
        platform="windows"
        lib_prefix=""
        lib_ext="dll"
        ;;
    *)
        echo "Error: unsupported operating system '${uname_s}'" >&2
        exit 1
        ;;
esac

output_lib="${output_lib_dir}/${lib_prefix}${lib_name}.${lib_ext}"

# ----------------------------------------------------------------- helpers --

log()  { echo "==> $*"; }
info() { echo "    $*"; }
die()  { echo "Error: $*" >&2; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

pick_compiler() {
    if [ -n "${CXX:-}" ]; then
        have "${CXX}" || die "CXX is set to '${CXX}' but it was not found"
        echo "${CXX}"
    elif have clang++; then
        echo "clang++"
    elif have g++; then
        echo "g++"
    else
        die "no C++ compiler found (install clang++ or g++)"
    fi
}

# Older compilers only know the C++23 draft as c++2b.
pick_cxx_standard() {
    local cxx="$1"
    if echo "" | "${cxx}" -std=c++23 -x c++ -fsyntax-only - >/dev/null 2>&1; then
        echo "c++23"
    elif echo "" | "${cxx}" -std=c++2b -x c++ -fsyntax-only - >/dev/null 2>&1; then
        echo "c++2b"
    else
        die "${cxx} does not support C++23; install a newer compiler"
    fi
}

check_java() {
    have java || die "java not found; JDK 25 is required"
    have mvn || [ -x "${app_dir}/mvnw" ] || die "Maven not found (install mvn or add app/mvnw)"

    local version_line major
    version_line="$(java -version 2>&1 | head -n 1)"
    major="$(echo "${version_line}" | sed -E 's/.*version "([0-9]+).*/\1/')"
    if [ -n "${major}" ] && [ "${major}" -lt 22 ] 2>/dev/null; then
        die "Java ${major} found, but the FFM API needs Java 22+ (project targets 25)"
    fi
}

# ------------------------------------------------------------------ engine --

build_engine() {
    log "Building C++ engine (${platform})..."
    mkdir -p "${build_dir}" "${output_lib_dir}"

    if [ -f "${engine_dir}/Makefile" ]; then
        make -C "${engine_dir}" all

        # Collect any library the Makefile produced into build/lib,
        # skipping files that are already there.
        find "${engine_dir}" -maxdepth 4 -name "*.${lib_ext}" -type f \
            -not -path "${output_lib_dir}/*" \
            -exec cp -f {} "${output_lib_dir}/" \;

    elif [ -d "${engine_dir}/src" ]; then
        local cxx std
        local src_files=()
        local f

        while IFS= read -r -d '' f; do
            src_files+=("${f}")
        done < <(find "${engine_dir}/src" -name "*.cpp" -type f -print0)

        if [ "${#src_files[@]}" -eq 0 ]; then
            info "No C++ sources in ${engine_dir}/src yet; skipping engine build."
            return 0
        fi

        cxx="$(pick_compiler)"
        std="$(pick_cxx_standard "${cxx}")"
        info "Compiler: ${cxx} (-std=${std}), ${#src_files[@]} source file(s)"

        local flags=("-std=${std}" -O2 -Wall -Wextra -shared)
        local include_dirs=("-I${engine_dir}")
        [ -d "${engine_dir}/include" ] && include_dirs+=("-I${engine_dir}/include")

        case "${platform}" in
            windows)
                # No -fPIC on Windows. Export every symbol so Java can find
                # them, and link the runtime statically so the JVM does not
                # need MinGW DLLs on PATH.
                flags+=(-Wl,--export-all-symbols -static-libgcc -static-libstdc++)
                ;;
            *)
                flags+=(-fPIC)
                ;;
        esac

        # shellcheck disable=SC2086
        "${cxx}" "${flags[@]}" ${CXXFLAGS:-} \
            "${include_dirs[@]}" \
            "${src_files[@]}" \
            -o "${output_lib}"

        info "Built ${output_lib}"
    else
        info "No Makefile or ${engine_dir}/src yet; skipping engine build."
    fi
}

# --------------------------------------------------------------------- app --

mvn_cmd() {
    if [ -x "${app_dir}/mvnw" ]; then
        (cd "${app_dir}" && ./mvnw -B "$@")
    else
        (cd "${app_dir}" && mvn -B "$@")
    fi
}

build_app() {
    log "Building Java application..."
    if [ ! -f "${app_dir}/pom.xml" ]; then
        info "No pom.xml in ${app_dir} yet; skipping Maven build."
        return 0
    fi
    check_java
    mvn_cmd package -DskipTests
}

# ------------------------------------------------------------------- tests --

run_tests() {
    log "Running C++ tests..."
    if [ -f "${build_dir}/CTestTestfile.cmake" ]; then
        ctest --test-dir "${build_dir}" --output-on-failure
    else
        info "No CTest configuration in ${build_dir}; skipping C++ tests."
    fi

    log "Running Java tests..."
    if [ -f "${app_dir}/pom.xml" ]; then
        check_java
        mvn_cmd test
    else
        info "No pom.xml in ${app_dir} yet; skipping Java tests."
    fi
}

# ------------------------------------------------------------------- clean --

clean_all() {
    log "Cleaning..."
    if [ -f "${engine_dir}/Makefile" ]; then
        make -C "${engine_dir}" clean || true
    fi
    rm -rf "${output_lib_dir}"
    if [ -f "${app_dir}/pom.xml" ]; then
        mvn_cmd clean || true
    fi
}

# -------------------------------------------------------------------- main --

usage() {
    sed -n '2,14p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

main() {
    local do_engine=1 do_app=1 do_test=0 do_clean=0

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --engine) do_app=0 ;;
            --app)    do_engine=0 ;;
            --test)   do_test=1 ;;
            --clean)  do_clean=1 ;;
            -h|--help) usage; exit 0 ;;
            *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
        esac
        shift
    done

    if [ "${do_clean}" -eq 1 ]; then
        clean_all
        exit 0
    fi

    [ "${do_engine}" -eq 1 ] && build_engine
    [ "${do_app}" -eq 1 ] && build_app
    [ "${do_test}" -eq 1 ] && run_tests

    log "Done. Native library (if built): ${output_lib}"
}

main "$@"