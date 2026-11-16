const REVIEW = {
  type: 'object',
  properties: {
    overall: { type: 'string' },
    models: { type: 'array', items: { type: 'object', properties: {
      model: { type: 'string' },
      versus_sprite: { type: 'string', enum: ['finer', 'equal', 'cruder'] },
      showroom_ready: { type: 'boolean' },
      defects: { type: 'array', items: { type: 'object', properties: {
        severity: { type: 'string', enum: ['high', 'medium', 'low'] }, where: { type: 'string' }, problem: { type: 'string' }, evidence: { type: 'string' }, fix: { type: 'string' } },
        required: ['severity', 'where', 'problem', 'evidence', 'fix'] } } },
      required: ['model', 'versus_sprite', 'showroom_ready', 'defects'] } },
    pipeline_issues: { type: 'array', items: { type: 'string' } },
    media: { type: 'array', items: { type: 'string' } },
  },
  required: ['overall', 'models', 'pipeline_issues', 'media'],
}

