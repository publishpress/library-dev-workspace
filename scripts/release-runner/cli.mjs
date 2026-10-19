import {
  archiveRelease,
  createReleaseRecord,
  deleteCurrentRelease,
  loadCurrentRelease,
  saveRelease,
  listReleaseIds,
  syncReleaseSteps,
  touchRelease,
} from './state/store.mjs';
import {
  buildStatusPayload,
  cascadeReopen,
  getCurrentStepId,
  runEngine,
} from './engine/engine.mjs';
import { loadUiPrefs } from './state/ui-prefs.mjs';
import {
  getPresetMeta,
  resolvePipeline,
  validateVersionForPreset,
} from './presets/index.mjs';
import { resolveStartPreset } from './detect-edition.mjs';
import { maxPrereleaseNumber } from './state/store.mjs';

/**
 * @param {string[]} argv
 */
function parseGlobalFlags(argv) {
  const flags = { json: false, yes: false };
  const rest = [];
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--json') {
      flags.json = true;
    } else if (arg === '--yes') {
      flags.yes = true;
    } else {
      rest.push(arg);
    }
  }
  return { flags, rest };
}

/**
 * @param {object} payload
 * @param {boolean} json
 */
function output(payload, json) {
  if (json) {
    process.stdout.write(`${JSON.stringify(payload)}\n`);
  } else if (payload.message) {
    process.stderr.write(`${payload.message}\n`);
  }
}

/**
 * @param {{ exitCode: number, blocked?: string, error?: string, release: object }} result
 */
function formatRunPayload(result) {
  return {
    ok: result.exitCode !== 1,
    exitCode: result.exitCode,
    ...(result.blocked ? { blocked: result.blocked } : {}),
    ...(result.error ? { error: result.error } : {}),
    release: result.release,
  };
}

/**
 * @param {{ exitCode: number }} result
 */
function exitFromRunResult(result) {
  return result.exitCode === 1 ? 1 : 0;
}

/**
 * @param {string} cwd
 * @param {{ onLog?: (line: string) => void, until?: string, confirm?: string }} [options]
 */
async function continueRelease(cwd, options = {}) {
  const release = loadCurrentRelease(cwd);
  if (!release) {
    throw new Error('No in-progress release');
  }
  return runEngine(release, { cwd, ...options });
}

/**
 * UI with auto-run off leaves the next auto step pending until Run/Continue.
 *
 * @param {string} cwd
 * @param {{ autoRun?: boolean, onLog?: (line: string) => void }} flags
 */
async function continueIfAuto(cwd, flags) {
  if (flags.autoRun === false) {
    const release = loadCurrentRelease(cwd);
    return { exitCode: 0, release };
  }
  return continueRelease(cwd, { onLog: flags.onLog, beatMs: flags.beatMs });
}

/**
 * UI passes `autoRun` on the request. CLI falls back to the saved toggle (default on).
 *
 * @param {{ autoRun?: boolean }} flags
 * @param {string} cwd
 */
function resolveAutoRun(flags, cwd) {
  if (typeof flags.autoRun === 'boolean') {
    return flags.autoRun;
  }
  return loadUiPrefs(cwd).autoRun !== false;
}

/**
 * @param {string[]} rest
 * @param {string} cwd
 * @param {{ json: boolean }} flags
 */
async function cmdStart(rest, cwd, flags) {
  const version = rest[0];
  if (!version) {
    throw new Error(
      'Usage: start <version> [--preset <id>] [--edition <id>] [--urgency standard|security] [--prerelease-channel beta|rc]'
    );
  }
  let presetExplicit = false;
  /** @type {string | null} */
  let presetArg = null;
  let urgency = 'standard';
  /** @type {'beta'|'rc'|null} */
  let prereleaseChannel = null;
  for (let i = 1; i < rest.length; i += 1) {
    if ((rest[i] === '--preset' || rest[i] === '--edition') && rest[i + 1]) {
      presetArg = rest[i + 1];
      presetExplicit = true;
      i += 1;
    } else if (rest[i] === '--urgency' && rest[i + 1]) {
      urgency = rest[i + 1];
      i += 1;
    } else if (rest[i] === '--prerelease-channel' && rest[i + 1]) {
      prereleaseChannel = rest[i + 1];
      i += 1;
    } else if (rest[i] === '--channel' && rest[i + 1]) {
      throw new Error('Use --prerelease-channel instead of --channel');
    }
  }
  const edition = resolveStartPreset(cwd, presetExplicit ? presetArg : null);
  validateVersionForPreset(version, edition);
  const meta = getPresetMeta(edition);
  /** @type {{ channel: 'beta'|'rc', n: number } | null} */
  let prerelease = null;
  if (meta.versionRule === 'prerelease') {
    const channels = meta.channels || ['beta'];
    const channel = prereleaseChannel || channels[0];
    if (!channels.includes(channel)) {
      throw new Error(
        `Invalid --prerelease-channel "${channel}". Allowed for ${edition}: ${channels.join(', ')}`
      );
    }
    const n = maxPrereleaseNumber(cwd, version, channel) + 1;
    prerelease = { channel, n };
  } else if (prereleaseChannel) {
    throw new Error(`--prerelease-channel is not used with stable preset ${edition}`);
  }
  const existing = loadCurrentRelease(cwd);
  if (existing?.status === 'in_progress') {
    throw new Error(`Release v${existing.version} is already in progress`);
  }
  const steps = resolvePipeline(edition, cwd);
  const release = createReleaseRecord(version, edition, urgency, steps, prerelease);
  saveRelease(release, cwd);
  const result = await continueIfAuto(cwd, flags);
  output(
    {
      started: true,
      ...formatRunPayload(result),
      ...(presetExplicit ? {} : { presetResolved: edition }),
    },
    flags.json
  );
  return exitFromRunResult(result);
}

