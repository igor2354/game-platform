extends RefCounted
## Connected pixel components and face ports, only for refined 16x16 cells.
static func build(mask: PackedByteArray) -> Dictionary:
	var labels:=PackedInt32Array();labels.resize(256);labels.fill(-1)
	var parts: Array=[];var bits: Array=[]
	for root in 256:
		if mask[root]==0 or labels[root]>=0:continue
		var id:=parts.size();var pixels:=PackedInt32Array([root]);labels[root]=id;var head:=0;var sides:=0
		while head<pixels.size():
			var p:=pixels[head];head+=1
			if p%16==0:sides|=1
			if p%16==15:sides|=2
			if p<16:sides|=4
			if p>=240:sides|=8
			for step in [-1,1,-16,16]:
				var q: int=p+step
				if q<0 or q>=256 or (absi(step)==1 and q/16!=p/16):continue
				if mask[q]>0 and labels[q]<0:labels[q]=id;pixels.append(q)
		parts.append(pixels);bits.append(sides)
	var ports: Array=[]
	for side in 4:
		var face:=PackedInt32Array()
		for i in 16:face.append(labels[i*16 if side==0 else i*16+15 if side==1 else i if side==2 else 240+i])
		ports.append(face)
	var sorted:=bits.duplicate();sorted.sort()
	return {"hash":hash(mask),"parts":parts,"bits":bits,"ports":ports,"signature":hash([sorted,ports if parts.size()>1 else []])}
