(function () {
  const MAX_PDF_PAGES = 20;
  const WORKER_TIMEOUT_MS = 45000;
  const RECOGNITION_TIMEOUT_MS = 60000;
  const OCR_BASE = new URL('ocr-vendor/', document.baseURI);
  let workerPromise;
  let queuedRecognition = Promise.resolve();

  function report(status, progress) {
    window.dispatchEvent(new CustomEvent('briefai-ocr-progress', {
      detail: {status, progress: Number(progress || 0)},
    }));
  }

  function timeoutAfter(milliseconds, message) {
    return new Promise((_, reject) => {
      window.setTimeout(() => reject(new Error(message)), milliseconds);
    });
  }

  async function createOcrWorker() {
    if (!window.Tesseract) {
      throw new Error('Lokalni OCR paket nije učitan. Osvežite aplikaciju.');
    }
    report('loading', 0);
    return window.Tesseract.createWorker('deu', 1, {
      workerPath: new URL(
        'tesseract/worker.min.js',
        OCR_BASE,
      ).href,
      corePath: new URL('core/', OCR_BASE).href,
      langPath: new URL('lang', OCR_BASE).href,
      logger: (message) => report(message.status, message.progress),
    });
  }

  function getWorker() {
    if (!workerPromise) {
      const creation = createOcrWorker();
      workerPromise = Promise.race([
        creation,
        timeoutAfter(
          WORKER_TIMEOUT_MS,
          'OCR se nije pokrenuo na vreme. Zatvorite druge aplikacije i pokušajte ponovo.',
        ),
      ]).catch((error) => {
        creation.then((worker) => worker.terminate()).catch(() => undefined);
        workerPromise = undefined;
        throw error;
      });
    }
    return workerPromise;
  }

  async function recognizeWithWorker(worker, source) {
    try {
      const result = await Promise.race([
        worker.recognize(source),
        timeoutAfter(
          RECOGNITION_TIMEOUT_MS,
          'Prepoznavanje traje predugo. Probajte jasniju ili manju fotografiju.',
        ),
      ]);
      return (result?.data?.text || '').trim();
    } catch (error) {
      const current = workerPromise;
      workerPromise = undefined;
      current?.then((activeWorker) => activeWorker.terminate())
        .catch(() => undefined);
      throw error;
    }
  }

  async function prepareImage(bytes, mimeType) {
    const blob = new Blob([bytes], {type: mimeType});
    if (!window.createImageBitmap) return blob;
    const bitmap = await createImageBitmap(blob, {
      imageOrientation: 'from-image',
    });
    try {
      const maxSide = Math.max(bitmap.width, bitmap.height);
      const scale = Math.min(1, 2200 / maxSide);
      const canvas = document.createElement('canvas');
      canvas.width = Math.max(1, Math.round(bitmap.width * scale));
      canvas.height = Math.max(1, Math.round(bitmap.height * scale));
      const context = canvas.getContext('2d', {alpha: false});
      context.fillStyle = '#ffffff';
      context.fillRect(0, 0, canvas.width, canvas.height);
      context.filter = 'contrast(1.15) brightness(1.03)';
      context.drawImage(bitmap, 0, 0, canvas.width, canvas.height);
      context.filter = 'none';
      return canvas;
    } finally {
      bitmap.close();
    }
  }

  async function recognizeDocument(rawBytes, mimeType) {
    const bytes = rawBytes instanceof Uint8Array
      ? rawBytes
      : new Uint8Array(rawBytes);
    const worker = await getWorker();
    if (mimeType !== 'application/pdf') {
      report('preparing image', 0);
      const source = await prepareImage(bytes, mimeType);
      return recognizeWithWorker(worker, source);
    }

    const pdfjs = await import(
      'https://cdn.jsdelivr.net/npm/pdfjs-dist@6.1.200/build/pdf.min.mjs'
    );
    pdfjs.GlobalWorkerOptions.workerSrc =
      'https://cdn.jsdelivr.net/npm/pdfjs-dist@6.1.200/build/pdf.worker.min.mjs';
    const pdf = await pdfjs.getDocument({data: bytes}).promise;
    if (pdf.numPages > MAX_PDF_PAGES) {
      throw new Error(`PDF može imati najviše ${MAX_PDF_PAGES} strana.`);
    }
    const pages = [];
    for (let pageNumber = 1; pageNumber <= pdf.numPages; pageNumber += 1) {
      report('recognizing text', (pageNumber - 1) / pdf.numPages);
      const page = await pdf.getPage(pageNumber);
      const viewport = page.getViewport({scale: 2});
      const canvas = document.createElement('canvas');
      canvas.width = Math.ceil(viewport.width);
      canvas.height = Math.ceil(viewport.height);
      const context = canvas.getContext('2d', {alpha: false});
      context.fillStyle = '#ffffff';
      context.fillRect(0, 0, canvas.width, canvas.height);
      await page.render({canvasContext: context, viewport}).promise;
      pages.push(await recognizeWithWorker(worker, canvas));
      page.cleanup();
      canvas.width = 1;
      canvas.height = 1;
    }
    await pdf.destroy();
    return pages.filter(Boolean).join('\n\n');
  }

  window.briefAiPrepareOcr = function () {
    return getWorker().then(() => undefined);
  };

  window.briefAiRecognizeDocument = function (rawBytes, mimeType) {
    const job = queuedRecognition.then(
      () => recognizeDocument(rawBytes, mimeType),
    );
    queuedRecognition = job.catch(() => undefined);
    return job;
  };
})();
