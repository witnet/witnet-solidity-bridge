const exec = require("node:child_process").execSync;
const os = require("node:os");
const fs = require("node:fs");

if (fs.existsSync("./artifacts")) {
	if (os.type() === "Windows_NT") {
		exec("del /s /q artifacts\\*.dbg.json");
	} else {
		exec('find ./artifacts -name "*.dbg.json" -exec rm -r {} \\;');
	}
}

if (fs.existsSync("./build") && fs.existsSync("./build/contracts")) {
	exec('sed -i -- /\\bsourcePath\\b/d ./build/contracts/*.json');
}

if (fs.existsSync("./migrations/frosts")) {
	exec('sed -i -- /\\bsourcePath\\b/d ./migrations/frosts/*.json');
}

if (fs.existsSync("./migrations/frosts/apps")) {
	exec('sed -i -- /\\bsourcePath\\b/d ./migrations/frosts/apps/*.json', { shell: true });
}

if (fs.existsSync("./migrations/frosts/core")) {
	exec('sed -i -- /\\bsourcePath\\b/d ./migrations/frosts/core/*.json');
}
