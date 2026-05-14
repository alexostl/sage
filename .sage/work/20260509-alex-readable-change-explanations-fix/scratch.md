# Scratch

approach-1: Pierwsza hipoteza zakładała, że QA workflow jest głównym miejscem
problemu, bo intake wprost wskazuje angielski `qa-report-template.md`. Dowody
potwierdziły błąd w QA, ale komentarz Alexa wskazał, że to może być szerszy
wzorzec.

approach-2: Szeroki scan workflowów pokazał, że ten sam typ ryzyka istnieje
też w `design-review.workflow.md`: workflow zapisuje raport i mówi
`Use template from develop/templates/design-review-template.md`, a template
jest po angielsku i nie ma Alex-native guidance. `build.workflow.md` także
używa template'ów, ale główne build/spec/plan/manifest template'y mają już
komentarz `Alex-native self-host — write prose po polsku`, więc nie są tym
samym root cause.
