// dsh-plugin-pet template — filled by switch_pet.sh
// Codex-pet-contract behaviors: per-row animation with official frame
// durations, bottom-edge wandering (running-left/right rows), waving
// greeting, reduced-motion static frame, drag to place, notify bubble.
window.__ModuleLoader__.load({
	id: "dsh-plugin-pet",
	factory: (require) => {
		var module = { exports: {} };
		var exports = module.exports;
		Object.defineProperty(exports, Symbol.toStringTag, { value: "Module" });
		const react = require("react");
		const useState = react.useState;
		const useEffect = react.useEffect;
		const useRef = react.useRef;
		const useMemo = react.useMemo;
		const useSyncExternalStore = react.useSyncExternalStore;

		const PET_NAME = "__PET_NAME__";
		const SPRITE_URL = "data:image/webp;base64,__PET_SPRITE_B64__";
		const SHEET = __PET_SHEET__;
		const ATLAS_MODE = "__PET_MODE__";
__PET_ROW_ANIM__
		const MOODS = {
			sleep: { title: PET_NAME + ": no session open" },
			idle: { title: PET_NAME + ": waiting for you" },
			working: { title: PET_NAME + ": agent is working" },
			waiting: { title: PET_NAME + ": agent needs your answer" },
			notify: { title: PET_NAME + ": new reply — click me to ack" }
		};
		const SIMPLE_INTERVALS = { sleep: 700, idle: 260, working: 110, waiting: 160, notify: 170 };
		const ACTIVITY_WINDOW_MS = 5000;
		const NOTIFY_WINDOW_MS = 60000;
		const REDUCED_MOTION = typeof matchMedia === "function" && matchMedia("(prefers-reduced-motion: reduce)").matches;
		const WANDER_KEY = "dsh-plugin-pet:wander";
		const WANDER_DEFAULT = true;
		const WALK_SPEED_PX_PER_TICK = 4;
		const WALK_TICK_MS = 100;
		const WALK_MIN_PX = 60;
		const WALK_MAX_PX = 260;
		const PAUSE_MIN_MS = 6000;
		const PAUSE_MAX_MS = 18000;
		const DOUBLE_TAP_MS = 320;
		const FLOOR_MARGIN = 8;

		const css = ".dshPet_root{position:relative;width:" + SHEET.displayW + "px;height:" + SHEET.displayH + "px;flex:none;cursor:grab;touch-action:none;transition:opacity .3s;opacity:1;user-select:none}.dshPet_root[data-dragging]{cursor:grabbing}.dshPet_root[data-floating]{position:fixed;z-index:2147483000}.dshPet_root:hover{opacity:1}.dshPet_sprite{position:absolute;inset:0;background-image:url('" + SPRITE_URL + "');background-repeat:no-repeat;background-size:" + SHEET.cols * SHEET.displayW + "px " + SHEET.rows * SHEET.displayH + "px;pointer-events:none}.dshPet_sprite[data-flip]{transform:scaleX(-1)}.dshPet_root[data-mode=simple][data-mood=waiting] .dshPet_sprite{animation:dshPetBob 1.1s ease-in-out infinite}.dshPet_root[data-mode=simple][data-mood=sleep] .dshPet_sprite{animation:dshPetBreath 3.2s ease-in-out infinite}.dshPet_root[data-mode=simple][data-mood=working] .dshPet_sprite{animation:dshPetBob .55s ease-in-out infinite}.dshPet_root[data-mode=simple][data-mood=notify] .dshPet_sprite{animation:dshPetHop .6s ease-in-out infinite}@keyframes dshPetBob{0%,100%{transform:translateY(0)}50%{transform:translateY(-3px)}}@keyframes dshPetBreath{0%,100%{transform:scale(1)}50%{transform:scale(.97)}}@keyframes dshPetHop{0%,100%{transform:translateY(0)}30%{transform:translateY(-9px)}55%{transform:translateY(0)}75%{transform:translateY(-4px)}}.dshPet_badge{position:absolute;right:-2px;top:-2px;width:8px;height:8px;border-radius:50%;background:#3b82f6;opacity:0;transition:opacity .25s;pointer-events:none}.dshPet_root[data-mood=waiting] .dshPet_badge{opacity:1;animation:dshPetPulse 1s ease-in-out infinite}.dshPet_root[data-mood=working] .dshPet_badge{opacity:.85;background:#22c55e}.dshPet_root[data-mood=notify] .dshPet_badge{opacity:1;background:#ef4444;animation:dshPetPulse .7s ease-in-out infinite}.dshPet_bubble{position:absolute;top:-20px;left:50%;transform:translateX(-50%);background:#ef4444;color:#fff;font-size:10px;line-height:14px;padding:1px 6px;border-radius:7px;white-space:nowrap;opacity:0;transition:opacity .25s;pointer-events:none}.dshPet_root[data-mood=notify] .dshPet_bubble{opacity:1;animation:dshPetBubblePulse .7s ease-in-out infinite}@keyframes dshPetPulse{0%,100%{transform:scale(1)}50%{transform:scale(1.45)}}@keyframes dshPetBubblePulse{0%,100%{opacity:1}50%{opacity:.55}}";
		const tagId = "dsh-plugin-pet/style";
		if (typeof document !== "undefined" && document.querySelector("style[data-plugin-css=" + JSON.stringify(tagId) + "]") === null) {
			const tag = document.createElement("style");
			tag.dataset.plugin = "dsh-plugin-pet";
			tag.dataset.pluginCss = tagId;
			tag.textContent = css;
			document.head.appendChild(tag);
		}

		function apply(ctx) {
			const sessions = ctx.sessions;
			const ackRef = { current: false };

			function specFor(name) {
				if (ATLAS_MODE === "contract" && ROW_ANIM) return ROW_ANIM[name] || ROW_ANIM.idle;
				return null;
			}

			function useFramePlayer(animName) {
				const [idx, setIdx] = useState(0);
				const idxRef = useRef(0);
				useEffect(() => {
					if (REDUCED_MOTION && animName !== "working") { idxRef.current = 0; setIdx(0); return; }
					const spec = specFor(animName);
					if (spec) {
						let cancelled = false;
						let timer = null;
						const play = () => {
							if (cancelled) return;
							idxRef.current = (idxRef.current + 1) % spec.cols.length;
							setIdx(idxRef.current);
							timer = setTimeout(play, spec.durations[idxRef.current] || 120);
						};
						timer = setTimeout(play, spec.durations[0] || 120);
						return () => { cancelled = true; clearTimeout(timer); };
					}
					const total = SHEET.cols * SHEET.rows;
					const timer = setInterval(() => {
						idxRef.current = (idxRef.current + 1) % total;
						setIdx(idxRef.current);
					}, SIMPLE_INTERVALS[animName] || 260);
					return () => clearInterval(timer);
				}, [animName]);
				if (REDUCED_MOTION && animName !== "working") return { col: 0, row: 0 };
				const spec = specFor(animName);
				if (spec) return { col: spec.cols[idx], row: spec.row };
				return { col: idx % SHEET.cols, row: Math.floor(idx / SHEET.cols) };
			}

			function PetAvatar() {
				const mood = useMood();
				const selfRef = useRef(null);
				const [superseded, setSuperseded] = useState(false);
				const [pos, setPos] = useState(null);
				const [dragging, setDragging] = useState(false);
				const dragOffsetRef = useRef(null);
				const lastTapRef = useRef(0);
				const welcomedRef = useRef(false);
				const [wanderOn, setWanderOn] = useState(() => {
					try { const v = localStorage.getItem(WANDER_KEY); return v === null ? WANDER_DEFAULT : v === "1"; } catch { return WANDER_DEFAULT; }
				});
				const walkRef = useRef(null);
				const [walking, setWalking] = useState(null);

				// welcome wave (contract only): one pass of the waving row
				const [animName, setAnimName] = useState(mood);
				useEffect(() => {
					if (welcomedRef.current) { setAnimName(mood); return; }
					if (ATLAS_MODE === "contract" && ROW_ANIM && ROW_ANIM.waving) {
						setAnimName("waving");
						const t = setTimeout(() => { welcomedRef.current = true; setAnimName(mood); }, 2000);
						return () => clearTimeout(t);
					}
					welcomedRef.current = true;
					setAnimName(mood);
				}, [mood]);
				useEffect(() => { if (welcomedRef.current) setAnimName(mood); }, [mood]);

				const effectiveAnim = walking ? (walking.dir < 0 && specFor("running_left") ? "running_left" : "running_right") : animName;

				const { col, row } = useFramePlayer(effectiveAnim);

				// ── wander engine: bottom-edge strolls between pauses ──────────
				useEffect(() => {
					if (!wanderOn || REDUCED_MOTION || dragging) { setWalking(null); return; }
					if (ATLAS_MODE !== "contract" || !ROW_ANIM || !ROW_ANIM.running_right) { setWalking(null); return; }
					let cancelled = false;
					let timer = null;
					const startWalk = () => {
						if (cancelled) return;
						const maxX = Math.max(0, window.innerWidth - SHEET.displayW);
						setPos((p) => {
							const base = p || { x: Math.random() * Math.max(1, maxX), y: window.innerHeight - SHEET.displayH - FLOOR_MARGIN };
							return { x: Math.min(Math.max(base.x, 0), maxX), y: window.innerHeight - SHEET.displayH - FLOOR_MARGIN };
						});
						const dist = WALK_MIN_PX + Math.random() * (WALK_MAX_PX - WALK_MIN_PX);
						const dir = Math.random() < 0.5 ? -1 : 1;
						let remaining = dist;
						setWalking({ dir });
						const tick = () => {
							if (cancelled) return;
							remaining -= WALK_SPEED_PX_PER_TICK;
							setPos((p) => {
								if (!p) return p;
								let nx = p.x + dir * WALK_SPEED_PX_PER_TICK;
								const maxX = window.innerWidth - SHEET.displayW;
								if (nx <= 0 || nx >= maxX) return p;
								return { x: nx, y: p.y };
							});
							if (remaining > 0) { timer = setTimeout(tick, WALK_TICK_MS); return; }
							setWalking(null);
							timer = setTimeout(startWalk, PAUSE_MIN_MS + Math.random() * (PAUSE_MAX_MS - PAUSE_MIN_MS));
						};
						timer = setTimeout(tick, WALK_TICK_MS);
					};
					timer = setTimeout(startWalk, 1500 + Math.random() * PAUSE_MIN_MS);
					return () => { cancelled = true; clearTimeout(timer); setWalking(null); };
				}, [wanderOn, dragging]);

				useEffect(() => {
					const node = selfRef.current;
					if (!node) return;
					const all = document.querySelectorAll(".dshPet_root");
					if (all.length > 1 && all[0] !== node) setSuperseded(true);
				}, []);
				useEffect(() => {
					if (!superseded) return;
					const node = selfRef.current;
					if (!node || !node.parentNode) return;
					const all = document.querySelectorAll(".dshPet_root");
					if (all.length <= 1 || all[0] === node) setSuperseded(false);
				}, [superseded, col]);
				if (superseded) return null;

				const onPointerDown = (e) => {
					ackRef.current = true;
					if (e.button !== 0) return;
					const node = selfRef.current;
					if (!node) return;
					const now = Date.now();
					if (now - lastTapRef.current < DOUBLE_TAP_MS) {
						const next = !wanderOn;
						setWanderOn(next);
						try { localStorage.setItem(WANDER_KEY, next ? "1" : "0"); } catch {}
						lastTapRef.current = 0;
					} else {
						lastTapRef.current = now;
					}
					const rect = node.getBoundingClientRect();
					if (pos === null) setPos({ x: rect.left, y: rect.top });
					dragOffsetRef.current = { dx: e.clientX - rect.left, dy: e.clientY - rect.top };
					setDragging(true);
					node.setPointerCapture(e.pointerId);
					e.preventDefault();
				};
				const onPointerMove = (e) => {
					if (!dragging || !dragOffsetRef.current) return;
					const x = Math.min(Math.max(e.clientX - dragOffsetRef.current.dx, 0), window.innerWidth - SHEET.displayW);
					const y = Math.min(Math.max(e.clientY - dragOffsetRef.current.dy, 0), window.innerHeight - SHEET.displayH);
					setPos({ x, y });
				};
				const onPointerUp = (e) => {
					if (!dragging) return;
					setDragging(false);
					dragOffsetRef.current = null;
					try { selfRef.current && selfRef.current.releasePointerCapture(e.pointerId); } catch {}
				};

				const meta = MOODS[mood] || MOODS.idle;
				const floating = pos !== null;
				const style = floating ? { position: "fixed", left: pos.x + "px", top: pos.y + "px", zIndex: 2147483000 } : undefined;
				return react.createElement(
					"div",
					{
						className: "dshPet_root",
						"data-mood": mood,
						"data-mode": ATLAS_MODE,
						"data-floating": floating ? "1" : undefined,
						"data-dragging": dragging ? "1" : undefined,
						title: meta.title + (wanderOn ? " · double-click: freeze" : " · double-click: wander"),
						role: "img",
						ref: selfRef,
						style: style,
						onPointerDown: onPointerDown,
						onPointerMove: onPointerMove,
						onPointerUp: onPointerUp,
						onPointerCancel: onPointerUp
					},
					react.createElement("div", {
						className: "dshPet_sprite",
						"data-flip": walking && walking.dir < 0 && !specFor("running_left") ? "1" : undefined,
						style: { backgroundPosition: "-" + col * SHEET.displayW + "px -" + row * SHEET.displayH + "px" }
					}),
					react.createElement("div", { className: "dshPet_badge" }),
					react.createElement("div", { className: "dshPet_bubble" }, "New reply!")
				);
			}

			function useMood() {
				const subList = useMemo(() => (cb) => sessions.list.subscribe(cb), [sessions]);
				const currentId = useSyncExternalStore(
					subList,
					() => { try { return sessions.list.getSnapshot().current ?? null; } catch { return null; } },
					() => null
				);
				const pending = useSyncExternalStore(
					subList,
					() => { try { const s = sessions.list.getSnapshot(); const sum = s.current ? s.byId[s.current] : undefined; return sum?.pendingInteraction ?? null; } catch { return null; } },
					() => null
				);
				const lastActivityRef = useRef(0);
				const binding = currentId ? sessions.binding?.(currentId) : undefined;
				const projections = binding?.session?.projections;
				useEffect(() => {
					if (!projections || typeof projections.subscribe !== "function") return;
					const stamp = () => { lastActivityRef.current = Date.now(); ackRef.current = false; };
					return projections.subscribe(stamp);
				}, [projections]);
				useEffect(() => {
					const stamp = () => { lastActivityRef.current = Date.now(); };
					return sessions.list.subscribe(stamp);
				}, [sessions]);
				const [, bumpTick] = useState(0);
				useEffect(() => {
					const timer = setInterval(() => bumpTick((n) => n + 1), 1000);
					return () => clearInterval(timer);
				}, []);
				if (currentId === null) return "sleep";
				if (pending) return "waiting";
				const idleFor = Date.now() - lastActivityRef.current;
				if (idleFor < ACTIVITY_WINDOW_MS) return "working";
				if (idleFor < NOTIFY_WINDOW_MS && lastActivityRef.current > 0 && !ackRef.current) return "notify";
				return "idle";
			}

			ctx.slots.inject("sidebar.footer.action", () => ctx.slots.register({ name: "sidebar.footer.action", id: "pet-avatar" }, PetAvatar));
		}

		const inject = ["slots", "sessions"];
		exports.apply = apply;
		exports.inject = inject;
		return module.exports;
	}
});
