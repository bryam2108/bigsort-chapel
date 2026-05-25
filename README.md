# BigSort — Parallel Sorting in Chapel

[![Chapel](https://img.shields.io/badge/Chapel-2.x-blue)](https://chapel-lang.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**BigSort** is a high-performance parallel sorting demonstration written in [Chapel](https://chapel-lang.org/), showcasing how elegantly Chapel expresses parallel divide-and-conquer algorithms.

---

## 🌐 Sitio web moderno

**¡Visita la nueva landing page oficial!**

**[https://bryam2108.github.io/bigsort-chapel/](https://bryam2108.github.io/bigsort-chapel/)**

Una página web moderna, completamente en español, con:
- Demostración interactiva del algoritmo de ordenamiento
- Animaciones fluidas y diseño de alto nivel
- Benchmarks visuales y ejemplos listos para copiar
- Instrucciones rápidas de instalación

> **Cómo publicar la web (una sola vez):**
>
> 1. Ve a **Settings → Pages**
> 2. En **Source**, selecciona **GitHub Actions**
> 3. Guarda.
>
> ¡Listo! A partir de ahora, cada vez que hagas push a `main`, la web se desplegará automáticamente gracias al workflow en `.github/workflows/deploy-pages.yml`.

---

## Features

- **Parallel merge sort** implemented from scratch in ~60 lines of clean Chapel
- Configurable serial cutoff (`--threshold`) for cache-friendly small sorts
- **Built-in comparison mode** (`--compare`) against Chapel's highly optimized `Sort.sort`
- Random data generation with reproducible seeds
- Optional verification (`--verify`)
- Basic support for sorting text files line-by-line (`--file`)
- Excellent single-node multi-core performance

> **Note**: Current version performs in-memory parallel sorting (ideal for datasets that fit in RAM, from millions to hundreds of millions of elements). A full **external merge sort** mode for multi-terabyte files is planned for a future release.

## Quick Start

### Prerequisites

- Chapel compiler ≥ 2.0 (tested with 2.8+)
- A multi-core machine (the more cores, the more impressive the scaling)

```bash
# macOS with Homebrew
brew install chapel

# Or build from source / use Spack, etc.
```

### Build

```bash
make
# or directly:
chpl -O bigsort.chpl -o bigsort
```

If you have a non-standard Chapel installation:

```bash
CHPL_HOME=/path/to/chapel make
```

### Run

```bash
# Default: 10 million integers, parallel merge sort
./bigsort

# Larger run with verification and built-in comparison
./bigsort --n=50000000 --verify --compare

# Small quick test (useful for CI)
make test

# Custom seed and cutoff
./bigsort --n=20000000 --seed=123 --threshold=4096 --verify
```

Example output:

```
BigSort - Parallel Merge Sort in Chapel
========================================
Elements : 10000000
Seed     : 42
Threshold: 2048

Generating random data... done.
Running BigSort parallel merge sort... BigSort (parallel merge): 1.87 seconds (5.35 M elements/sec)
Running Chapel built-in sort (Sort.sort)... Chapel built-in sort: 0.92 seconds (10.87 M elements/sec)

Relative: BigSort took 2.03x the time of built-in sort
```

## Command Line Options

| Option           | Default     | Description |
|------------------|-------------|-------------|
| `--n`            | 10000000    | Number of random integers to generate and sort |
| `--seed`         | 42          | RNG seed (reproducibility) |
| `--threshold`    | 2048        | Serial cutoff size for insertion sort |
| `--verify`       | false       | Check that the result is correctly sorted |
| `--compare`      | false       | Also time Chapel's built-in `Sort.sort` |
| `--quiet`        | false       | Minimal output |
| `--file=FILE`    | (none)      | Sort lines from a text file instead of random ints |
| `--output=FILE`  | (none)      | Write sorted results to file |
| `--numeric`      | false       | Numeric sort when using `--file` |
| `--reverse`      | false       | (Reserved for future use) |

## The Algorithm

BigSort implements **parallel merge sort**:

1. Divide the array into two halves
2. Sort both halves **in parallel** using `coforall`
3. Merge the sorted halves (serial merge for simplicity and correctness)

The recursion bottoms out at `--threshold` elements, where a simple insertion sort finishes the job (excellent cache behavior for small subproblems).

```chapel
coforall i in 0..1 {
  if i == 0 then
    parallelMergeSort(data, lo, mid);
  else
    parallelMergeSort(data, mid + 1, hi);
}
merge(data, lo, mid, hi);
```

This pattern — trivial expression of recursive parallelism — is where Chapel shines compared to traditional HPC languages.

## Performance Notes

- On a modern 8–16 core laptop you should see several million elements per second.
- Chapel's built-in sort (`Sort.sort`) is extremely well tuned (radix + quicksort hybrids + parallel). Our merge sort is intentionally a clean teaching implementation.
- Use `--fast` or `-O` for best results.
- Memory bandwidth is usually the limiter for in-memory sorts of this size.

Future external sort implementation will remove the "must fit in RAM" limitation by using temporary files and k-way merging.

## Project Structure

```
.
├── bigsort.chpl     # Main BigSort implementation + CLI
├── hello.chpl       # Minimal "Hello, world!" Chapel example
├── Makefile         # Build system
├── README.md        # This file
├── .gitignore
├── LICENSE
├── index.html         # ✨ Modern landing page (Spanish)
├── .nojekyll
├── .github/workflows/deploy-pages.yml
└── test.sh
```

## Building for Distributed Memory (Future)

BigSort currently targets single-node shared-memory parallelism. When Chapel's distributed arrays and multi-locale execution are used, the same algorithmic skeleton can be extended to sort data across a cluster with almost no change to the core logic.

```bash
make build-dist   # (requires GASNet etc.)
```

## Contributing

Pull requests are welcome! Ideas for v2:

- True external merge sort (chunked I/O + parallel k-way merge)
- Support for strings / records with custom comparators
- Multi-locale / distributed memory version
- GPU offload via Chapel's GPU support

## License

MIT License. See [LICENSE](LICENSE).

## Learn More

- [Chapel Language](https://chapel-lang.org/)
- [Chapel Documentation](https://chapel-lang.org/docs/)
- [Parallel Programming Concepts in Chapel](https://chapel-lang.org/docs/primers/)

---

*Originally started as a minimal Hello World in the `hello-chapel` workspace. Evolved into BigSort to demonstrate real parallel computing patterns in Chapel.*

**Created with ❤️ and the help of Grok for Chapel enthusiasts.**