/**
 * @param {string} cwd
 * @param {{ json: boolean }} flags
 */
async function cmdResume(cwd, flags) {
  const release = loadCurrentRelease(cwd);
  if (!release) {
    throw new Error('No in-progress release. Run start first.');
  }
  output({ ok: true, release }, flags.json);
  return 0;
}

/**
 * @param {string[]} rest
 * @param {string} cwd
 * @param {{ json: boolean, yes: boolean }} flags
 */
async function cmdReset(rest, cwd, flags) {
  if (!flags.yes && rest[0] !== '--yes') {
    throw new Error('reset requires --yes');
  }
  deleteCurrentRelease(cwd);
  output({ ok: true, reset: true }, flags.json);
  return 0;
}

/**
 * @param {string[]} rest
 * @param {string} cwd
 * @param {{ json: boolean }} flags
 */
async function cmdNew(rest, cwd, flags) {
  const startArgs = rest;
  const current = loadCurrentRelease(cwd);
  if (current) {
    archiveRelease(current, cwd);
  }
  return cmdStart(startArgs, cwd, flags);
}

/**
 * @param {string} cwd
 * @param {{ json: boolean }} flags
 */
async function cmdList(cwd, flags) {
  output({ ok: true, releases: listReleaseIds(cwd) }, flags.json);
  return 0;
}

/**
 * @param {string} cwd
 * @param {{ json: boolean }} flags
 */
async function cmdStatus(cwd, flags) {
  const release = loadCurrentRelease(cwd);
  if (!release) {
    output({ ok: true, release: null }, flags.json);
    return 0;
  }
  const payload = buildStatusPayload(release, release.edition, cwd);
  output({ ok: true, ...payload }, flags.json);
  return 0;
}

/**
 * @param {string} stepId
 * @param {string} cwd
 * @param {string} [note]
 */
function markStep(release, stepId, status, note, cwd) {
  const { changed } = syncReleaseSteps(release, cwd);
  if (changed) {
    saveRelease(release, cwd);
  }
  if (!release.steps[stepId]) {
    throw new Error(`Unknown step: ${stepId}`);
  }
  release.steps[stepId] = {
    status,
    at: new Date().toISOString(),
    ...(note ? { note } : {}),
  };
  touchRelease(release);
  saveRelease(release, cwd);
}

/**
 * @param {string[]} rest
 * @param {string} cwd
 * @param {{ json: boolean }} flags
 */
async function cmdComplete(rest, cwd, flags) {
  const stepId = rest[0];
  let note;
  for (let i = 1; i < rest.length; i += 1) {
    if (rest[i] === '--note' && rest[i + 1]) {
      note = rest[i + 1];
      i += 1;
    }
  }
  const release = loadCurrentRelease(cwd);
  if (!release) {
    throw new Error('No in-progress release');
  }
  markStep(release, stepId, 'done', note, cwd);
  const result = await continueIfAuto(cwd, flags);
  output(formatRunPayload(result), flags.json);
  return exitFromRunResult(result);
}

/**
 * @param {string[]} rest
 * @param {string} cwd
 * @param {{ json: boolean }} flags
 */
async function cmdSkip(rest, cwd, flags) {
  const stepId = rest[0];
  if (resolveAutoRun(flags, cwd)) {
    throw new Error('Skip is only available when auto-run is off');
  }
  if (stepId === 'github_auth') {
    throw new Error('github_auth cannot be skipped');
  }
  let note;
  for (let i = 1; i < rest.length; i += 1) {
    if (rest[i] === '--note' && rest[i + 1]) {
      note = rest[i + 1];
      i += 1;
    }
  }
  const release = loadCurrentRelease(cwd);
  if (!release) {
    throw new Error('No in-progress release');
  }
  const pipeline = resolvePipeline(release.edition, cwd);
  const stepDef = pipeline.find((step) => step.id === stepId);
  if (!stepDef) {
    throw new Error(`Unknown step: ${stepId}`);
  }
  if (stepDef.type === 'confirm' || stepDef.publish === true) {
    throw new Error(`${stepId} cannot be skipped`);
  }
  if (stepDef.type !== 'auto' && stepDef.type !== 'manual') {
    throw new Error(`${stepId} cannot be skipped`);
  }
  const currentStepId = getCurrentStepId(release, release.edition, cwd);
  if (stepId !== currentStepId) {
    throw new Error('Only the current step can be skipped');
  }
  const status = release.steps[stepId]?.status;
  if (status === 'done' || status === 'skipped' || status === 'running') {
    throw new Error(`Cannot skip ${stepId} while it is ${status}`);
  }
  markStep(release, stepId, 'skipped', note, cwd);
  const saved = loadCurrentRelease(cwd);
  output({ ok: true, exitCode: 0, release: saved }, flags.json);
  return 0;
}

