#!/usr/bin/env node
import assert from "node:assert/strict";
import { colorizeWelcomeLogo } from "../shared/pi/extensions/powerline-welcome.ts";

const rows = ["██████████    ", "████  ████    ", "████  ████    ",
  "████████  ████", "████      ████", "████      ████"];
const reset = "\x1b[0m";
const sgr = /\x1b\[[0-9;]*m/g;
const strip = text => text.replace(sgr, "");
const coral = "\x1b[38;2;228;138;122m";
const blue = "\x1b[38;2;79;142;179m";
const yellow = "\x1b[38;2;234;182;93m";
const fixture = ["header", "Welcome back!", ...rows.map(row =>
  "│      " + [...row].map(char => char === "█" ? "\x1b[38;5;199m█" + reset : char).join("") + "      │ Tips"), "footer"];
const result = colorizeWelcomeLogo(fixture);
assert.equal(result.length, fixture.length);
assert.equal(result[0], fixture[0]);
assert.equal(result[1], fixture[1]);
assert.equal(result.at(-1), fixture.at(-1));
for (const [index, line] of result.slice(2, 8).entries()) {
  assert.equal(strip(line).length, strip(fixture[index + 2]).length);
  assert.ok(line.startsWith("│      ") && line.endsWith("      │ Tips"));
}

// Decode terminal half blocks into square pixels, independently of the renderer.
function decode(lines) {
  const pixels = [];
  const colors = new Map([[coral, "C"], [blue, "B"], [yellow, "Y"]]);
  for (const line of lines) {
    let fg = ".", bg = ".";
    const top = [], bottom = [];
    for (const match of line.matchAll(/\x1b\[[0-9;]*m|[^\x1b]/gu)) {
      const token = match[0];
      if (token === reset) { fg = bg = "."; continue; }
      if (token.startsWith("\x1b[38;")) { fg = colors.get(token); continue; }
      if (token.startsWith("\x1b[48;")) {
        bg = colors.get(token.replace("[48;", "[38;")); continue;
      }
      top.push(token === "█" || token === "▀" ? fg : bg);
      bottom.push(token === "█" || token === "▄" ? fg : bg);
    }
    pixels.push(top.join(""), bottom.join(""));
  }
  return pixels;
}
const artwork = result.slice(2, 8).map(line => line.slice("│      ".length, -"      │ Tips".length));
const reference = ["CCC.", "B.C.", "BB.Y", "B..Y"];
assert.deepEqual(decode(artwork), reference.flatMap(row =>
  Array(3).fill("." + [...row].map(pixel => pixel.repeat(3)).join("") + ".")),
  "Every brand pixel, including empty space, must scale equally");
assert.deepEqual(colorizeWelcomeLogo(result), result, "Repainting must be idempotent");
assert.deepEqual(colorizeWelcomeLogo([]), []);
assert.deepEqual(colorizeWelcomeLogo(["ordinary dialog", fixture[2]]), ["ordinary dialog", fixture[2]]);
assert.deepEqual(colorizeWelcomeLogo(fixture.slice(0, 7)), fixture.slice(0, 7), "Partial logos stay untouched");
console.log("PASS: official Pi pixel proportions and colors, unchanged dialog layout, idempotence, unrelated and partial UI");
