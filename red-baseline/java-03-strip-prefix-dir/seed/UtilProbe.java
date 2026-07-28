import java.io.PrintStream;
import java.nio.charset.StandardCharsets;

// Fixed harness — nodes never edit this file (only Util.java is in `files:`).
//
// This is the only caller of the model-edited Util. It computes observations and prints
// them, one per line; it asserts NOTHING. All judgement lives in TestRunner, which runs
// this class as a SUBPROCESS.
//
// That split is the point (issue #7). TestRunner was already a separate main(), but it ran
// in the SAME JVM as Util, so `System.exit(0)` inside any Util method terminated the whole
// run with a success status before an assertion completed. Out-of-process it kills only
// this child, which then prints no observations, and the parent requires positive evidence
// rather than merely a zero exit.
//
// Usage: java UtilProbe <case-name>   ->  one observation per line on stdout, exit 0
public class UtilProbe {

    // Write UTF-8 explicitly rather than relying on the platform default, so the "…" in
    // compactPath survives regardless of the JVM's file.encoding.
    static final PrintStream OUT = new PrintStream(System.out, true, StandardCharsets.UTF_8);

    static void emit(Object o) {
        OUT.println(String.valueOf(o));
    }

    public static void main(String[] args) {
        if (args.length != 1) {
            System.err.println("usage: UtilProbe <case-name>");
            System.exit(2);
        }
        switch (args[0]) {
            case "compactPath":
                emit(Util.compactPath("a/b/c/d", 3));
                emit(Util.compactPath("a/b", 3));
                emit(Util.compactPath("only", 3));
                break;
            case "longestCommonDir":
                emit(Util.longestCommonDir(new String[]{"src/a/X.java", "src/a/Y.java", "src/b/Z.java"}));
                emit(Util.longestCommonDir(new String[]{"src/a/X.java"}));
                emit(Util.longestCommonDir(new String[]{"A.java", "B.java"}));
                emit(Util.longestCommonDir(new String[]{}));
                break;
            case "stripPrefixDir":
                emit(Util.stripPrefixDir("src/a/X.java", "src"));
                emit(Util.stripPrefixDir("src/a/X.java", "lib"));
                emit(Util.stripPrefixDir("src", "src"));
                break;
            case "encodeDecode":
                for (String s : new String[]{"a/b/c", "plain", "x/y", "/leading", "trailing/"}) {
                    emit(Util.decodeSeg(Util.encodeSeg(s)));
                }
                emit(Util.encodeSeg("a/b"));
                break;
            case "splitJoinExt": {
                String[] a = Util.splitExt("Main.java");
                emit(a[0]);
                emit(a[1]);
                String[] b = Util.splitExt("README");
                emit(b[0]);
                emit(b[1]);
                emit(Util.joinExt("Main", "java"));
                emit(Util.joinExt("README", ""));
                String[] p = Util.splitExt("archive.tar");
                emit(Util.joinExt(p[0], p[1]));
                break;
            }
            case "visibleCount":
                emit(Util.isHidden(".git"));
                emit(Util.isHidden("src"));
                emit(Util.visibleCount(new String[]{".git", "src", ".env", "Main.java"}));
                break;
            default:
                System.err.println("unknown case: " + args[0]);
                System.exit(2);
        }
    }
}
