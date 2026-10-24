"""Serve the single-threaded Web build locally; no cross-origin isolation required."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import argparse


class WebHandler(SimpleHTTPRequestHandler):
    extensions_map = {
        **SimpleHTTPRequestHandler.extensions_map,
        ".wasm": "application/wasm",
        ".js": "text/javascript",
        ".pck": "application/octet-stream",
    }

    def end_headers(self) -> None:
        self.send_header("Cache-Control", "no-store")
        super().end_headers()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory", default=".dist")
    parser.add_argument("--port", type=int, default=8060)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    directory = Path(args.directory)
    if not directory.is_absolute():
        directory = root / directory
    directory = directory.resolve()
    if not all((directory / name).is_file() for name in ["index.html", "index.js", "index.wasm", "index.pck"]):
        parser.error("Build files are missing. Run scripts/build_web.py first.")
    server = ThreadingHTTPServer(("127.0.0.1", args.port), partial(WebHandler, directory=str(directory)))
    print(f"Web preview: http://127.0.0.1:{server.server_port}/index.html", flush=True)
    print("Serving only the build directory. Stop with Ctrl+C.", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
