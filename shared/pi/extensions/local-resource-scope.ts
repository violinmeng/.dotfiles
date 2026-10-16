import { realpathSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, isAbsolute, relative, resolve, sep } from "node:path";
import type { BuildSystemPromptOptions, ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const COMMAND_NAME = "local-scope";
const STATE_ENTRY_TYPE = "local-resource-scope-state";
const STATUS_KEY = "local-resource-scope";

type Skill = NonNullable<BuildSystemPromptOptions["skills"]>[number];
type ContextFile = NonNullable<BuildSystemPromptOptions["contextFiles"]>[number];

function canonicalize(path: string): string {
  try {
    return realpathSync(path);
  } catch {
    return resolve(path);
  }
}

function globalContextDirectories(): Set<string> {
  return new Set([
    canonicalize(process.env.PI_CODING_AGENT_DIR ?? resolve(homedir(), ".pi", "agent")),
    // Pi discovers ~/AGENTS.md while walking cwd ancestors. Treat the home-level
    // context as global rather than as repository or workspace context.
    canonicalize(homedir()),
  ]);
}

function isWithin(path: string, root: string): boolean {
  const childPath = canonicalize(path);
  const rootPath = canonicalize(root);
  const relativePath = relative(rootPath, childPath);

  return relativePath === "" || (!isAbsolute(relativePath) && relativePath !== ".." && !relativePath.startsWith(`..${sep}`));
}

export function isCurrentDirectorySkill(skillPath: string, cwd: string): boolean {
  return [resolve(cwd, ".agents", "skills"), resolve(cwd, ".pi", "skills")].some((root) => isWithin(skillPath, root));
}

function isAllowedSkill(skill: Skill, cwd: string): boolean {
  return skill.sourceInfo.scope === "user" || isCurrentDirectorySkill(skill.filePath, cwd);
}

function isAllowedContext(filePath: string, cwd: string): boolean {
  const directory = canonicalize(dirname(filePath));
  return directory === canonicalize(cwd) || globalContextDirectories().has(directory);
}

function formatProjectContext(contextFiles: ContextFile[]): string {
  if (contextFiles.length === 0) {
    return "";
  }

  let section = "\n\n<project_context>\n\n";
  section += "Project-specific instructions and guidelines:\n\n";
  for (const { path, content } of contextFiles) {
    section += `<project_instructions path="${path}">\n${content}\n</project_instructions>\n\n`;
  }
  section += "</project_context>\n";
  return section;
}

function escapeXml(value: string): string {
  return value.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;").replace(/'/g, "&apos;");
}

function formatSkills(skills: Skill[]): string {
  const visibleSkills = skills.filter((skill) => !skill.disableModelInvocation);
  if (visibleSkills.length === 0) {
    return "";
  }

  const lines = [
    "\n\nThe following skills provide specialized instructions for specific tasks.",
    "Use the read tool to load a skill's file when the task matches its description.",
    "When a skill file references a relative path, resolve it against the skill directory (parent of SKILL.md / dirname of the path) and use that absolute path in tool commands.",
    "",
    "<available_skills>",
  ];

  for (const skill of visibleSkills) {
    lines.push("  <skill>");
    lines.push(`    <name>${escapeXml(skill.name)}</name>`);
    lines.push(`    <description>${escapeXml(skill.description)}</description>`);
    lines.push(`    <location>${escapeXml(skill.filePath)}</location>`);
    lines.push("  </skill>");
  }
  lines.push("</available_skills>");
  return lines.join("\n");
}

function replaceExact(source: string, value: string): string {
  return value ? source.replace(value, "") : source;
}

export function scopeSystemPrompt(systemPrompt: string, options: BuildSystemPromptOptions): string {
  const allContextFiles = options.contextFiles ?? [];
  const allSkills = options.skills ?? [];
  const canReadSkills = options.selectedTools === undefined || options.selectedTools.includes("read");

  let scopedPrompt = replaceExact(systemPrompt, formatProjectContext(allContextFiles));
  if (canReadSkills) {
    scopedPrompt = replaceExact(scopedPrompt, formatSkills(allSkills));
  }

  const allowedContextFiles = allContextFiles.filter((file) => isAllowedContext(file.path, options.cwd));
  const allowedSkills = canReadSkills ? allSkills.filter((skill) => isAllowedSkill(skill, options.cwd)) : [];
  const allowedSections = `${formatProjectContext(allowedContextFiles)}${formatSkills(allowedSkills)}`;

  const cwdMarker = `\nCurrent working directory: ${options.cwd.replace(/\\/g, "/")}`;
  const markerIndex = scopedPrompt.lastIndexOf(cwdMarker);
  if (markerIndex === -1) {
    return `${scopedPrompt}${allowedSections}`;
  }

  return `${scopedPrompt.slice(0, markerIndex)}${allowedSections}${scopedPrompt.slice(markerIndex)}`;
}

function restoreEnabledState(ctx: ExtensionContext): boolean {
  let enabled = true;
  for (const entry of ctx.sessionManager.getBranch()) {
    if (entry.type === "custom" && entry.customType === STATE_ENTRY_TYPE && typeof (entry.data as { enabled?: unknown } | undefined)?.enabled === "boolean") {
      enabled = (entry.data as { enabled: boolean }).enabled;
    }
  }
  return enabled;
}

function updateStatus(ctx: ExtensionContext, enabled: boolean): void {
  ctx.ui.setStatus(STATUS_KEY, enabled ? "scope: current + global" : undefined);
}

export default function localResourceScopeExtension(pi: ExtensionAPI) {
  let enabled = true;

  const restoreState = (ctx: ExtensionContext) => {
    enabled = restoreEnabledState(ctx);
    updateStatus(ctx, enabled);
  };

  pi.on("session_start", (_event, ctx) => {
    restoreState(ctx);
  });

  pi.on("session_tree", (_event, ctx) => {
    restoreState(ctx);
  });

  pi.on("before_agent_start", (event) => {
    if (!enabled) {
      return undefined;
    }

    return {
      systemPrompt: scopeSystemPrompt(event.systemPrompt, event.systemPromptOptions),
    };
  });

  pi.on("input", (event, ctx) => {
    if (!enabled) {
      return { action: "continue" };
    }

    const commandName = event.text.trim().split(/\s+/, 1)[0]?.slice(1);
    if (!commandName?.startsWith("skill:")) {
      return { action: "continue" };
    }

    const skillCommand = pi.getCommands().find((command) => command.source === "skill" && command.name === commandName);
    if (!skillCommand || skillCommand.sourceInfo.scope === "user" || isCurrentDirectorySkill(skillCommand.sourceInfo.path, ctx.cwd)) {
      return { action: "continue" };
    }

    ctx.ui.notify(`Blocked /${commandName}: the skill is outside the current and global configuration`, "warning");
    return { action: "handled" };
  });

  pi.registerCommand(COMMAND_NAME, {
    description: "Limit skills and project instructions to current and global configuration (on|off|status|toggle)",
    getArgumentCompletions: (prefix) => {
      const values = ["on", "off", "status", "toggle"].filter((value) => value.startsWith(prefix.trim().toLowerCase()));
      return values.length > 0 ? values.map((value) => ({ value, label: value })) : null;
    },
    handler: async (args, ctx) => {
      const action = args.trim().toLowerCase() || "status";
      let nextEnabled = enabled;

      switch (action) {
        case "on":
          nextEnabled = true;
          break;
        case "off":
          nextEnabled = false;
          break;
        case "toggle":
          nextEnabled = !enabled;
          break;
        case "status":
          break;
        default:
          ctx.ui.notify(`Usage: /${COMMAND_NAME} [on|off|status|toggle]`, "warning");
          return;
      }

      if (nextEnabled !== enabled) {
        enabled = nextEnabled;
        pi.appendEntry(STATE_ENTRY_TYPE, { enabled });
        updateStatus(ctx, enabled);
      }

      ctx.ui.notify(`Current-directory scope is ${enabled ? "enabled" : "disabled"}`, "info");
    },
  });
}
