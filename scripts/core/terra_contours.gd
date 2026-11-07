extends RefCounted
static func triangle(points: PackedVector2Array, values: Array[float]) -> PackedVector2Array:
	var out:=PackedVector2Array()
	for i in 3:
		var j: int=(i+1)%3
		if values[i]>0: out.append(points[i])
		if (values[i]>0)!=(values[j]>0): out.append(points[i].lerp(points[j],values[i]/(values[i]-values[j])))
	return out
