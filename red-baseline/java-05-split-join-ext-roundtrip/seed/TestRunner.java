import java.util.Arrays;

// Fixed harness — nodes never edit this file. Usage: java TestRunner <name>.
// Runs only the named check; prints exactly "PASS" on success, otherwise "FAIL"
// (and exits non-zero). Any exception from an unimplemented Util method is
// caught and reported as FAIL.
public class TestRunner {

    static void eq(Object got, Object want) {
        boolean ok = (got instanceof String[] && want instanceof String[])
                ? Arrays.equals((String[]) got, (String[]) want)
                : (got == null ? want == null : got.equals(want));
        if (!ok) {
            throw new AssertionError("got " + str(got) + " want " + str(want));
        }
    }

    static String str(Object o) {
        return o instanceof String[] ? Arrays.toString((String[]) o) : String.valueOf(o);
    }

    static void compactPath() {
        eq(Util.compactPath("a/b/c/d", 3), "a/…/d");
        eq(Util.compactPath("a/b", 3), "a/b");
        eq(Util.compactPath("only", 3), "only");
    }

    static void longestCommonDir() {
        eq(Util.longestCommonDir(new String[]{"src/a/X.java", "src/a/Y.java", "src/b/Z.java"}), "src");
        eq(Util.longestCommonDir(new String[]{"src/a/X.java"}), "src/a");
        eq(Util.longestCommonDir(new String[]{"A.java", "B.java"}), "");
        eq(Util.longestCommonDir(new String[]{}), "");
    }

    static void stripPrefixDir() {
        eq(Util.stripPrefixDir("src/a/X.java", "src"), "a/X.java");
        eq(Util.stripPrefixDir("src/a/X.java", "lib"), "src/a/X.java");
        eq(Util.stripPrefixDir("src", "src"), "src");
    }

    static void encodeDecode() {
        for (String s : new String[]{"a/b/c", "plain", "x/y", "/leading", "trailing/"}) {
            eq(Util.decodeSeg(Util.encodeSeg(s)), s);
        }
        eq(Util.encodeSeg("a/b"), "a%2Fb");
    }

    static void splitJoinExt() {
        eq(Util.splitExt("Main.java"), new String[]{"Main", "java"});
        eq(Util.splitExt("README"), new String[]{"README", ""});
        eq(Util.joinExt("Main", "java"), "Main.java");
        eq(Util.joinExt("README", ""), "README");
        String[] p = Util.splitExt("archive.tar");
        eq(Util.joinExt(p[0], p[1]), "archive.tar");
    }

    static void visibleCount() {
        eq(Util.isHidden(".git"), true);
        eq(Util.isHidden("src"), false);
        eq(Util.visibleCount(new String[]{".git", "src", ".env", "Main.java"}), 2);
    }

    public static void main(String[] args) {
        if (args.length != 1) {
            System.out.println("FAIL");
            System.exit(2);
        }
        try {
            switch (args[0]) {
                case "compactPath": compactPath(); break;
                case "longestCommonDir": longestCommonDir(); break;
                case "stripPrefixDir": stripPrefixDir(); break;
                case "encodeDecode": encodeDecode(); break;
                case "splitJoinExt": splitJoinExt(); break;
                case "visibleCount": visibleCount(); break;
                default:
                    System.out.println("FAIL");
                    System.exit(2);
            }
            System.out.println("PASS");
        } catch (Throwable t) {
            System.out.println("FAIL");
            System.exit(1);
        }
    }
}
