import { pluginProStablePreset } from './plugin-pro-stable.mjs';
import { withoutSteps } from './without-steps.mjs';

/** Prerelease (beta/rc) pro pipeline — no milestone bookkeeping. */
export const pluginProUnstablePreset = withoutSteps(pluginProStablePreset, [
  'milestone_check',
  'milestone_close',
  'translate_ai',
  'translate_commit',
  'wait_translator_es_fr_it',
  'wait_translator_pt_br',
  'translate_download',
  'translate_compile',
  'changelog_i18n',
  'check_release',
]);
