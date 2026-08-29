#!/usr/bin/env node

import { existsSync, readFileSync, realpathSync } from "node:fs";
import { homedir } from "node:os";
import { delimiter, dirname, join } from "node:path";
import { pathToFileURL } from "node:url";

function findPiEntrypoint() {
	for (const directory of (process.env.PATH ?? "").split(delimiter)) {
		if (!directory) continue;
		const candidate = join(directory, "pi");
		if (existsSync(candidate)) return realpathSync(candidate);
	}
	throw new Error("Could not find pi on PATH");
}

function findPiPackageRoot(entrypoint) {
	let directory = dirname(entrypoint);
	while (true) {
		const manifestPath = join(directory, "package.json");
		if (existsSync(manifestPath)) {
			const manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
			if (manifest.name === "@earendil-works/pi-coding-agent") return directory;
		}
		const parent = dirname(directory);
		if (parent === directory) break;
		directory = parent;
	}
	throw new Error(`Could not find the Pi package root from ${entrypoint}`);
}

const configuredAgentDir = process.env.PI_CODING_AGENT_DIR ?? join(homedir(), ".pi", "agent");
const agentDir = realpathSync(configuredAgentDir);
const settings = JSON.parse(readFileSync(join(agentDir, "settings.json"), "utf8"));
const managedNpmDir = join(agentDir, "npm");
const managedManifest = JSON.parse(readFileSync(join(managedNpmDir, "package.json"), "utf8"));
const managedLock = JSON.parse(readFileSync(join(managedNpmDir, "package-lock.json"), "utf8"));
const hiddenLockPath = join(managedNpmDir, "node_modules", ".package-lock.json");
const hiddenLock = existsSync(hiddenLockPath) ? JSON.parse(readFileSync(hiddenLockPath, "utf8")) : undefined;
const packageRoot = findPiPackageRoot(findPiEntrypoint());
const [{ DefaultPackageManager }, { SettingsManager }] = await Promise.all([
	import(pathToFileURL(join(packageRoot, "dist/core/package-manager.js")).href),
	import(pathToFileURL(join(packageRoot, "dist/core/settings-manager.js")).href),
]);

const settingsManager = SettingsManager.inMemory(settings, { projectTrusted: false });
const packageManager = new DefaultPackageManager({
	cwd: process.cwd(),
	agentDir,
	settingsManager,
});
const startupInstalls = [];
const stateErrors = [];

const nonExactDependencies = Object.entries(managedManifest.dependencies ?? {})
	.filter(([, version]) => typeof version !== "string" || !/^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$/.test(version));
if (nonExactDependencies.length > 0) {
	stateErrors.push(`managed manifest has non-exact dependencies: ${nonExactDependencies.map(([name]) => name).join(", ")}`);
}

const invalidLockEntries = Object.entries(managedLock.packages ?? {})
	.filter(([path, metadata]) => path !== "" && metadata?.link !== true &&
		(typeof metadata?.version !== "string" || metadata.version.trim() === ""));
if (invalidLockEntries.length > 0) {
	const examples = invalidLockEntries.slice(0, 3).map(([path]) => path).join(", ");
	stateErrors.push(`managed lock has ${invalidLockEntries.length} package entries without versions: ${examples}`);
}

const recursiveLockEntries = Object.keys(managedLock.packages ?? {})
	.filter(path => path.includes(".dotfiles/pi/.dotfiles/pi"));
if (recursiveLockEntries.length > 0) {
	stateErrors.push(`managed lock has ${recursiveLockEntries.length} recursive Stow paths`);
}

for (const [name, expectedVersion] of Object.entries(managedManifest.dependencies ?? {})) {
	const lockKey = `node_modules/${name}`;
	const installedManifestPath = join(managedNpmDir, "node_modules", name, "package.json");
	const installedVersion = existsSync(installedManifestPath)
		? JSON.parse(readFileSync(installedManifestPath, "utf8")).version
		: undefined;
	const lockVersion = managedLock.packages?.[lockKey]?.version;
	const hiddenLockVersion = hiddenLock?.packages?.[lockKey]?.version;
	if (installedVersion !== expectedVersion || lockVersion !== expectedVersion || hiddenLockVersion !== expectedVersion) {
		stateErrors.push(
			`${name} version mismatch: manifest=${expectedVersion}, lock=${lockVersion ?? "missing"}, ` +
			`hidden-lock=${hiddenLockVersion ?? "missing"}, installed=${installedVersion ?? "missing"}`,
		);
	}
}

packageManager.installNpm = async source => {
	startupInstalls.push(`npm:${source.spec}`);
};
packageManager.installGit = async source => {
	startupInstalls.push(`git:${source.host}/${source.path}`);
};

await packageManager.resolve();

if (stateErrors.length > 0) {
	console.error("Pi's managed npm state is invalid:");
	for (const error of stateErrors) console.error(`- ${error}`);
	process.exitCode = 1;
} else if (startupInstalls.length > 0) {
	console.error("Pi would install these packages during startup:");
	for (const source of startupInstalls) console.error(`- ${source}`);
	process.exitCode = 1;
} else {
	console.log("startup-installs=0");
}
