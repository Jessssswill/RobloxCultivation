import { Ease } from "./types";

export function ease(kind: Ease | undefined, a: number): number {
	a = math.clamp(a, 0, 1);
	if (kind === "in") return a * a;
	if (kind === "out") return 1 - (1 - a) * (1 - a);
	if (kind === "inOut") return a * a * (3 - 2 * a);
	if (kind === "expoOut") return a === 1 ? 1 : 1 - 2 ** (-10 * a);
	if (kind === "back") {
		// Lewat dikit terus balik: bikin tebasan kerasa "nendang"
		const c1 = 1.70158;
		const c3 = c1 + 1;
		return 1 + c3 * (a - 1) ** 3 + c1 * (a - 1) ** 2;
	}
	return a;
}
