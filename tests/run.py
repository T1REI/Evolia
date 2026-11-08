import argparse
import pathlib
import shutil
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description="Run Acrylic checks with the Luau CLI.")
    parser.add_argument("--luau", default="luau", help="Path to the official Luau CLI executable")
    args = parser.parse_args()
    executable = shutil.which(args.luau)
    if not executable:
        parser.error("Luau CLI not found. Install it or pass --luau /path/to/luau.")

    root = pathlib.Path(__file__).resolve().parent.parent
    mock = (root / "tests/roblox_mock.lua").read_text(encoding="utf-8")
    module = (root / "modules/ui/acrylic.lua").read_text(encoding="utf-8")
    scope = mock + "\nlocal Acrylic = (function()\n" + module + "\nend)()\n"
    with tempfile.TemporaryDirectory(prefix="acrylic-tests-") as directory:
        for name in ("acrylic", "fullscreen"):
            source = scope + (root / f"tests/{name}.spec.lua").read_text(encoding="utf-8")
            path = pathlib.Path(directory) / f"{name}-tests.luau"
            path.write_text(source, encoding="utf-8")
            result = subprocess.run([executable, str(path)], check=False)
            if result.returncode:
                return result.returncode
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
