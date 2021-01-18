"use strict";

const process = require("process");
const path = require("path");
const fs = require("fs");
const { EOL } = require("os");

const map = new Map([
  ["%", "%25"],
  ["\r", "%0D"],
  ["\n", "%0A"],
]);

const regex = /[%\r\n]/g;
const replacer = Map.prototype.get.bind(map);

const moduleName = "ubpm.cmake";

try {
  const destination = process.env.INPUT_DESTINATION || ".ubpm_root";
  const fromLocation = path.join(__dirname, moduleName);
  const locationParent = path.join(process.cwd(), destination);
  const location = path.join(locationParent, moduleName);
  fs.mkdirSync(locationParent, { recursive: true });
  fs.copyFileSync(fromLocation, location);

  const envFile = path.normalize(process.env.GITHUB_ENV);
  fs.appendFileSync(envFile, `UBPM_MODULE_PATH=${location}${EOL}`);

  const value = location.replace(regex, replacer);
  process.stdout.write(`::set-output name=location::${value}${EOL}`);
} catch (error) {
  process.exitCode = 1;
  process.stdout.write(`::error::${error.message}${EOL}`);
}
