/*
 * bigsort.chpl
 * BigSort - High-performance parallel sorting for large datasets in Chapel
 *
 * This program demonstrates Chapel's elegant support for parallel programming
 * by implementing a parallel merge sort that scales across cores.
 *
 * Usage examples:
 *   ./bigsort --n=10000000 --seed=42 --verify
 *   ./bigsort --n=5000000 --compare
 *   ./bigsort --file=input.txt --output=sorted.txt
 *
 * For truly massive data that exceeds RAM, a future version will add
 * external merge sort (chunked sort + k-way merge to disk).
 */

module BigSort {

  use Time;
  use Random;
  use Sort;           // Chapel's built-in parallel sort for comparison
  use IO;
  use FileSystem;
  use List;           // for readLines buffer
  use OS.POSIX;       // for exit() in older Chapel; modern uses halt()

  // Configuration parameters (set via command line or defaults)
  config const n: int = 10_000_000;           // Number of elements to sort
  config const seed: int = 42;                // RNG seed for reproducibility
  config const threshold: int = 2048;         // Switch to serial sort below this size
  config const verify: bool = false;          // Verify results after sorting
  config const compare: bool = false;         // Also run and time Chapel's built-in sort
  config const quiet: bool = false;           // Suppress progress output
  config const file: string = "";             // Input file (one item per line)
  config const output: string = "";           // Output file for sorted data
  config const numeric: bool = false;         // Numeric sort (for file mode)
  config const reverse: bool = false;         // Reverse sort order

  // ============================================================
  // Parallel Merge Sort Implementation
  // ============================================================

  /*
   * Parallel merge sort using divide-and-conquer with coforall.
   * This is the heart of BigSort - showcasing Chapel's parallelism.
   */
  proc parallelMergeSort(ref data: [] int, lo: int, hi: int) {
    if (hi - lo + 1) <= threshold {
      // Small chunk: use simple insertion sort (serial, cache-friendly)
      insertionSort(data, lo, hi);
      return;
    }

    const mid = lo + (hi - lo) / 2;

    // Recurse in parallel on both halves
    coforall i in 0..1 {
      if i == 0 then
        parallelMergeSort(data, lo, mid);
      else
        parallelMergeSort(data, mid + 1, hi);
    }

    // Merge the two sorted halves
    merge(data, lo, mid, hi);
  }

  /*
   * Simple insertion sort for small subarrays.
   */
  proc insertionSort(ref data: [] int, lo: int, hi: int) {
    for i in lo+1..hi {
      const key = data[i];
      var j = i - 1;
      while j >= lo && data[j] > key {
        data[j+1] = data[j];
        j -= 1;
      }
      data[j+1] = key;
    }
  }

