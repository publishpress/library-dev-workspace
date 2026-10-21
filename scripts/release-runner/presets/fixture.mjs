/** @type {import('./types.mjs').StepDefinition[]} */
export const fixturePreset = [
  {
    id: 'auto_ok',
    label: 'Fixture auto step',
    phase: 'Fixture',
    type: 'auto',
    run: async () => {},
  },
  {
    id: 'auto_next',
    label: 'Fixture second auto',
    phase: 'Fixture',
    type: 'auto',
    run: async () => {},
  },
  {
    id: 'manual_gate',
    label: 'Fixture manual gate',
    phase: 'Fixture',
    type: 'manual',
    instructions: 'Complete this manual step in tests.',
  },
  {
    id: 'confirm_gate',
    label: 'Fixture confirm gate',
    phase: 'Fixture',
    type: 'confirm',
    message: 'Confirm to proceed.',
  },
  {
    id: 'auto_final',
    label: 'Fixture final auto',
    phase: 'Fixture',
    type: 'auto',
    run: async () => {},
  },
  {
    id: 'localize_auto',
    label: 'Fixture localization',
    phase: 'Localization',
    type: 'auto',
    run: async () => {},
  },
  {
    id: 'localize_confirm',
    label: 'Fixture localization confirm',
    phase: 'Localization',
    type: 'confirm',
    message: 'Confirm translations.',
  },
  {
    id: 'after_localize',
    label: 'Fixture after localization',
    phase: 'Fixture',
    type: 'auto',
    run: async () => {},
  },
];
