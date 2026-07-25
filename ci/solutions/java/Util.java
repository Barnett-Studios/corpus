// Reference solution for the java katas (validation only — NEVER shipped into
// red-baseline/). One solved file covers all six java katas; ci/prove-solvable.sh
// overlays it onto each kata's seed and asserts the fixed accept exits 0.
import java.util.*;

public class Util {

    public static String compactPath(String path, int max) {
        String[] parts = path.split("/", -1);
        if (parts.length <= max) {
            return path;
        }
        return parts[0] + "/…/" + parts[parts.length - 1];
    }

    public static String longestCommonDir(String[] paths) {
        if (paths.length == 0) {
            return "";
        }
        List<String[]> parents = new ArrayList<>();
        int minLen = Integer.MAX_VALUE;
        for (String p : paths) {
            String[] ps = p.split("/", -1);
            String[] par = Arrays.copyOf(ps, ps.length - 1);
            parents.add(par);
            minLen = Math.min(minLen, par.length);
        }
        List<String> common = new ArrayList<>();
        for (int i = 0; i < minLen; i++) {
            String seg = parents.get(0)[i];
            boolean ok = true;
            for (String[] par : parents) {
                if (!par[i].equals(seg)) {
                    ok = false;
                    break;
                }
            }
            if (!ok) {
                break;
            }
            common.add(seg);
        }
        return String.join("/", common);
    }

    public static String stripPrefixDir(String path, String prefix) {
        String pre = prefix + "/";
        return path.startsWith(pre) ? path.substring(pre.length()) : path;
    }

    public static String encodeSeg(String s) {
        return s.replace("/", "%2F");
    }

    public static String decodeSeg(String s) {
        return s.replace("%2F", "/");
    }

    public static String[] splitExt(String name) {
        int i = name.lastIndexOf('.');
        if (i == -1) {
            return new String[]{name, ""};
        }
        return new String[]{name.substring(0, i), name.substring(i + 1)};
    }

    public static String joinExt(String stem, String ext) {
        return ext.isEmpty() ? stem : stem + "." + ext;
    }

    public static boolean isHidden(String name) {
        return name.startsWith(".");
    }

    public static int visibleCount(String[] names) {
        int c = 0;
        for (String n : names) {
            if (!isHidden(n)) {
                c++;
            }
        }
        return c;
    }
}
