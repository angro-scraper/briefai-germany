const modules = [
  {
    name: 'platform',
    url: 'https://salvesca.com/',
    marker: 'Salvesca — Digitalna platforma za dijasporu',
  },
  {
    name: 'asistent',
    url: 'https://asistent.salvesca.com/',
    marker: 'salvesca-asistent-backup.json',
  },
  {
    name: 'usluge',
    url: 'https://usluge.salvesca.com/',
    marker: 'salvesca-usluge-backup.json',
  },
  {
    name: 'posao',
    url: 'https://posao.salvesca.com/',
    marker: 'salvesca-posao-backup.json',
  },
  {
    name: 'prevod',
    url: 'https://prevod.salvesca.com/',
    marker: 'salvesca-prevod-backup.json',
  },
  {
    name: 'finansije',
    url: 'https://finansije.salvesca.com/',
    marker: 'salvesca-finansije-backup.json',
  },
  {
    name: 'prevoz',
    url: 'https://prevoz.salvesca.com/',
    marker: 'salvesca-prevoz-backup.json',
  },
  {
    name: 'wohnradar',
    url: 'https://wohnradar.salvesca.com/',
    marker: 'WohnRadar',
  },
];

const results = await Promise.all(
  modules.map(async ({name, url, marker}) => {
    try {
      const response = await fetch(url, {
        headers: {'user-agent': 'Salvesca-public-smoke/1.0'},
        signal: AbortSignal.timeout(30_000),
      });
      const body = await response.text();
      return {
        name,
        url,
        ok: response.ok && body.includes(marker),
        status: response.status,
        markerFound: body.includes(marker),
      };
    } catch (error) {
      return {name, url, ok: false, error: String(error)};
    }
  }),
);

for (const result of results) {
  const detail = result.error ?? `HTTP ${result.status}; marker=${result.markerFound}`;
  console.log(`${result.ok ? 'PASS' : 'FAIL'} ${result.name}: ${detail}`);
}

if (results.some((result) => !result.ok)) process.exitCode = 1;
