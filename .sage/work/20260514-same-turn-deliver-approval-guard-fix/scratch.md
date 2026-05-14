approach-1: sprawdzilem hipoteze "hook myli legalny bookkeeping po approval z
self-created approval" — kod `same_turn_bootstrapped_cycle` patrzy tylko na
`session_id`, `turn_id`, `cycle_id` oraz obecność `.sage/work/<cycle>/manifest.md`
albo canonical `plan.md` w `.sage/.session-mutations.log`. Ad hoc reprodukcja na
temp projekcie pokazala: prior-turn manifest+plan pozwala source edit; same-turn
`plan-milestone-1.md` sam pozwala source edit; same-turn `manifest.md` albo
canonical `plan.md` blokuje source edit jako self-created cycle, nawet gdy
manifest ma `semantic_reclassification: accepted` i scope obejmuje target.

approach-2: Alex doprecyzowal wariant workflow: user moze powiedziec agentowi,
zeby zrobil revision wedlug juz opisanych punktow i od razu po tej rewizji
implementowal plan bez kolejnego stopu. To jest legalne tylko jako explicit,
bounded conditional approval: user wskazuje konkretne zmiany do revision oraz
jednoczesnie autoryzuje implementacje po ich naniesieniu. Nie jest legalne jako
agent self-revision + self-approval, ani przy materialnym scope expansion,
nowych decyzjach lub ryzyku odkrytym podczas rewizji.

decision-note: Alex chce dodac to jako oficjalna opcje checkpointu:
`[I] Revise and Implement in the same turn`.

approach-3: plan review subagent zwrocil NEEDS REVISION. Poprawka planu wybiera
konkretny marker contract: `implementation_approval` w manifest frontmatter.
Hook ma allowowac same-turn `manifest.md` / canonical `plan.md` bookkeeping
tylko przy pre-turn evidence zatwierdzonego canonical `plan.md`/scope; same-turn
dopisanie markera bez takiego evidence nadal blokuje, szczegolnie `AGENTS.md`.

approach-4: druga runda plan review zwrocila NEEDS REVISION, bo pre-turn
`manifest.md` evidence bylo za szerokie. Plan zostal zawezony: canonical
`.sage/work/<cycle>/plan.md` musi istniec i miec prior log evidence; manifest-only
evidence bez canonical planu nadal blokuje, zwlaszcza `AGENTS.md`.
