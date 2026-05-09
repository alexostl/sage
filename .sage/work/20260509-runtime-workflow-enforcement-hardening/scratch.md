# Scratch: runtime workflow enforcement hardening

## approach-1

Hipoteza: główny problem to brak resolvera wielu aktywnych cykli.

Evidence: zainstalowany `.codex/hooks/lib/active_init.sh` wybiera newest
`in-progress`, a `.codex/hooks/pre-tool-validate.sh` używa go bez path-intent
resolution. To tłumaczy blokadę podczas consolidation pass.

## approach-2

Hipoteza rozszerzona: source runtime ma już częściową poprawkę, ale aktywna
powierzchnia hooków i status UX nie są spójne.

Evidence: `runtime/platforms/codex/hooks/pre-tool-validate.sh` używa
`resolve_cycle_for_patch`, lecz `.codex/hooks/pre-tool-validate.sh` nadal używa
starego `active_init_path`. `bin/sage status` nadal wypisuje `next: sage
continue`, mimo że `bin/sage continue` nie istnieje.

## approach-3

Hipoteza końcowa: umbrella fix musi objąć nie tylko resolver cyklu, ale cały
contract między source hooks, deployed hooks, status/recovery text, turn audit i
harness rubric.

Evidence: QA pokazało real-agent `file_change` bypass, fix-trigger bez gate i
target repo ownership drift, a harness scenario 03 ma pustą `state_rubric`.
