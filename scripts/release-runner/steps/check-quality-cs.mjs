export default {
  id: 'check_quality_cs',
  label: 'Code quality: coding standards',
  phase: 'Code Quality',
  type: 'auto',
  instructions: 'Runs PHPCS to verify PHP matches project coding standards.',
  command: 'composer lint:phpcs',
  run: async (ctx) => {
    await ctx.exec('composer lint:phpcs');
  },
};
