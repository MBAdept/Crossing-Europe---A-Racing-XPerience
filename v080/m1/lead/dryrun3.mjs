import fs from 'fs'
const file = process.argv[2]
let src = fs.readFileSync(file, 'utf8').replace('export const meta', 'const meta')
const prompts = []
const agent = async (p, o) => { prompts.push({ label: o.label, opts: o, p }); const s = o.schema && o.schema.properties || {}; if (s.models) return { overall: 'x', models: [{ model: 'player/kombi', versus_sprite: 'equal', showroom_ready: false, defects: [{ severity: 'high', where: 'w', problem: 'p', evidence: 'e', fix: 'f' }] }], pipeline_issues: [], media: [] }; if (s.findings) return { verdict: 'v', findings: [], checked_ok: [], media: [] }; return { package: o.label, branch: 'br-' + o.label, commit: 'c0ffee' + o.label.length + '0000000000000000000000000000000', worktree: '/wt/' + o.label, summary: 's', files_changed: [], acceptance: [{ check: 'c', result: 'partial', evidence: 'e' }], tests_total: 1, tests_failed: 0, deviations: [], contract_issues: [], notes_for_next: [], quality_verdict: 'q', look_verdict: 'l', media: [] } }
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
console.log('return:', JSON.stringify(r))
