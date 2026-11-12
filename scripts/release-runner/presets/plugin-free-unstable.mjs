import { pluginFreeStablePreset } from './plugin-free-stable.mjs';
import { withoutSteps } from './without-steps.mjs';

/** Prerelease (beta/rc) free pipeline — no milestone or post-publish WP.org gates. */
export const pluginFreeUnstablePreset = withoutSteps(pluginFreeStablePreset, [
  'milestone_check',
  'milestone_close',
  'post_release',
  'check_wporg',
  'translate_ai',
  'translate_commit',
  'wait_translator_es_fr_it',
  'wait_translator_pt_br',
  'translate_download',
  'translate_compile',
  'changelog_i18n',
  'check_release',
]);
