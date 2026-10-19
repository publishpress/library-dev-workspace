import { existsSync, readFileSync } from 'fs';
import { join } from 'path';

/** Placeholder id in presets. Replaced by one auto step per suite when configured. */
export const MANUAL_TESTING_STEP_ID = 'testing';

const SUITE_NAME = /^[A-Za-z0-9][A-Za-z0-9_-]*$/;

/**
 * @param {string} cwd
 * @returns {object | null}
 */
function readRootComposer(cwd) {
  const filePath = join(cwd, 'composer.json');
  if (!existsSync(filePath)) {
    return null;
  }
  try {
    return JSON.parse(readFileSync(filePath, 'utf8'));
  } catch {
    return null;
  }
}

/**
 * Suite names from `composer.json` → `extra.test-suites`.
 * Missing or empty means the release shows a single manual testing step.
 *
 * @param {string | undefined} cwd
 * @returns {string[]}
 */
export function readTestSuites(cwd) {
  if (!cwd) {
    return [];
  }
  const composer = readRootComposer(cwd);
  if (!composer) {
    return [];
  }
  const extra = composer.extra && typeof composer.extra === 'object' ? composer.extra : {};
  const raw = extra['test-suites'];
  if (raw === undefined || raw === null) {
    return [];
  }
  if (!Array.isArray(raw)) {
    throw new Error('composer.json extra.test-suites must be an array of suite names');
  }
  /** @type {string[]} */
  const suites = [];
  const seen = new Set();
  for (const entry of raw) {
    if (typeof entry !== 'string' || !SUITE_NAME.test(entry)) {
      throw new Error(
        `composer.json extra.test-suites entries must be suite names like "unit" (got ${JSON.stringify(entry)})`
      );
    }
    const id = suiteStepId(entry);
    if (seen.has(id)) {
      throw new Error(`composer.json extra.test-suites has duplicate suite "${entry}"`);
    }
    seen.add(id);
    suites.push(entry);
  }
  return suites;
}

/**
 * @param {string} suite
 */
export function suiteStepId(suite) {
  return `test_${suite.toLowerCase().replace(/-/g, '_')}`;
}

/**
 * @param {string} suite
 */
function suiteLabel(suite) {
  const words = suite.replace(/[-_]/g, ' ');
  return `${words.charAt(0).toUpperCase()}${words.slice(1)} tests`;
}

/**
 * @param {string} suite
 * @returns {import('../presets/types.mjs').StepDefinition}
 */
export function suiteStep(suite) {
  const command = `composer test:${suite}`;
  return {
    id: suiteStepId(suite),
    label: suiteLabel(suite),
    phase: 'Testing',
    type: 'auto',
    command,
    instructions: `Runs the ${suite} suite.`,
    run: async (ctx) => {
      await ctx.exec(command);
    },
  };
}

/** Shown when `extra.test-suites` is missing or empty. */
export const manualTestingStep = {
  id: MANUAL_TESTING_STEP_ID,
  label: 'Testing',
  phase: 'Testing',
  type: 'manual',
  instructions:
    'Run the project tests, then continue.\n\n' +
    'composer.json has no extra.test-suites, so this step stays manual.\n' +
    'List suite names there to run them as composer test:<name> (for example "unit" → composer test:unit).',
};

/**
 * Swap the manual testing placeholder for auto suite steps when configured.
 * Returns the same array when nothing changes.
 *
 * @param {import('../presets/types.mjs').StepDefinition[]} pipeline
 * @param {string | undefined} cwd
 */
export function expandTestingSteps(pipeline, cwd) {
  const suites = readTestSuites(cwd);
  if (suites.length === 0) {
    return pipeline;
  }
  const steps = suites.map(suiteStep);
  let replaced = false;
  /** @type {import('../presets/types.mjs').StepDefinition[]} */
  const out = [];
  for (const step of pipeline) {
    if (step.id === MANUAL_TESTING_STEP_ID) {
      out.push(...steps);
      replaced = true;
    } else {
      out.push(step);
    }
  }
  return replaced ? out : pipeline;
}
