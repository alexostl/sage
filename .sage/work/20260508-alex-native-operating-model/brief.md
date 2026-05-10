---
title: "Brief: Alex-native operating model"
workflow: architect
phase: understand
status: completed
created: 2026-05-08
updated: 2026-05-08
cycle_id: "20260508-alex-native-operating-model"
owner: alexostl
handoff: |
  Brief approved by Alex on 2026-05-08. Design must keep the change
  prospective and moderate: Polish prose for new artifacts, stable Sage
  framework terms, concise junior/vibe-coder conversational context, and
  optional autonomous continuation at checkpoints without weakening safety
  stops.
---

# Brief: Alex-native operating model

## Problem

Sage Self Host ma przestać udawać neutralny upstreamowy produkt i ma być
świadomie dostrojony do Alexa jako głównego użytkownika. Obecny Sage działa
dobrze i nie wymaga rewolucji, ale czasem przechodzi zbyt szybko od rozmowy do
artefaktów albo implementacji, szczególnie w `build`, i zakłada, że użytkownik
przeczyta całe wygenerowane pliki (`brief`, `spec`, `plan`, `manifest`) przed
akceptacją.

To założenie jest tylko częściowo prawdziwe. Przy kluczowych decyzjach Alex
może czytać więcej, szczególnie jeśli treść artefaktów będzie po polsku, ale
przy mniejszych workflowach często potrzebuje krótkiego kontekstu w rozmowie:
co właśnie ustalono, gdzie zapisano najważniejsze punkty i które fragmenty
warto kliknąć przed decyzją.

## Użytkownicy

Pierwszym i jedynym docelowym użytkownikiem v1 jest Alex jako właściciel
self-host Sage. W przyszłości ten kierunek może być przydatny dla polskich
vibe-coderów, ale nie projektujemy tej zmiany jako publicznego upstreamowego
produktu.

Codex Port i Claude Port mają dostać efekt tej zmiany tam, gdzie przenoszą
core Sage do instrukcji runtime, ale kierunek produktu jest self-hostowy:
`self` oznacza "dla Alexa".

## Success Criteria

Sukces jest jakościowy i będzie mierzony feelingiem Alexa po około 3 miesiącach:
Sage nadal ma być szybki, skuteczny i nieprzegadany, ale ma częściej dawać
krótki kontekst, zadawać jedno pytanie naraz przy niejasnościach, pisać nowe
artefakty `.sage` po polsku i wskazywać klikalne miejsca w dokumentacji, gdzie
zapisał najważniejsze decyzje.

Zmiana stylu rozmowy ma być umiarkowana: około 20%, maksymalnie 30% w miejscach
takich jak `architect`, większy `build` i podobne workflowy wymagające decyzji.

## Scope

### Must Have v1

1. Nowe treści artefaktów `.sage` mają być pisane po polsku, z zachowaniem
   nazw frameworkowych, nazw artefaktów, nazw workflowów i naturalnych terminów
   technicznych po angielsku.
2. Agent ma rozmawiać bardziej jak z junior/vibe-coderem: mniej zakładać bez
   dopytania, częściej dawać krótki kontekst, tłumaczyć ważne koncepty prostszym
   językiem i zadawać jedno pytanie naraz w miejscach realnej niepewności.
3. Checkpointy mają dostać opcję wyboru trybu pracy: kontynuacja z kolejnymi
   checkpointami albo świadome pozwolenie agentowi na autonomiczne dowiezienie
   dalszego cyklu, z zachowaniem stopów bezpieczeństwa.

### Won't Have v1

- Nie migrujemy ani nie tłumaczymy historycznych plików w `.sage/work` i
  `.sage/docs`.
- Nie tłumaczymy nazw plików ani nazw artefaktów, takich jak `brief.md`,
  `spec.md`, `plan.md`, `manifest.md`, `decision-*.md`.
- Nie tłumaczymy nazw workflowów, komend ani terminów frameworka, takich jak
  `architect`, `build`, `fix`, `design`, `checkpoint`, `handoff`, `manifest`.
- Nie robimy pełnego `grill-me everywhere`; pytania mają być umiarkowane,
  konkretne i zadawane jedno po drugim.
- Nie przepisujemy metodologii Sage od zera i nie robimy dużego redesignu
  procesu.

## Key Flow

1. Użytkownik zaczyna większy `architect`, `build` albo podobny workflow.
2. Agent najpierw krótko zarysowuje kontekst, zamiast od razu przechodzić do
   plików albo implementacji.
3. Jeśli decyzja jest niejasna, agent zadaje jedno pytanie naraz i podaje swoją
   rekomendację.
4. Gdy agent tworzy albo aktualizuje artefakt, zapisuje treść po polsku i po
   checkpointcie pokazuje krótkie podsumowanie oraz linki do 1-3 najważniejszych
   miejsc w pliku.
5. Przy checkpointach agent domyślnie proponuje normalną ścieżkę z akceptacją,
   ale dodaje opcję świadomej autonomicznej kontynuacji przez dalsze etapy.
6. Jeśli podczas autonomicznej kontynuacji zmienia się scope, pojawia się
   ryzykowna decyzja, konflikt z dokumentacją albo istotna awaria testów, agent
   zatrzymuje się i wraca do użytkownika.

## Constraints

- Najwięcej zmian powinno żyć w `core/`, a nie w portach.
- Codex Port i Claude Port mają dostać ten efekt, ale najlepiej przez wspólny
  core i generowane instrukcje, nie przez duplikowanie osobnej filozofii w obu
  portach.
- Zmiana ma być prospektywna: dotyczy nowych artefaktów i instrukcji od teraz,
  bez edycji historycznej dokumentacji.
- Formalne gate'y Sage pozostają bezpieczne; autonomiczna kontynuacja nie może
  omijać stopów bezpieczeństwa, zmian scope ani ryzykownych decyzji.
- Testy powinny objąć miejsca, gdzie generowane instrukcje albo workflow text
  mają wymuszać polski język artefaktów, styl rozmowy i opcję checkpointów.

## High Risk Areas

- Zbyt mocna zmiana może spowolnić Sage i zmienić dobry obecny balans pracy.
- Zbyt miękka zmiana może pozostać tylko deklaracją w dokumentacji i nie wpłynąć
  na realne zachowanie agentów.
- Przeniesienie logiki do portów zamiast do `core/` może zwiększyć duplikację i
  utrudnić utrzymanie Claude Port oraz Codex Port.
- Opcja autonomicznej kontynuacji musi być dobrze ograniczona, żeby nie
  rozszczelnić checkpointów i guardrails.

## Framing Decision

Ten cykl projektuje Alex-native operating model jako dostrojenie istniejącego
Sage, nie jako rewolucję. Język dokumentów i styl rozmowy są częścią produktu,
ale nazwy frameworka, artefaktów i workflowów pozostają stabilne.
