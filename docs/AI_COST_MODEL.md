# BriefAI Germany — AI trošak i zaštitni limiti

Referentne cene su proverene 26. jula 2026. na zvaničnoj OpenAI stranici:
<https://developers.openai.com/api/docs/pricing>.

## Produkcioni model

Podrazumevani model je `gpt-5.6-luna`:

- ulaz: 1 USD / 1.000.000 tokena;
- izlaz: 6 USD / 1.000.000 tokena.

Tipična analiza sa približno 3.500 ulaznih i 700 izlaznih tokena košta oko
0,0077 USD. Konzervativna procena, koja uključuje duži OCR i maksimalni
odgovor, rezerviše više sredstava pre svakog poziva i posle odgovora se
usklađuje sa stvarnim brojem tokena koji prijavi OpenAI.

## Server-side ograničenja

- analiza: najviše 1.200 izlaznih tokena;
- formalni odgovor: najviše 1.400 izlaznih tokena;
- pitanje AI asistentu: najviše 700 izlaznih tokena;
- globalni AI budžet: 30 USD mesečno;
- odgovorna upotreba Premium naloga: 1,50 USD mesečno;
- odgovorna upotreba Pro naloga: 4 USD mesečno;
- besplatni nalog: dve analize mesečno;
- odgovor i AI asistent: samo aktivni Premium/Pro nalog.

Budžeti su Firebase Functions parametri:

```text
OPENAI_MODEL=gpt-5.6-luna
AI_MONTHLY_BUDGET_USD=30
AI_USER_MONTHLY_BUDGET_USD=1.50
AI_PRO_USER_MONTHLY_BUDGET_USD=4
```

API ključ je isključivo Secret Manager tajna `OPENAI_API_KEY`. Parametri i
ključ nikada se ne ugrađuju u Flutter ili JavaScript paket.

## Predlog komercijalnih planova

| Plan | Cena | AI funkcije |
|---|---:|---|
| Free | 0 € | 2 analize mesečno |
| Premium | 4,99 €/mesec | analize, odgovori, asistent, arhiva i podsetnici uz zaštitu odgovorne upotrebe |
| Pro | 9,99 €/mesec | viši operativni prag za porodice i male firme, kada se zasebno uvede organizacioni nalog |

Limit u dolarima je zaštita od automatizovane zloupotrebe i neočekivanog
računa, a ne marketinški brojač. Admin panel prikazuje trenutni model, tokene,
procenjeni mesečni trošak i globalni limit.
