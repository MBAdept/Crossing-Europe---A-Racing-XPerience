import fs from 'fs'
const file = process.argv[2]
let src = fs.readFileSync(file, 'utf8').replace('export const meta', 'const meta')
const prompts = []
const mode = process.env.DRY || 'high'
const agent = async (p, o) => { prompts.push({ label: o.label, opts: o, p }); const s = o.schema && o.schema.properties || {}
  if (s.reproduced) return { reproduced: 'yes', mechanisms: [{ id: 'M1', what: 'w', build: 'both', situation: 's', depth_m: '0.1', frequency: 'f', visible: 'v', likely_user_case: true }], method: 'm', arcade_same_moment: 'a', media: [], notes: [] }
  if (s.sizes) return { mechanisms: [{ id: 'M1', what: 'w', code: 'c', worst_case_m: '0.2', likelihood: 'high', why: 'y' }], sizes: [], fix_options: [], notes: [] }
  if (s.root_causes) return { root_causes: [{ id: 'M1', what: 'w', evidence: 'e', user_case: 'most likely' }], fix_design: 'd', fairness_argument: 'f', arcade_identity: 'a', tests: [], acceptance: [], risks: [] }
  if (s.refuted) return { refuted: false, problems: [{ severity: 'medium', problem: 'p', evidence: 'e', correction: 'c' }], confirmed: [] }
  if (s.per_finding) return { verdict: 'v', per_finding: [], findings: [], gates: [] }
  if (s.findings) return { verdict: 'v', findings: mode === 'high' ? [{ id: 'X1', severity: 'high', area: 'a', where: 'w', problem: 'p', evidence: 'e', repro: 'r', fix: 'f' }] : [], checked_ok: [], media: [] }
  return { package: o.label, branch: 'br-' + o.label, commit: 'c0ffee' + o.label.length + '0000000000000000000000000000000', worktree: '/wt/' + o.label, summary: 's', files_changed: [], acceptance: [{ check: 'c', result: 'partial', evidence: 'e' }], tests_total: 1, tests_failed: 0, deviations: [], contract_issues: [], notes_for_next: [], quality_verdict: 'q', look_verdict: 'l', media: [] } }
const parallel = async (ts) => Promise.all(ts.map(t => t()))
const phase = () => {}; const log = (m) => console.log('LOG', m)
const fn = new Function('agent', 'parallel', 'phase', 'log', 'args', `return (async () => {\n${src}\n})()`)
const A = process.argv[3] ? JSON.parse(fs.readFileSync(process.argv[3], 'utf8')) : undefined
const r = await fn(agent, parallel, phase, log, A)
for (const x of prompts) {
  const bad = (x.p.match(/\$\{|undefined|\[object Object\]|NaN/g) || [])
  console.log(`== ${x.label} len=${x.p.length} iso=${x.opts.isolation} schema=${!!x.opts.schema} suspicious=${JSON.stringify(bad)}`)
  fs.writeFileSync(file.replace('.js', `.${x.label.replace(/[^a-zA-Z0-9]/g, '_')}.txt`), x.p)
}
console.log('return keys:', Object.keys(r || {}).join(','))
