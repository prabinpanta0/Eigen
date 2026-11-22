# Eigen

A high-performance, terminal-based matrix calculator built with a modern Java/C++ architecture.

## About

**Eigen** is a collaborative project between developers learning and mastering different programming languages:

- **Java**
- **C++**

It allows users to type matrix expressions into a full-screen Terminal UI (TUI). The Java application handles parsing, operator precedence, variables, and the user interface. A C++ shared library handles all heavy matrix math, memory layout, and elimination algorithms for maximum speed.

The two sides communicate directly using Java's Foreign Function & Memory (FFM) API (Project Panama) — no JNI, no separate processes, and zero text-parsing overhead.

## Tech Stack

- **Java 25**: TUI, parsing, evaluation, and FFM boundary.
- **C++23**: Core math engine, manual memory management, and shared library generation.
- **Build Tools**: Maven (Java), GNU Make (C++).
- **Terminal**: Modern UTF-8 terminal (Windows Terminal, GNOME Terminal, etc.).

## Quick Start

1. Clone the repo:
   ```bash
   git clone https://github.com/prabinpanta0/Eigen.git
   cd Eigen
   ```
2. Ensure you have JDK 25 (64-bit), Maven, and a modern C++ compiler installed:

```bash
java -version       # MUST say "25" (or at least 22+) and "64-Bit"
mvn -v              # MUST show Java 25 in the output
clang++ --version   # MUST be installed (C++17/C++23 compatible)
make --version      # MUST be installed
git --version       # MUST be installed
```

3. Run ./build.sh to compile both the C++ library and the Java application.

## Team

- C++ Dev: Engine, memory management, and algorithms.
- Java Dev: TUI, parser, evaluator, and FFM bindings.
- A Random Person: This is me but I don't know what I'm doing
