import json, re, os
L = '/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/lead'
S = '/root/.claude/projects/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/workflows/scripts'
T = '/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/tasks'
REPO = '/home/user/crossing-europe---a-racing-xperience'
common = open(f'{L}/common.js').read()
oldR = open(f'{S}/v080-m1-renderer-wf_3b561c53-566.js').read()
oldC = open(f'{S}/v080-m1-inhalt-wf_bade9e46-06a.js').read()

def between(s, a, b):
    i = s.index(a) + len(a); j = s.index(b, i); return s[i:j]

def res(f):
    s = open(f'{T}/{f}').read(); return json.loads(s[s.find('{'):])['result']
rA = res('wwxy9w4zy.output'); rB = res('wp4m02xj0.output')
skel = rA['skel']; as1 = rB['models']['as1']
R1A = {'commit': skel['commit'], 'branch': skel['branch'], 'summary': skel['summary'],
       'open': [a for a in skel['acceptance'] if a['result'] != 'pass'], 'deviations': skel['deviations'],
       'contract_issues': skel['contract_issues'], 'notes': skel['notes_for_next']}
AS1J = {k: as1[k] for k in ['package', 'branch', 'commit', 'worktree', 'summary', 'acceptance', 'deviations',
                            'contract_issues', 'notes_for_next', 'quality_verdict', 'media']}
js = lambda o: json.dumps(o, ensure_ascii=False)

PACKAGES = 'const PACKAGES = [' + between(oldR, 'const PACKAGES = [', "\nphase('Bau')")
assert PACKAGES.rstrip().endswith(']'), PACKAGES[-200:]
SKEL_OLD = between(oldR, "const SKEL = `", "`\n\nconst PACKAGES")
assert SKEL_OLD.startswith('The skeleton R1a is your base')
SKEL = ('const SKEL = `The skeleton R1a is the base of every renderer package: commit ${R1A.commit} (branch ${R1A.branch}). '
        'What it delivers and leaves open:\n${JSON.stringify(R1A)}\n'
        + SKEL_OLD.split('\n', 2)[2]
        .replace('The other two renderer\npackages work in parallel from the same base and you will not see their files:',
                 'The other renderer\npackages work in parallel and you will not see their files:')
        + '\nAfter this push the lead\'s assembly step (RINT) merges R1, R2 and R3 and makes them work together.`')
assert 'The other renderer\npackages work in parallel' in SKEL, SKEL[:3000]
CONT = '''const CONT = {
  R1: { mode: 'continue', head: '@R1@', branch: 'worktree-wf_3b561c53-566-2', oldWt: `${REPO}/.claude/worktrees/wf_3b561c53-566-2` },
  R2: { mode: 'continue', head: '@R2@', branch: 'worktree-wf_3b561c53-566-3', oldWt: `${REPO}/.claude/worktrees/wf_3b561c53-566-3` },
  UI1: { mode: 'continue', head: '@UI1@', branch: 'worktree-wf_bade9e46-06a-3', oldWt: `${REPO}/.claude/worktrees/wf_bade9e46-06a-3` },
}'''
for k, v in {'@R1@': os.environ['H_R1'], '@R2@': os.environ['H_R2'], '@UI1@': os.environ['H_UI1']}.items():
    CONT = CONT.replace(k, v)
BASE = os.environ['H_BASE']

# ---------------- script 1: R1 + R2 continue ----------------
s1 = f'''export const meta = {{
  name: 'v080-m1b-renderer',
  description: 'v0.8.0 Modern, M1 after the usage-limit stop: road/environment (R1) and terrain/props (R2) continue from their committed intermediate states',
  phases: [{{ title: 'Bau', detail: 'R1 and R2 continue in fresh worktrees from the heads of their predecessors' }}],
}}
{common}
const R1A = {js(R1A)}
{SKEL}
{PACKAGES}
{CONT}

phase('Bau')
const built = (await parallel(['R1', 'R2'].map(id => () =>
  agent(`${{common(id, CONT[id], 'render')}}\\n${{SKEL}}\\nYOUR PACKAGE BRIEF (the same as your predecessor's):\\n${{PACKAGES.find(p => p.id === id).prompt}}\\nReturn the result format: every acceptance item of your package as its own entry with pass/fail and evidence.`,
    {{ label: `bau:${{id}}`, phase: 'Bau', schema: BUILD_R, isolation: 'worktree' }})))).filter(Boolean)
log(`Bau: ${{built.map(b => `${{b.package}} ${{b.commit ? b.commit.slice(0, 7) : '?'}} (${{b.acceptance.filter(a => a.result !== 'pass').length}} offen)`).join(', ')}}`)
return {{ built }}
'''
open(f'{L}/wf_m1b_renderer.js', 'w').write(s1)

