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
assert.deepEqual(result.map(strip), fixture.map(strip), "Layout and text must not change");
assert.equal(result[0], fixture[0]);
assert.equal(result.at(-1), fixture.at(-1));
const colors = result.slice(2, 8).map(line => [...line.matchAll(/(\x1b\[38;2;[\d;]+m)█/g)].map(match => match[1]));
assert.deepEqual(colors, [
  Array(10).fill(coral),
  [...Array(4).fill(blue), ...Array(4).fill(coral)],
  [...Array(4).fill(blue), ...Array(4).fill(coral)],
  [...Array(8).fill(blue), ...Array(4).fill(yellow)],
  [...Array(4).fill(blue), ...Array(4).fill(yellow)],
  [...Array(4).fill(blue), ...Array(4).fill(yellow)],
]);
assert.deepEqual(colorizeWelcomeLogo(result), result, "Repainting must be idempotent");
assert.deepEqual(colorizeWelcomeLogo([]), []);
assert.deepEqual(colorizeWelcomeLogo(["ordinary dialog", fixture[2]]), ["ordinary dialog", fixture[2]]);
assert.deepEqual(colorizeWelcomeLogo(fixture.slice(0, 7)), fixture.slice(0, 7), "Partial logos stay untouched");
console.log("PASS: official Pi colors, unchanged layout, idempotence, unrelated and partial UI");
