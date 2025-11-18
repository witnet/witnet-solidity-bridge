#!/usr/bin/env node
const exec = require("node:child_process").execSync;
const fs = require("node:fs");
if (!fs.existsSync(".no-postinstall") && !fs.existsSync(`${process.env.INIT_CWD}/.env_witnet`)) {
	console.info(`Copying .env_witnet file from ${process.env.INIT_CWD}...`);
	fs.cpSync(".env_witnet", `${process.env.INIT_CWD}/.env_witnet`);
}

if (fs.existsSync("./build/contracts")) {
	exec('sed -i -- \"/\bsourcePath\b/d\" ./build/contracts/*.json');
}