# ---------------- script 2: R3 + AS1b fresh ----------------
AS1NOTE = '''const AS1NOTE = `UPDATE SINCE THE BRIEF WAS WRITTEN: the vehicle-model package AS1 is finished and is part of your base
(merge commit ${BASE} = R1a ${R1A.commit} + AS1 ${AS1.commit}). Models now exist for player/limousine and player/kompakt
(race level, show level, shadow caster) and for traffic/sedan, traffic/hatch, traffic/wagon and traffic/truck (lod0–lod2;
the truck as tractor and trailer node groups with pivots in the manifest). An independent art review and a rework of
these models (AS1R) run in parallel – they change meshes and the ce3d/cesprites files, not your files; a new manifest
must keep working without a code change. What AS1 reports for you (quality verdict, contract issues, notes):
${JSON.stringify({ summary: AS1.summary, quality: AS1.quality_verdict, contract_issues: AS1.contract_issues, notes: AS1.notes_for_next })}
Its pictures: ${AS1.media.slice(0, 6).join(' ; ')}`'''
AS1B_OLD = between(oldC, "const as1b = await agent(`${common('AS1b', head.commit, true)}\n", "`,\n    { label: 'modelle:AS1b'")
old_base = "Your base ${head.commit} is the vehicle package AS1 after its rework (branch\n${head.branch}); its notes for you: ${JSON.stringify(head.notes_for_next)}"
assert old_base in AS1B_OLD, AS1B_OLD[:600]
new_base = '''Your base ${BASE} is the renderer skeleton R1a merged with
the vehicle package AS1 (${AS1.commit}, branch ${AS1.branch}). First copy AS1's export cache (keyed by content, saves
Blender time): cp -a ${AS1.worktree}/tools/blender/_cache3d tools/blender/ . AS1's notes: ${JSON.stringify(AS1.notes_for_next)}
PARALLEL WORK ON THE SAME PIPELINE: the vehicle models get an art review and a rework at the same time (package AS1R,
branch wip/v080-as1r, same base). AS1R owns the vehicle files (tools/blender/ce3d/{vehicles3d, traffic3d, truck3d,
interior3d, extras3d}.py, the cesprites car files, assets/models/player/**, assets/models/traffic/**,
tools/models/contact_sheet.gd); you own assets/models/props/**, assets/models/landmarks/** if you touch them, and the
prop builders (ce3d/props3d.py, veg3d.py, leafatlas.py, bake.py). Shared pipeline files (ce3d core, decalgeo, lod,
catalog3d, roles, export, manifest, glb; export_models.py, validate_models.py, docs/modelle.md, the generated
assets/models/manifest.json): change them only additively and backwards-compatibly, keep your catalog entries in
their own block, and list every shared-file change in your report – the lead merges both packages and regenerates
manifest.json. The renderer package R2 (terrain, props builder with PropLibrary, sprite stand-ins, the billboard,
baked and leaves shaders) is still in progress on branch wip/v080-r2: for pictures of your models in the race you may
merge it into a throwaway branch in a second worktree under your scratch folder (never into your package branch);
otherwise show the models in your own scene.'''
AS1B = 'const AS1B = `' + AS1B_OLD.replace(old_base, new_base) + '`'
R3_EXTRA = ''
s2 = f'''export const meta = {{
  name: 'v080-m1b-r3-as1b',
  description: 'v0.8.0 Modern, M1: vehicles/flares/signs (R3) and environment models of the slice (AS1b), both from the merged base R1a + AS1',
  phases: [
    {{ title: 'Fahrzeuge', detail: 'R3 – vehicle and flare layers, paint and glass look, signs' }},
    {{ title: 'Umgebungsmodelle', detail: 'AS1b – trees, buildings and technical props of the slice' }},
  ],
}}
{common}
const R1A = {js(R1A)}
const AS1 = {js(AS1J)}
const BASE = '{BASE}'
{SKEL}
{PACKAGES}
{AS1NOTE}
{AS1B}

const [r3, as1b] = await parallel([
  () => agent(`${{common('R3', {{ mode: 'fresh', base: BASE }}, 'render')}}\\n${{SKEL}}\\n${{AS1NOTE}}\\nYOUR PACKAGE BRIEF:\\n${{PACKAGES.find(p => p.id === 'R3').prompt}}\\nReturn the result format: every acceptance item of your package as its own entry with pass/fail and evidence.`,
    {{ label: 'bau:R3', phase: 'Fahrzeuge', schema: BUILD_R, isolation: 'worktree' }}),
  () => agent(`${{common('AS1b', {{ mode: 'fresh', base: BASE }}, 'content')}}\\n${{AS1B}}`,
    {{ label: 'modelle:AS1b', phase: 'Umgebungsmodelle', schema: BUILD_C, isolation: 'worktree' }}),
])
if (r3) log(`R3: ${{r3.commit ? r3.commit.slice(0, 7) : '?'}} (${{r3.acceptance.filter(a => a.result !== 'pass').length}} offen)`)
if (as1b) log(`AS1b: ${{as1b.commit ? as1b.commit.slice(0, 7) : '?'}} (${{as1b.acceptance.filter(a => a.result !== 'pass').length}} offen)`)
return {{ r3, as1b }}
'''
open(f'{L}/wf_m1b_r3_as1b.js', 'w').write(s2)

