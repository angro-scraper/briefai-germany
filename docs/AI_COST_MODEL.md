# BriefAI Germany — AI trošak i zaštitni limiti

Referentne cene su proverene 26. jula 2026. na zvaničnoj OpenAI stranici:
<https://developers.openai.com/api/docs/pricing>.

## Produkcioni model

Podrazumevani model je `gpt-5.6-terra`, zvanično preporučen za balans
kvaliteta i troška:

- ulaz: 2,50 USD / 1.000.000 tokena;
- izlaz: 15 USD / 1.000.000 tokena.

Tipična analiza sa približno 3.500 ulaznih i 700 izlaznih tokena košta oko
0,0193 USD. Konzervativna procena, koja uključuje duži OCR i maksimalni
odgovor, rezerviše više sredstava pre svakog poziva i posle odgovora se
usklađuje sa stvarnim brojem tokena koji prijavi OpenAI.

## Server-side ograničenja

- analiza: najviše 1.500 izlaznih tokena;
- formalni odgovor: najviše 2.800 izlaznih tokena;
- pitanje AI asistentu: najviše 700 izlaznih tokena;
- globalni AI budžet: 30 USD mesečno;
- probni nalog ima zaštitni AI budžet od 1,50 USD mesečno;
- Basic / Plus / Pro imaju zaštitne AI budžete od 4 / 8 / 12 USD mesečno;
- plaćeni paketi imaju 50 / 100 / 150 analiza po kalendarskom mesecu;
- svaki prijavljeni nalog tokom zatvorenog testiranja dobija 15 analiza ukupno;
- nakon treće analize nova pisma, AI odgovor i asistent zahtevaju Premium;
- founder claim za vlasnika zaobilazi probni i korisnički limit, dok globalni
  sigurnosni budžet ostaje aktivan kao zaštita od zloupotrebe i greške.

Budžeti su Firebase Functions parametri:

```text
OPENAI_MODEL=gpt-5.6-terra
AI_MONTHLY_BUDGET_USD=30
AI_USER_MONTHLY_BUDGET_USD=1.50
```

API ključ je isključivo Secret Manager tajna `OPENAI_API_KEY`. Parametri i
ključ nikada se ne ugrađuju u Flutter ili JavaScript paket.

Responses API pozivi koriste `store: false`; samo OCR tekst i kontekst koji su
potrebni za trenutni zahtev napuštaju uređaj. Originalna slika/PDF i arhiva se
ne šalju OpenAI-ju niti čuvaju u Firebase-u.

## Predlog komercijalnih planova

| Plan | Cena | AI funkcije |
|---|---:|---|
| Test | 0 € | 15 analiza ukupno, naplata isključena |
| Basic | 9,90 €/mesec | 50 analiza, odgovori, asistent, arhiva i podsetnici |
| Plus | 19,90 €/mesec | 100 analiza, odgovori, asistent, arhiva i podsetnici |
| Pro | 29,90 €/mesec | 150 analiza, odgovori, asistent, arhiva i podsetnici |
| Founder | bez naplate | trajni no-limit pristup za serverski označen nalog vlasnika |

Limit u dolarima je zaštita od automatizovane zloupotrebe i neočekivanog
računa, a ne marketinški brojač. Admin panel prikazuje trenutni model, tokene,
procenjeni mesečni trošak i globalni limit.
