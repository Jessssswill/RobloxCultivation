// Tween yang jalan di waktu timeline cutscene (ikut slow-mo dan hitstop), beda sama TweenService.
// Satu daftar, di-update sekali per frame dari runtime.

interface Item {
	t0: number;
	dur: number;
	step: (a: number) => void;
	done?: () => void;
}

export class Tweens {
	now = 0;
	private list = new Array<Item>();

	add(dur: number, step: (a: number) => void, done?: () => void) {
		this.list.push({ t0: this.now, dur: math.max(dur, 1e-3), step, done });
		step(0);
	}

	after(delay: number, fn: () => void) {
		this.list.push({ t0: this.now, dur: math.max(delay, 1e-3), step: () => {}, done: fn });
	}

	update(now: number) {
		this.now = now;
		for (let i = this.list.size() - 1; i >= 0; i--) {
			const item = this.list[i];
			if (item === undefined) continue;
			const a = math.clamp((now - item.t0) / item.dur, 0, 1);
			item.step(a);
			if (a >= 1) {
				this.list.unorderedRemove(i);
				item.done?.();
			}
		}
	}

	clear() {
		this.list.clear();
	}
}
