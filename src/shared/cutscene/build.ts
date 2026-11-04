// Pembantu bikin set greybox cutscene. Semua part anchored, gak tabrakan, cuma ada di client yang nonton.

export interface PartProps {
	size: Vector3;
	cf: CFrame;
	color?: Color3;
	material?: Enum.Material;
	transparency?: number;
	shape?: Enum.PartType;
	name?: string;
}

export function block(parent: Instance, p: PartProps): Part {
	const part = new Instance("Part");
	part.Name = p.name ?? "Set";
	part.Anchored = true;
	part.CanCollide = false;
	part.CanQuery = false;
	part.CanTouch = false;
	part.CastShadow = false;
	part.Size = p.size;
	part.CFrame = p.cf;
	part.Color = p.color ?? Color3.fromRGB(160, 160, 160);
	part.Material = p.material ?? Enum.Material.SmoothPlastic;
	part.Transparency = p.transparency ?? 0;
	if (p.shape) part.Shape = p.shape;
	part.TopSurface = Enum.SurfaceType.Smooth;
	part.BottomSurface = Enum.SurfaceType.Smooth;
	part.Parent = parent;
	return part;
}

/** Silinder tegak (silinder Roblox aslinya rebah di sumbu X). */
export function pillar(parent: Instance, pos: Vector3, height: number, diameter: number, color: Color3, material?: Enum.Material) {
	return block(parent, {
		size: new Vector3(height, diameter, diameter),
		cf: new CFrame(pos).mul(CFrame.Angles(0, 0, math.rad(90))),
		color,
		material,
		shape: Enum.PartType.Cylinder,
	});
}

export function light(part: BasePart, color: Color3, range: number, brightness = 2) {
	const l = new Instance("PointLight");
	l.Color = color;
	l.Range = range;
	l.Brightness = brightness;
	l.Parent = part;
	return l;
}
