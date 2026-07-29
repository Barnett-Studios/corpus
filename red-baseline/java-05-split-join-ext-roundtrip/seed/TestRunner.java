import java.io.BufferedReader;
import java.io.File;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;
import java.util.concurrent.TimeUnit;

// Fixed harness — nodes never edit this file, nor UtilProbe.java. Usage: java TestRunner <name>.
// Prints exactly "PASS" on success, otherwise "FAIL" (and exits non-zero).
//
// This class deliberately does NOT call Util. It runs UtilProbe as a SUBPROCESS and judges the
// lines it prints, so model-edited code and the assertions never share a JVM (issue #7).
//
// Previously both ran in one JVM, so `System.exit(0)` inside a Util method ended the run with a
// success status before any check completed — an edit to Util.java alone, which every node already
// permits. `observe` closes that by requiring positive evidence: the child must exit 0 AND print a
// complete, matching observation. A child that dies early prints nothing.
public class TestRunner {

    // A hung child scores RED rather than stalling the battery.
    static final long PROBE_TIMEOUT_SECONDS = 60;

    static List<String> observe(String caseName) throws Exception {
        // Reuse the JVM running this class, so nothing depends on `java` being on PATH.
        String java = System.getProperty("java.home") + File.separator + "bin" + File.separator + "java";
        ProcessBuilder pb = new ProcessBuilder(java, "-cp", ".", "UtilProbe", caseName);
        pb.directory(new File("."));
        Process p = pb.start();

        // Slurp stdout on a worker thread. A blocking read on the main thread would let a
        // hung implementation stall the battery forever, and a harness that hangs is worse
        // than one that fails — a hung child must score RED.
        List<String> lines = Collections.synchronizedList(new ArrayList<>());
        Thread reader = new Thread(() -> {
            try (BufferedReader r = new BufferedReader(
                    new InputStreamReader(p.getInputStream(), StandardCharsets.UTF_8))) {
                String line;
                while ((line = r.readLine()) != null) {
                    lines.add(line);
                }
            } catch (Exception ignored) {
                // A closed pipe just means no more observations; the checks below decide.
            }
        });
        reader.setDaemon(true);
        reader.start();

        if (!p.waitFor(PROBE_TIMEOUT_SECONDS, TimeUnit.SECONDS)) {
            p.destroyForcibly();
            throw new AssertionError("probe for " + caseName + " produced no complete output within "
                    + PROBE_TIMEOUT_SECONDS + "s — killed. A hung implementation is a failure, not a pass.");
        }
        reader.join(5000);
        int rc = p.exitValue();
        if (rc != 0) {
            throw new AssertionError(
                    "probe for " + caseName + " exited " + rc + " without producing observations");
        }
        if (lines.isEmpty()) {
            throw new AssertionError(
                    "probe for " + caseName + " exited 0 but printed nothing — the implementation "
                            + "terminated the process before the observation was produced, which is not a pass");
        }
        return lines;
    }

    static void expect(String caseName, String... want) throws Exception {
        List<String> got = observe(caseName);
        if (!got.equals(Arrays.asList(want))) {
            throw new AssertionError("got " + got + " want " + Arrays.toString(want));
        }
    }

    public static void main(String[] args) {
        if (args.length != 1) {
            System.out.println("FAIL");
            System.exit(2);
        }
        try {
            switch (args[0]) {
                case "compactPath":
                    expect("compactPath", "a/…/d", "a/b", "only");
                    break;
                case "longestCommonDir":
                    expect("longestCommonDir", "src", "src/a", "", "");
                    break;
                case "stripPrefixDir":
                    expect("stripPrefixDir", "a/X.java", "src/a/X.java", "src");
                    break;
                case "encodeDecode":
                    expect("encodeDecode", "a/b/c", "plain", "x/y", "/leading", "trailing/", "a%2Fb");
                    break;
                case "splitJoinExt":
                    expect("splitJoinExt", "Main", "java", "README", "", "Main.java", "README", "archive.tar");
                    break;
                case "visibleCount":
                    expect("visibleCount", "true", "false", "2");
                    break;
                default:
                    System.out.println("FAIL");
                    System.exit(2);
            }
            System.out.println("PASS");
        } catch (Throwable t) {
            System.out.println("FAIL");
            System.err.println(t);
            System.exit(1);
        }
    }
}
