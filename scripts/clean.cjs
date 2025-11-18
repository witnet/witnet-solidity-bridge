const exec = require("node:child_process").execSync;
const os = require("node:os");
const fs = require("node:fs");

if (process.argv.length < 3) {
	console.log(`Usage: ${0} ${1} /path/to/be/cleaned`);
	process.exit(0);
}

process.argv.slice(2).forEach((target) => {
	if (fs.existsSync(target)) {
		if (os.type() === "Windows_NT") {
			target = target.replace(/\//g, "\\");
			exec(`del ${target}\\ /f /q /s`);
			exec(`rmdir ${target}\\ /q /s`);
		} else {
			target = target.replace(/\\/g, "/");
			exec(`rm -rf ${target}`);
		}
	}
});
