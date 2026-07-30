//! Acceptance tests for the eval-rust battery. Nodes never edit this file, nor `src/main.rs`.
//!
//! These deliberately do NOT link the model-edited library. Each test runs the `eval_rust`
//! binary as a SUBPROCESS and judges its output, so model code and assertions never share a
//! process (issue #7).
//!
//! Relocating the tests out of the editable `src/lib.rs` (issue #4) stopped a node being
//! scored GREEN by deleting its test. It did not stop one being scored GREEN by
//! `std::process::exit(0)` inside a library function: that returns `!`, so it type-checks in
//! any position, and it terminated the whole test binary with a success status before a
//! single assertion ran. `observe` closes that by requiring *positive evidence* — a child
//! that exits early prints nothing and cannot match.

use std::io::Read;
use std::process::{Command, Stdio};
use std::sync::mpsc;
use std::time::Duration;

/// A hung child must score RED, not stall the battery. An unbounded `output()` would
/// wait forever on an implementation that blocks (a `loop {}`, a read from stdin), and a
/// measurement harness that hangs is worse than one that fails.
const PROBE_TIMEOUT: Duration = Duration::from_secs(60);

/// Run one case out-of-process and return its observed lines.
fn observe(case: &str) -> Vec<String> {
    let mut child = Command::new(env!("CARGO_BIN_EXE_eval_rust"))
        .arg(case)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .unwrap_or_else(|e| panic!("could not run the probe binary for {case}: {e}"));

    // Read both pipes on a worker thread so the timeout below cannot be defeated by a
    // child that fills a pipe buffer and blocks instead of exiting.
    let mut out_pipe = child.stdout.take().expect("piped stdout");
    let mut err_pipe = child.stderr.take().expect("piped stderr");
    let (tx, rx) = mpsc::channel();
    std::thread::spawn(move || {
        let mut o = String::new();
        let mut e = String::new();
        let _ = out_pipe.read_to_string(&mut o);
        let _ = err_pipe.read_to_string(&mut e);
        let _ = tx.send((o, e));
    });

    let (stdout, stderr) = rx
        .recv_timeout(PROBE_TIMEOUT)
        .unwrap_or_else(|_| {
            let _ = child.kill();
            let _ = child.wait();
            panic!(
                "probe for {case} produced no complete output within {PROBE_TIMEOUT:?} — \
                 killed. A hung implementation is a failure, not a pass."
            )
        });
    let out = child
        .wait()
        .unwrap_or_else(|e| panic!("could not reap the probe for {case}: {e}"));

    assert!(
        out.success(),
        "probe for {case} exited {:?} without producing observations; stderr:\n{}",
        out.code(),
        stderr.trim()
    );
    assert!(
        !stdout.trim().is_empty(),
        "probe for {case} exited 0 but printed nothing — the implementation terminated the \
         process before the observation was produced, which is not a pass"
    );
    stdout.lines().map(|s| s.to_string()).collect()
}

#[test]
fn test_compact_path() {
    assert_eq!(observe("compact_path"), ["a/…/d", "a/b", "only"]);
}

#[test]
fn test_longest_common_dir() {
    assert_eq!(observe("longest_common_dir"), ["src", "src/a", "", ""]);
}

#[test]
fn test_strip_prefix_dir() {
    assert_eq!(observe("strip_prefix_dir"), ["a/x.rs", "src/a/x.rs", "src"]);
}

#[test]
fn test_encode_decode_roundtrip() {
    assert_eq!(
        observe("encode_decode_roundtrip"),
        [
            "a/b/c",
            "plain",
            "x/y",
            "/leading",
            "trailing/",
            "a%2Fb",
            "false",
        ]
    );
}

#[test]
fn test_split_join_ext_roundtrip() {
    assert_eq!(
        observe("split_join_ext_roundtrip"),
        ["main", "rs", "README", "", "main.rs", "README", "archive.tar"]
    );
}

#[test]
fn test_visible_count() {
    assert_eq!(observe("visible_count"), ["true", "false", "2"]);
}