/**
 * @param {string[]} rest
 * @param {string} cwd
 * @param {{ json: boolean }} flags
 */
async function cmdReopen(rest, cwd, flags) {
  const stepId = rest[0];
  const release = loadCurrentRelease(cwd);
  if (!release) {
    throw new Error('No in-progress release');
  }
  cascadeReopen(release, stepId, release.edition, cwd);
  saveRelease(release, cwd);
  const saved = loadCurrentRelease(cwd);
  output({ ok: true, exitCode: 0, release: saved }, flags.json);
  return 0;
}

/**
 * Cascade from a finished step. Auto steps execute. Manual and confirm steps stay pending.
 * Auto-run on continues until the next gate. Auto-run off stops after that one auto step.
 *
 * @param {string[]} rest
 * @param {string} cwd
 * @param {{ json: boolean, autoRun?: boolean, onLog?: (line: string) => void, beatMs?: number }} flags
 */
async function cmdRerun(rest, cwd, flags) {
  const stepId = rest[0];
  const release = loadCurrentRelease(cwd);
  if (!release) {
    throw new Error('No in-progress release');
  }
  const pipeline = resolvePipeline(release.edition, cwd);
  const stepDef = pipeline.find((step) => step.id === stepId);
  if (!stepDef) {
    throw new Error(`Unknown step: ${stepId}`);
  }
  const status = release.steps[stepId]?.status;
  if (status !== 'done' && status !== 'failed' && status !== 'skipped') {
    throw new Error(`Step ${stepId} has not run yet`);
  }
  cascadeReopen(release, stepId, release.edition, cwd);
  saveRelease(release, cwd);
  if (stepDef.type === 'manual' || stepDef.type === 'confirm') {
    const result = await continueIfAuto(cwd, flags);
    output(formatRunPayload(result), flags.json);
    return exitFromRunResult(result);
  }
  const autoRun = resolveAutoRun(flags, cwd);
  const result = await continueRelease(cwd, {
    onLog: flags.onLog,
    stepwise: autoRun === false,
    beatMs: autoRun === false ? 0 : flags.beatMs,
  });
  output(formatRunPayload(result), flags.json);
  return result.exitCode;
}

/**
 * @param {string[]} rest
 * @param {string} cwd
 * @param {{ json: boolean }} flags
 */
async function cmdRun(rest, cwd, flags) {
  let until;
  let confirm;
  for (let i = 0; i < rest.length; i += 1) {
    if (rest[i] === '--until' && rest[i + 1]) {
      until = rest[i + 1];
      i += 1;
    } else if (rest[i] === '--confirm' && rest[i + 1]) {
      confirm = rest[i + 1];
      i += 1;
    }
  }
  const result = await continueRelease(cwd, {
    until,
    confirm,
    onLog: flags.onLog,
    stepwise: flags.autoRun === false && !until,
    beatMs: flags.beatMs,
  });
  output(formatRunPayload(result), flags.json);
  return result.exitCode;
}

/** @type {Record<string, (rest: string[], cwd: string, flags: { json: boolean, yes: boolean, onLog?: (line: string) => void }) => Promise<number>>} */
export const commands = {
  start: cmdStart,
  resume: (rest, cwd, flags) => cmdResume(cwd, flags),
  reset: cmdReset,
  new: cmdNew,
  list: (rest, cwd, flags) => cmdList(cwd, flags),
  status: (rest, cwd, flags) => cmdStatus(cwd, flags),
  complete: cmdComplete,
  skip: cmdSkip,
  reopen: cmdReopen,
  rerun: cmdRerun,
  run: cmdRun,
};

/**
 * @param {string[]} argv
 * @param {{ cwd?: string }} [options]
 */
export async function runCli(argv, options = {}) {
  const cwd = options.cwd || process.cwd();
  const { flags, rest } = parseGlobalFlags(argv);
  const sub = rest[0];
  if (!sub || sub === '--help' || sub === '-h') {
    process.stderr.write(
      [
        'Open the web UI:  composer release',
        '  Then open the URL printed in that terminal. Leave it running.',
        '',
        'CLI only:  composer release -- <start|resume|reset|new|list|status|complete|skip|reopen|rerun|run> [options]',
        '',
      ].join('\n')
    );
    return sub ? 0 : 1;
  }
  const handler = commands[sub];
  if (!handler) {
    throw new Error(`Unknown subcommand: ${sub}`);
  }
  try {
    return await handler(rest.slice(1), cwd, flags);
  } catch (err) {
    output({ ok: false, error: err.message }, flags.json);
    if (!flags.json) {
      process.stderr.write(`${err.message}\n`);
    }
    return 1;
  }
}