  /*
   * Merge two sorted adjacent subarrays [lo..mid] and [mid+1..hi]
   * into a temporary buffer then copy back.
   */
  proc merge(ref data: [] int, lo: int, mid: int, hi: int) {
    const leftSize = mid - lo + 1;
    const rightSize = hi - mid;

    // Temporary arrays for the two halves
    var left: [0..#leftSize] int;
    var right: [0..#rightSize] int;

    // Copy data
    forall i in 0..#leftSize do left[i] = data[lo + i];
    forall i in 0..#rightSize do right[i] = data[mid + 1 + i];

    var i = 0, j = 0, k = lo;

    // Standard merge
    while i < leftSize && j < rightSize {
      if left[i] <= right[j] {
        data[k] = left[i];
        i += 1;
      } else {
        data[k] = right[j];
        j += 1;
      }
      k += 1;
    }

    // Copy remaining elements
    while i < leftSize {
      data[k] = left[i];
      i += 1;
      k += 1;
    }
    while j < rightSize {
      data[k] = right[j];
      j += 1;
      k += 1;
    }
  }

  /*
   * Wrapper that sorts an entire array using our parallel merge sort.
   */
  proc bigSort(ref data: [] int) {
    if data.size == 0 then return;
    parallelMergeSort(data, 0, data.size - 1);
  }

  // ============================================================
  // File-based sorting (for strings / lines)
  // ============================================================

  proc readLines(filename: string): [] string throws {
    var f = open(filename, ioMode.r);
    var r = f.reader(locking=false);

    var lines: list(string);
    var line: string;

    while r.readLine(line, stripNewline=true) {
      lines.pushBack(line);
    }

    r.close();
    f.close();

    return lines.toArray();
  }

  proc writeLines(filename: string, lines: [] string) throws {
    var f = open(filename, ioMode.cw);
    var w = f.writer(locking=false);

    for line in lines {
      w.writeln(line);
    }

    w.close();
    f.close();
  }

  // ============================================================
  // Verification and Utilities
  // ============================================================

  proc isSorted(data: [] int): bool {
    for i in 0..#data.size-1 {
      if data[i] > data[i+1] then return false;
    }
    return true;
  }

  proc verifySorted(data: [] int, name: string) {
    if isSorted(data) {
      if !quiet then writeln(name, ": OK (correctly sorted)");
    } else {
      writeln("ERROR: ", name, " produced incorrect results!");
      halt(1);
    }
  }

  proc printStats(n: int, elapsed: real, name: string) {
    const mps = n:real / elapsed / 1_000_000.0;  // million elements per second
    if !quiet then
      writeln(name, ": ", elapsed, " seconds (", mps, " M elements/sec)");
  }

  // ============================================================
  // Main
  // ============================================================

  proc main(args: [] string) {
    var timer: stopwatch;

    if file != "" {
      // ===================== FILE MODE =====================
      if !quiet then writeln("BigSort - Sorting file: ", file);
      if !quiet then writeln("Reading lines...");

      var data = try! readLines(file);

      if !quiet then writeln("Read ", data.size, " lines. Sorting...");

      timer.start();
      if numeric {
        // Numeric sort by parsing (simple, assumes valid integers)
        var nums: [data.domain] int;
        forall (i, s) in zip(data.domain, data) do nums[i] = try! s:int;
        bigSort(nums);
        // write back as strings (or keep numeric representation)
        forall (i, v) in zip(data.domain, nums) do data[i] = v:string;
      } else {
        // Lexicographic string sort using built-in (parallel)
        sort(data);
      }
      timer.stop();

      printStats(data.size, timer.elapsed(), "Sort (file)");

      if output != "" {
        try {
          writeLines(output, data);
          if !quiet then writeln("Wrote sorted output to ", output);
        } catch e {
          writeln("Error writing output: ", e.message());
        }
      } else if data.size < 100 {
        for line in data do writeln(line);
      } else {
        if !quiet then writeln("(output suppressed for large results; use --output)");
      }

      return;
    }

    // ===================== LARGE ARRAY MODE (default) =====================
    if !quiet {
      writeln("BigSort - Parallel Merge Sort in Chapel");
      writeln("========================================");
      writeln("Elements : ", n);
      writeln("Seed     : ", seed);
      writeln("Threshold: ", threshold);
      writeln();
    }

    // Generate random data (fillRandom is parallel-safe and efficient)
    if !quiet then write("Generating random data... ");
    var data: [0..#n] int;
    fillRandom(data, seed);
    // Scale to desired range [0, 1e9] if needed (fillRandom gives [0,1) reals by default for reals;
    // for ints it fills with random ints). For bounded, do a simple map:
    forall x in data do x = abs(x) % 1_000_000_001;
    if !quiet then writeln("done.");

    var originalData: [data.domain] int = data;  // for potential reuse

    // ----- Our parallel merge sort -----
    if !quiet then write("Running BigSort parallel merge sort... ");
    timer.start();
    bigSort(data);
    timer.stop();
    const bigsortTime = timer.elapsed();
    printStats(n, bigsortTime, "BigSort (parallel merge)");

    if verify {
      verifySorted(data, "BigSort");
    }

    // ----- Optional: Chapel built-in sort comparison -----
    if compare {
      data = originalData;  // reset

      if !quiet then write("Running Chapel built-in sort (Sort.sort)... ");
      timer.start();
      sort(data);
      timer.stop();
      const builtinTime = timer.elapsed();
      printStats(n, builtinTime, "Chapel built-in sort");

      if verify {
        verifySorted(data, "Chapel built-in");
      }

      if !quiet {
        const speedup = bigsortTime / builtinTime;
        writeln();
        writeln("Relative: BigSort took ", speedup, "x the time of built-in sort");
        writeln("(Note: Chapel's built-in sort is highly optimized; our merge sort");
        writeln(" is a teaching implementation that demonstrates parallel patterns.)");
      }
    }

    // ----- Optional: write sorted output (only for modest sizes) -----
    if output != "" && n <= 10_000_000 {
      try {
        var f = open(output, ioMode.cw);
        var w = f.writer();
        for x in data do w.writeln(x);
        w.close();
        f.close();
        if !quiet then writeln("Wrote sorted data to ", output);
      } catch e {
        writeln("Warning: could not write output file: ", e.message());
      }
    } else if output != "" {
      if !quiet then writeln("Output file requested but n is very large; skipping write.");
    }

    if !quiet {
      writeln();
      writeln("Try larger sizes with: --n=50000000");
      writeln("Compare against built-in: --compare");
      writeln("Enable verification: --verify");
    }
  }
}
