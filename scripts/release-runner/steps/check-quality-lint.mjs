export default {
  id: 'check_quality_lint',
  label: 'Code quality: lint',
  phase: 'Code Quality',
  type: 'auto',
  instructions: 'Runs ESLint on JavaScript sources for style and common issues.',
  command: 'composer lint:js',
  run: async (ctx) => {
    await ctx.exec('composer lint:js');
  },
};
