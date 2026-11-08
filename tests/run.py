import argparse
import pathlib
import shutil
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description="Run Evolia and Acrylic checks with the Luau CLI.")
    parser.add_argument("--luau", default="luau", help="Path to the official Luau CLI executable")
    args = parser.parse_args()
    executable = shutil.which(args.luau)
    if not executable:
        parser.error("Luau CLI not found. Install it or pass --luau /path/to/luau.")

    root = pathlib.Path(__file__).resolve().parent.parent
    mock = (root / "tests/roblox_mock.lua").read_text(encoding="utf-8")
    module = (root / "modules/ui/acrylic.lua").read_text(encoding="utf-8")
    module_scope = mock + "\nlocal Acrylic = (function()\n" + module + "\nend)()\n"
    evolia = (root / "evolia.lua").read_text(encoding="utf-8")
    controls = (root / "modules/ui/controls.lua").read_text(encoding="utf-8")
    radial = (root / "modules/ui/radial.lua").read_text(encoding="utf-8")
    loader_mock = '''
local environment = {}
local requests = 0
local function getgenv() return environment end
local loadEvolia
function game:HttpGet(url)
    assert(url == "https://raw.githubusercontent.com/T1REI/Evolia/main/evolia.lua"
        or url:match("^https://raw%.githubusercontent%.com/T1REI/Evolia/main/modules/ui/"))
    requests += 1
    return url:match("([^/]+)%.lua$")
end
local function loadstring(source)
    if source == "evolia" then return loadEvolia end
    local modules = { acrylic = Acrylic, controls = Controls, radial = Radial }
    assert(modules[source])
    return function() return modules[source] end
end
loadEvolia = function()
'''
    ui_scope = module_scope + "\nlocal Controls = (function()\n" + controls + "\nend)()\n" \
        + "local Radial = (function()\n" + radial + "\nend)()\n" + loader_mock + evolia + "\nend\n"
    sources = {
        "acrylic": module_scope + (root / "tests/acrylic.spec.lua").read_text(encoding="utf-8"),
        "evolia": ui_scope + (root / "tests/evolia.spec.lua").read_text(encoding="utf-8"),
        "example": ui_scope + (root / "examples/evolia.lua").read_text(encoding="utf-8")
        + "\n" + (root / "tests/example.spec.lua").read_text(encoding="utf-8"),
    }
    with tempfile.TemporaryDirectory(prefix="evolia-tests-") as directory:
        for name, source in sources.items():
            path = pathlib.Path(directory) / f"{name}-tests.luau"
            path.write_text(source, encoding="utf-8")
            result = subprocess.run([executable, str(path)], check=False)
            if result.returncode:
                return result.returncode
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
