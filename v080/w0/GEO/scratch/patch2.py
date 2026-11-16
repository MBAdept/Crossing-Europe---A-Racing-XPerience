root = '/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_92c01fa2-b2a-4/'
p = root + 'scripts/race3d/chunk_streamer.gd'
s = open(p).read()

a = '''	if not path.is_ready() or path.track != track or cam_seg < path.first or cam_seg > path.last():
		_restart(cam_z, cam_seg)
	path.ensure(cam_seg + int(landmark_path_m / seg_len))
	if path.last() < cam_seg:
		# the road between the old path and the camera is gone from the track window (a jump ahead)
		_restart(cam_z, cam_seg)
		path.ensure(cam_seg + int(landmark_path_m / seg_len))
'''
b = '''	if not path.is_ready() or path.track != track or cam_seg > path.last() \\
			or (cam_seg < path.first and track.get_segment(cam_seg).index == cam_seg):
		_restart(cam_z, cam_seg)
	path.ensure(cam_seg + int(landmark_path_m / seg_len))
	if path.last() < cam_seg:
		# the road between the old path and the camera is gone from the track window (a jump ahead)
		_restart(cam_z, cam_seg)
		path.ensure(cam_seg + int(landmark_path_m / seg_len))
	if cam_seg < path.first:
		# the camera is behind everything the track still holds: stream from the oldest road there is
		cam_seg = path.first
		cam_z = float(cam_seg) * seg_len
'''
assert a in s
s = s.replace(a, b)

a = '''	var at_once := sync or not _loaded
	# collect: everything at once at load / in sync mode, else one chunk per update
	for ci: int in _wanted:
		if _chunks.has(ci):
			continue
		if not _make_room(ci, cam_seg):
			break
		if _collect(ci, not at_once and threaded) and not at_once:
			break
'''
b = '''	var at_once := sync or not _loaded
	# collect: everything at once at load / in sync mode, else one chunk per update
	for ci: int in _wanted:
		if _chunks.has(ci):
			continue
		if not _make_room(ci, cam_seg):
			break
		if _collect(ci, threaded) and not at_once:
			break
'''
assert a in s
s = s.replace(a, b)
open(p, 'w').write(s)
print('patched')
