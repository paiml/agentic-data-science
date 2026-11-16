// Fetch.java URL OUT : curl-free download for images without curl (java scripts/Fetch.java URL OUT). Exit 1 on a non-200.
import java.net.URI;
import java.net.http.*;
import java.nio.file.Path;

public class Fetch {
    public static void main(String[] a) throws Exception {
        HttpClient c = HttpClient.newBuilder().followRedirects(HttpClient.Redirect.ALWAYS).build();
        HttpResponse<Path> r = c.send(HttpRequest.newBuilder(URI.create(a[0])).build(), HttpResponse.BodyHandlers.ofFile(Path.of(a[1])));
        if (r.statusCode() != 200) { System.err.println("HTTP " + r.statusCode()); System.exit(1); }
    }
}
