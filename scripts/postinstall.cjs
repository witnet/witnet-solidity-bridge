#!/usr/bin/env node
const fs = require("fs")
if (!fs.existsSync(".no-postinstall") && !fs.existsSync(`${process.env.INIT_CWD}/.env_witnet`)) {
  console.info(`Copying .env_witnet file from ${process.env.INIT_CWD}...`)
  fs.cpSync(".env_witnet", `${process.env.INIT_CWD}/.env_witnet`)
}
