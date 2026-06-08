extends FogVolume

func _process(delta):
	# Fa oscillare leggermente la nebbia per un effetto respiro spettrale
	material.density = 1.0 + sin(Time.get_ticks_msec() * 0.001) * 0.5