# ---------------- script 3: KRITIK -> AS1R ; UI1 continue ----------------
AS1_BRIEF = 'const AS1_BRIEF = `' + between(oldC, "const AS1 = `", "`\n\nconst pipelineLane") + '`'
REVIEW = 'const REVIEW = {' + between(oldC, 'const REVIEW = {', '\n}\n') + '\n}'
KR_OLD = between(oldC, "const review = await agent(`${common('AS1-KRITIK', as1.commit, false)}\n", "`,\n    { label: 'kritik:AS1'")
kr_a = 'You make no commits, so skip the safety-copy step.'
assert kr_a in KR_OLD
KR = KR_OLD.replace(kr_a, kr_a + ''' A predecessor of yours made that copy
(${SP}/m1/AS1-KRITIK/wt) and was stopped by the usage limit before it had reviewed anything – reuse the copy after a
quick diff -rq of tools/blender, assets/models and assets/shaders against the worktree.''')
RW_OLD = between(oldC, "as1fix = await agent(`${common('AS1', as1.commit, false)}\n", "`,\n      { label: 'nacharbeit:AS1'")
rw_a = '''YOUR ROLE: REWORK OF THE VEHICLE MODELS (package AS1, second pass). Work in the existing worktree ${as1.worktree}
(cd there; branch ${as1.branch}, head ${as1.commit}) and commit there; keep pushing the safety copy to
wip/v080-as1. The package brief was:'''
assert rw_a in RW_OLD, RW_OLD[:500]
rw_b = '''YOUR ROLE: REWORK OF THE VEHICLE MODELS (second pass of package AS1; package id AS1R). Your fresh worktree starts
from ${BASE} = the renderer skeleton R1a merged with the AS1 head ${as1.commit} (branch ${as1.branch}). The first pass's
worktree ${as1.worktree} is READ-ONLY for you – but first copy its export cache (keyed by content, saves Blender time):
cp -a ${as1.worktree}/tools/blender/_cache3d tools/blender/
PARALLEL WORK ON THE SAME PIPELINE: the package AS1b builds the environment models at the same time from the same base.
You own the vehicle files (tools/blender/ce3d/{vehicles3d, traffic3d, truck3d, interior3d, extras3d}.py, the cesprites
car files, assets/models/player/**, assets/models/traffic/**, tools/models/contact_sheet.gd); AS1b owns
assets/models/props/** and the prop builders (ce3d props3d, veg3d, leafatlas, bake). Shared pipeline files (ce3d core,
decalgeo, lod, catalog3d, roles, export, manifest, glb; export_models.py, validate_models.py, docs/modelle.md, the
generated assets/models/manifest.json): change them only additively and backwards-compatibly, keep your catalog entries
in their own block, and list every shared-file change in your report – the lead merges both packages and regenerates
manifest.json. The renderer package R3 builds the paint, glass and chrome shaders and the vehicle layer in parallel
(vpbr.gdshader, model_factory.gd, modern_materials.gd stay R3's – report what the cars need from them).
The package brief was:'''
RW = RW_OLD.replace(rw_a, rw_b).replace('${AS1}', '${AS1_BRIEF}').replace('${JSON.stringify(review)}', '${reviewText}')
rw_c = 'Return the result format with package "AS1" (the state after the rework)'
assert rw_c in RW
RW = RW.replace(rw_c, 'Return the result format with package "AS1R" (the state after the rework)')
assert '${AS1_BRIEF}' in RW and '${reviewText}' in RW
UI_OLD = between(oldC, "const uiLane = () => agent(`${common('UI1', BASE, true)}\n", "`,\n  { label: 'oberfläche:UI1'")
UI_UPD = '''
UPDATE SINCE THE BRIEF WAS WRITTEN: the vehicle models AS1 (commit ${as1.commit}) and the engine sound AU-B (commit
${AUB_COMMIT}) are finished. Merge both into your branch early (git merge --no-edit ${as1.commit}, then
git merge --no-edit ${AUB_COMMIT}; the lead checked that both merge cleanly with your predecessor's head), so that you
can test Showroom3D with the real show level of player/limousine and player/kompakt (their showroom flag is still false
– force it in tests as the brief says) and the sound-profile switch with the real Modern engine. AU-B's notes for you:
EngineAudio3.preview(id) loads the bank on a worker task (22–75 ms) and blips once it is there; at most three banks stay
cached; frame.engine carries load (0..1). AS1's note for the showroom: the real-time paint is still flat (the paint
shader with clear coat comes from the renderer package R3 in parallel), so the showroom light rig has to carry the look;
check it with tools/models_contact_sheet.sh <png> --only="player/*" --showroom once your rig exists.'''
s3 = f'''export const meta = {{
  name: 'v080-m1b-content',
  description: 'v0.8.0 Modern, M1: independent art review of the vehicle models and their rework (AS1R); UI1 continues (options, chooser, showroom, Leistungstest)',
  phases: [
    {{ title: 'Sichtprüfung', detail: 'art review of the vehicle models, then their rework AS1R' }},
    {{ title: 'Oberfläche', detail: 'UI1 continues from its predecessor\\'s head' }},
  ],
}}
{common}
const as1 = {js(AS1J)}
const BASE = '{BASE}'
const AUB_COMMIT = '{os.environ['H_AUB']}'
{CONT}
{AS1_BRIEF}
{REVIEW}

const modelLane = async () => {{
  const review = await agent(`${{common('AS1-KRITIK', {{ mode: 'readonly' }}, 'content')}}
{KR}`,
    {{ label: 'kritik:AS1', phase: 'Sichtprüfung', schema: REVIEW }})
  if (review) {{
    const high = review.models.flatMap(m => m.defects.filter(d => d.severity !== 'low').map(d => `${{m.model}}: ${{d.problem}}`))
    log(`Sichtprüfung AS1: ${{review.models.map(m => `${{m.model}} ${{m.versus_sprite}}`).join(', ')}}; ${{high.length}} Mängel hoch/mittel`)
  }} else log('Sichtprüfung AS1 ausgefallen – die Nacharbeit prüft selbst')
  const reviewText = review ? JSON.stringify(review) : 'NOT AVAILABLE – the reviewer failed. Make your own strict review first (chase camera 8/30 m day and night, close-ups, every LOD level at its distance, lamp channels, comparison with the Cycles sprites) and fix what you find.'
  const as1fix = await agent(`${{common('AS1R', {{ mode: 'fresh', base: BASE }}, 'content')}}
{RW}`,
    {{ label: 'nacharbeit:AS1R', phase: 'Sichtprüfung', schema: BUILD_C, isolation: 'worktree' }})
  if (as1fix) log(`AS1R: ${{as1fix.commit ? as1fix.commit.slice(0, 7) : '?'}} (${{as1fix.acceptance.filter(a => a.result !== 'pass').length}} offen)`)
  return {{ review, as1fix }}
}}

const uiLane = () => agent(`${{common('UI1', CONT.UI1, 'content')}}\\nYOUR PACKAGE BRIEF (the same as your predecessor's):\\n{UI_OLD}\\n{UI_UPD}`,
  {{ label: 'oberfläche:UI1', phase: 'Oberfläche', schema: BUILD_C, isolation: 'worktree' }})

const [models, ui1] = await parallel([modelLane, uiLane])
return {{ models, ui1 }}
'''
open(f'{L}/wf_m1b_content.js', 'w').write(s3)
for f in ['wf_m1b_renderer.js', 'wf_m1b_r3_as1b.js', 'wf_m1b_content.js']:
    print(f, len(open(f'{L}/{f}').read()))
